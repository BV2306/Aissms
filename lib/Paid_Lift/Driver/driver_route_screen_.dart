import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_route_service.dart';
// import 'driver_seeker_live_map.dart'; // Uncomment when live-map is ready

class DriverRouteScreen extends StatefulWidget {
  final LatLng source;
  final LatLng destination;
  final String sourceName;
  final String destinationName;

  const DriverRouteScreen({
    super.key,
    required this.source,
    required this.destination,
    required this.sourceName,
    required this.destinationName,
  });

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  GoogleMapController? _mapController;
  String? _rideId;
  List<LatLng> _routePoints = [];
  bool _loading = true;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<DatabaseEvent>? _requestSub;

  final String _driverId = FirebaseAuth.instance.currentUser!.uid;

  // Tracks seeker IDs whose dialog is currently ON SCREEN to avoid duplicates.
  // A seeker is removed from here once their dialog is dismissed (accept/reject).
  final Set<String> _dialogOpen = {};

  @override
  void initState() {
    super.initState();
    _startRide();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _requestSub?.cancel();
    FirebaseDatabase.instance.ref("drivers/$_driverId").remove();
    super.dispose();
  }

  // ── Ride setup ────────────────────────────────────────────────────────────

  Future<void> _startRide() async {
    try {
      final (rideId, points) = await DriverRouteService.createActiveRide(
        source: widget.source,
        destination: widget.destination,
        sourceName: widget.sourceName,
        destinationName: widget.destinationName,
      );

      _rideId = rideId;
      _routePoints = points;

      _buildMapElements();
      _broadcastLocation();
      _listenForRequests();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create ride: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  void _buildMapElements() {
    _markers = {
      Marker(
        markerId: const MarkerId('source'),
        position: widget.source,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow:
            InfoWindow(title: widget.sourceName, snippet: 'Your start'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow:
            InfoWindow(title: widget.destinationName, snippet: 'Your end'),
      ),
    };
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: Colors.blue.shade700,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  // ── Location broadcast ────────────────────────────────────────────────────

  void _broadcastLocation() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      // Write to driverLocations so seeker can read it
      FirebaseDatabase.instance.ref("driverLocations/$_driverId").set({
        "lat": pos.latitude,
        "lng": pos.longitude,
        "rideId": _rideId,
        "status": "online",
      });
      // Also maintain drivers list for discoverability
      FirebaseDatabase.instance.ref("drivers/$_driverId").set({
        "lat": pos.latitude,
        "lng": pos.longitude,
        "rideId": _rideId,
        "status": "online",
      });
    });
  }

  // ── Request listener ──────────────────────────────────────────────────────

  void _listenForRequests() {
    _requestSub = FirebaseDatabase.instance
        .ref("rideRequests/$_rideId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || !mounted) return;

      final requests =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      requests.forEach((seekerId, rawData) {
        final data = Map<dynamic, dynamic>.from(rawData as Map);
        final sid = seekerId as String;

        // Show dialog only if status is pending AND dialog is not already open
        if (data['status'] == 'pending' && !_dialogOpen.contains(sid)) {
          _dialogOpen.add(sid);
          _showRequestDialog(sid, data);
        }
      });
    });
  }

  // ── Accept / Reject ───────────────────────────────────────────────────────

  void _showRequestDialog(
      String seekerId, Map<dynamic, dynamic> seekerData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_pin_circle, color: Colors.blue),
            SizedBox(width: 8),
            Text("New Ride Request"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icon: Icons.my_location,
              color: Colors.green,
              label: "Seeker pickup",
              text: seekerData['seekerSourceName'] ?? 'Unknown',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_on,
              color: Colors.red,
              label: "Seeker drop-off",
              text: seekerData['seekerDestName'] ?? 'Unknown',
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: Icons.handshake,
              color: Colors.orange,
              label: "Meeting point (board here)",
              text: seekerData['meetingPointLat'] != null
                  ? "${(seekerData['meetingPointLat'] as num).toStringAsFixed(5)}, "
                      "${(seekerData['meetingPointLng'] as num).toStringAsFixed(5)}"
                  : "On your route",
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.flag,
              color: Colors.purple,
              label: "Drop point (exit here)",
              text: seekerData['dropPointLat'] != null
                  ? "${(seekerData['dropPointLat'] as num).toStringAsFixed(5)}, "
                      "${(seekerData['dropPointLng'] as num).toStringAsFixed(5)}"
                  : "On your route",
            ),
          ],
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          OutlinedButton(
            onPressed: () async {
              _dialogOpen.remove(seekerId); // ← FIX: allow re-trigger
              await _rejectRequest(seekerId);
              if (mounted) Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Decline"),
          ),
          ElevatedButton(
            onPressed: () async {
              _dialogOpen.remove(seekerId);
              await _acceptRequest(seekerId, seekerData);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectRequest(String seekerId) async {
    await FirebaseDatabase.instance
        .ref("rideRequests/$_rideId/$seekerId")
        .update({"status": "rejected"});
    await FirebaseDatabase.instance
        .ref("seekerMatches/$seekerId/$_rideId")
        .update({"status": "rejected"});
  }

  Future<void> _acceptRequest(
      String seekerId, Map<dynamic, dynamic> seekerData) async {
    // Mark request as accepted
    await FirebaseDatabase.instance
        .ref("rideRequests/$_rideId/$seekerId")
        .update({"status": "accepted"});

    await FirebaseDatabase.instance
        .ref("seekerMatches/$seekerId/$_rideId")
        .update({"status": "accepted"});

    // Create the active ride record
    await FirebaseDatabase.instance.ref("activeRides/$_rideId").set({
      "driverId": _driverId,
      "seekerId": seekerId,
      "driverSourceName": widget.sourceName,
      "driverDestName": widget.destinationName,
      "driverSourceLat": widget.source.latitude,
      "driverSourceLng": widget.source.longitude,
      "driverDestLat": widget.destination.latitude,
      "driverDestLng": widget.destination.longitude,
      "seekerSourceName": seekerData['seekerSourceName'] ?? '',
      "seekerDestName": seekerData['seekerDestName'] ?? '',
      "seekerSourceLat": seekerData['seekerSourceLat'],
      "seekerSourceLng": seekerData['seekerSourceLng'],
      "meetingPointLat": seekerData['meetingPointLat'],
      "meetingPointLng": seekerData['meetingPointLng'],
      "dropPointLat": seekerData['dropPointLat'],
      "dropPointLng": seekerData['dropPointLng'],
      "driverLat": null,
      "driverLng": null,
      "seekerLat": null,
      "seekerLng": null,
      "status": "ongoing",
      "createdAt": ServerValue.timestamp,
    });

    // Stop new seekers from matching to this ride
    await FirebaseDatabase.instance
        .ref("rideDrivers/$_rideId")
        .update({"status": "matched"});

    // Notify seeker that ride has been accepted
    await FirebaseDatabase.instance
        .ref("rideAccepted/$seekerId/$_rideId")
        .set({
      "driverId": _driverId,
      "rideId": _rideId,
      "acceptedAt": ServerValue.timestamp,
    });

    // TODO: Navigate to DriverLiveMap
    // if (mounted) Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => DriverLiveMap(rideId: _rideId!, seekerUid: seekerId),
    // ));
  }

  // ── End ride ──────────────────────────────────────────────────────────────

  Future<void> _endRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("End Ride?"),
        content: const Text(
            "This will mark your ride as completed and remove you from active drivers."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("End",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && _rideId != null) {
      await DriverRouteService.completeRide(_rideId!);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Map helpers ───────────────────────────────────────────────────────────

  LatLngBounds _bounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Fetching route & creating ride..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Ride"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _endRide,
            child: const Text("End Ride",
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              if (_routePoints.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(
                        _bounds(_routePoints), 60),
                  );
                });
              }
            },
            initialCameraPosition:
                CameraPosition(target: widget.source, zoom: 13),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // ── Bottom info card ───────────────────────────────────────
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.trip_origin,
                      color: Colors.green,
                      label: "From",
                      text: widget.sourceName,
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.location_on,
                      color: Colors.red,
                      label: "To",
                      text: widget.destinationName,
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Live — waiting for seeker requests",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared info row widget ────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey)),
              Text(text,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}