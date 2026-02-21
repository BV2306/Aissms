import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RideStartedScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const RideStartedScreen({
    super.key,
    required this.bookingData,
  });

  @override
  State<RideStartedScreen> createState() => _RideStartedScreenState();
}

class _RideStartedScreenState extends State<RideStartedScreen> {
  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _source;
  LatLng? _destination;
  LatLng? _userLocation;

  bool _loading = true;

  static const String orsKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  Future<void> _initEverything() async {
    try {
      await _getUserLocation();
      await _fetchHubCoordinates();
      await _drawRouteSmart();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint("Init error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _getUserLocation() async {
    await Geolocator.requestPermission();
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _userLocation = LatLng(pos.latitude, pos.longitude);
  }

  // =====================================================
  // 📍 FETCH HUBS — supports both booking types
  // =====================================================
  Future<void> _fetchHubCoordinates() async {
    final bd = widget.bookingData;
    final bool isRental = (bd["bookingType"] as String?) == "rental";

    final sourceLocality = bd["sourceLocality"] as String;
    final sourceHub = bd["sourceHub"] as String;

    // For hub-to-hub: destLocality + destinationHub
    // For rental: submissionLocality + submissionHub
    final destLocality = isRental
        ? bd["submissionLocality"] as String? ?? sourceLocality
        : bd["destLocality"] as String? ?? sourceLocality;
    final destHub = isRental
        ? bd["submissionHub"] as String? ?? sourceHub
        : bd["destinationHub"] as String? ?? sourceHub;

    final fs = FirebaseFirestore.instance;

    // ─── Source hub ─────────────────────────────────────
    final sDoc = await fs
        .collection("EV-Hubs")
        .doc(sourceLocality)
        .collection("Hubs")
        .doc(sourceHub)
        .get();

    final sData = sDoc.data();
    final sCoords = sData?["Up"] ?? sData?["Down"];
    _source = LatLng(
        (sCoords["lat"] as num).toDouble(),
        (sCoords["long"] as num? ??
                sCoords["lon"] as num? ??
                sCoords["lng"] as num)
            .toDouble());

    // ─── Destination hub ─────────────────────────────────
    final dDoc = await fs
        .collection("EV-Hubs")
        .doc(destLocality)
        .collection("Hubs")
        .doc(destHub)
        .get();

    final dData = dDoc.data();
    final dCoords = dData?["Up"] ?? dData?["Down"];
    _destination = LatLng(
        (dCoords["lat"] as num).toDouble(),
        (dCoords["long"] as num? ??
                dCoords["lon"] as num? ??
                dCoords["lng"] as num)
            .toDouble());

    // ─── Markers ─────────────────────────────────────────
    _markers.add(Marker(
      markerId: const MarkerId("source"),
      position: _source!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: "Pickup: $sourceHub"),
    ));

    _markers.add(Marker(
      markerId: const MarkerId("dest"),
      position: _destination!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
          title: isRental ? "Return: $destHub" : "Destination: $destHub"),
    ));

    _markers.add(Marker(
      markerId: const MarkerId("user"),
      position: _userLocation!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: "You"),
    ));
  }

  // =====================================================
  // 🧠 SMART ROUTING
  // =====================================================
  Future<void> _drawRouteSmart() async {
    if (_userLocation == null || _source == null || _destination == null) return;

    final distToSource = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      _source!.latitude,
      _source!.longitude,
    );

    if (distToSource > 120) {
      await _drawRoute(_userLocation!, _source!,
          id: "user_to_source", color: Colors.orange);
    }

    await _drawRoute(_source!, _destination!,
        id: "source_to_dest", color: Colors.blue);
  }

  Future<void> _drawRoute(LatLng start, LatLng end,
      {required String id, required Color color}) async {
    try {
      final res = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [start.longitude, start.latitude],
            [end.longitude, end.latitude],
          ]
        }),
      );

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final coords =
          data["features"][0]["geometry"]["coordinates"] as List;
      final pts =
          coords.map<LatLng>((c) => LatLng(c[1] as double, c[0] as double)).toList();

      _polylines.add(Polyline(
        polylineId: PolylineId(id),
        points: pts,
        width: 6,
        color: color,
      ));
    } catch (e) {
      debugPrint("ORS error: $e");
    }
  }

  void _fitCamera() {
    if (_mapController == null ||
        _userLocation == null ||
        _destination == null) return;

    final allPoints = [_userLocation!, _source!, _destination!];
    double minLat = allPoints[0].latitude, maxLat = allPoints[0].latitude;
    double minLng = allPoints[0].longitude, maxLng = allPoints[0].longitude;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final bd = widget.bookingData;
    final bool isRental = (bd["bookingType"] as String?) == "rental";

    return Scaffold(
      appBar: AppBar(
        title: Text(isRental ? "Rental Ride" : "Navigation"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation!,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            onMapCreated: (c) {
              _mapController = c;
              _fitCamera();
            },
          ),

          // ─── Ride info card ──────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isRental
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _infoRow(Icons.pedal_bike, "Rental",
                              "${bd['sourceHub']}  →  ${bd['submissionHub']}"),
                          _infoRow(Icons.schedule, "Time",
                              "${bd['startTime']} – ${bd['endTime']}"),
                          _infoRow(Icons.calendar_today, "Date",
                              "${bd['scheduledDate']}"),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _infoRow(Icons.route, "Route",
                              "${bd['sourceHub']}  →  ${bd['destinationHub']}"),
                          _infoRow(Icons.timer, "Allocated",
                              "${bd['allocatedMinutes']} min"),
                        ],
                      ),
              ),
            ),
          ),

          // ─── Start Ride button ───────────────────────
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ride Started 🚴")),
                );
              },
              child: Text(
                isRental ? "Start Rental Ride 🚲" : "Start Ride 🚴",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Text("$label: ",
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}