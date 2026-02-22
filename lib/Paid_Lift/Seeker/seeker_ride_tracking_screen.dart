import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Shown to the SEEKER automatically after a driver accepts their request.
/// Seeker did nothing here — this screen opens via the Firestore listener in SeekerDashboard.
class SeekerRideTrackingScreen extends StatefulWidget {
  final String driverUid;

  const SeekerRideTrackingScreen({super.key, required this.driverUid});

  @override
  State<SeekerRideTrackingScreen> createState() => _SeekerRideTrackingScreenState();
}

class _SeekerRideTrackingScreenState extends State<SeekerRideTrackingScreen> {
  final MapController _mapController = MapController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  LatLng? driverLocation;
  LatLng? seekerLocation;

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
    _trackAndBroadcastSeekerLocation();
  }

  /// Listens to driver's real-time position from Realtime DB
  void _listenToDriverLocation() {
    FirebaseDatabase.instance
        .ref("driverLocations/${widget.driverUid}")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || !mounted) return;
      try {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null) {
          setState(() => driverLocation = LatLng(
            (lat as num).toDouble(),
            (lng as num).toDouble(),
          ));
          _recenterMap();
        }
      } catch (e) {
        debugPrint("Error parsing driver location: $e");
      }
    });
  }

  /// Updates seeker position in Realtime DB so driver can also see seeker on their map
  void _trackAndBroadcastSeekerLocation() {
    if (_uid == null) return;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => seekerLocation = LatLng(pos.latitude, pos.longitude));

      FirebaseDatabase.instance.ref("seekers/$_uid/location").set({
        "lat": pos.latitude,
        "lng": pos.longitude,
      });

      _recenterMap();
    });
  }

  void _recenterMap() {
    if (driverLocation != null && seekerLocation != null) {
      final centerLat = (driverLocation!.latitude + seekerLocation!.latitude) / 2;
      final centerLng = (driverLocation!.longitude + seekerLocation!.longitude) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 14);
    }
  }

  String _formatDistance() {
    if (driverLocation == null || seekerLocation == null) return "";
    final meters = Geolocator.distanceBetween(
      seekerLocation!.latitude, seekerLocation!.longitude,
      driverLocation!.latitude, driverLocation!.longitude,
    );
    if (meters < 1000) return "${meters.toStringAsFixed(0)}m away";
    return "${(meters / 1000).toStringAsFixed(2)}km away";
  }

  @override
  Widget build(BuildContext context) {
    final center = seekerLocation ?? driverLocation ?? const LatLng(18.5204, 73.8567);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Accepted! 🎉"),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false, // prevent accidental back navigation
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.lastmile_transport",
              ),
              MarkerLayer(
                markers: [
                  if (seekerLocation != null)
                    Marker(
                      point: seekerLocation!,
                      width: 60, height: 70,
                      child: const Column(
                        children: [
                          Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                          Text("You", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue,
                          )),
                        ],
                      ),
                    ),
                  if (driverLocation != null)
                    Marker(
                      point: driverLocation!,
                      width: 60, height: 70,
                      child: const Column(
                        children: [
                          Icon(Icons.directions_car, color: Colors.green, size: 40),
                          Text("Driver", style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green,
                          )),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top status banner
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.green.withOpacity(0.92),
              child: const Text(
                "✅ Your ride has been accepted! Driver is heading your way.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Bottom distance card
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.green, size: 28),
                        const SizedBox(height: 4),
                        const Text("Driver", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          driverLocation != null ? _formatDistance() : "Locating...",
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    const Column(
                      children: [
                        Icon(Icons.person, color: Colors.blue, size: 28),
                        SizedBox(height: 4),
                        Text("You", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Waiting here", style: TextStyle(color: Colors.black54, fontSize: 12)),
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