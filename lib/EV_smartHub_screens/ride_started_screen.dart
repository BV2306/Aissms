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

  // 🔴 PUT YOUR ORS KEY
  static const String orsKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  // =====================================================
  // 🔥 MASTER INIT (runs once only)
  // =====================================================
  Future<void> _initEverything() async {
    try {
      await _getUserLocation();
      await _fetchHubCoordinates();
      await _drawRouteSmart();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Init error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // =====================================================
  // 📍 USER LOCATION
  // =====================================================
  Future<void> _getUserLocation() async {
    await Geolocator.requestPermission();

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _userLocation = LatLng(pos.latitude, pos.longitude);
  }

  // =====================================================
  // 📍 FETCH HUBS
  // =====================================================
  Future<void> _fetchHubCoordinates() async {
    final sourceLocality = widget.bookingData["sourceLocality"];
    final sourceHub = widget.bookingData["sourceHub"];
    final destLocality = widget.bookingData["destLocality"];
    final destHub = widget.bookingData["destinationHub"];

    final fs = FirebaseFirestore.instance;

    // SOURCE
    final sDoc = await fs
        .collection("EV-Hubs")
        .doc(sourceLocality)
        .collection("Hubs")
        .doc(sourceHub)
        .get();

    final sData = sDoc.data();
    final sCoords = sData?["Up"] ?? sData?["Down"];
    _source = LatLng(sCoords["lat"] * 1.0, sCoords["long"] * 1.0);

    // DEST
    final dDoc = await fs
        .collection("EV-Hubs")
        .doc(destLocality)
        .collection("Hubs")
        .doc(destHub)
        .get();

    final dData = dDoc.data();
    final dCoords = dData?["Up"] ?? dData?["Down"];
    _destination =
        LatLng(dCoords["lat"] * 1.0, dCoords["long"] * 1.0);

    // markers
    _markers.add(
      Marker(
        markerId: const MarkerId("source"),
        position: _source!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId("dest"),
        position: _destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId("user"),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
      ),
    );
  }

  // =====================================================
  // 🧠 SMART ROUTING LOGIC
  // =====================================================
  Future<void> _drawRouteSmart() async {
    if (_userLocation == null ||
        _source == null ||
        _destination == null) return;

    // distance user → source
    final distToSource = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      _source!.latitude,
      _source!.longitude,
    );

    // 🚀 CASE 1: user far from source → route user → source → dest
    if (distToSource > 120) {
      await _drawRoute(_userLocation!, _source!,
          id: "user_to_source", color: Colors.orange);

      await _drawRoute(_source!, _destination!,
          id: "source_to_dest", color: Colors.blue);
    }
    // 🚀 CASE 2: user already near source → only source → dest
    else {
      await _drawRoute(_source!, _destination!,
          id: "source_to_dest", color: Colors.blue);
    }
  }

  // =====================================================
  // 🧭 ORS ROUTE DRAW
  // =====================================================
  Future<void> _drawRoute(
    LatLng start,
    LatLng end, {
    required String id,
    required Color color,
  }) async {
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
          coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

      _polylines.add(
        Polyline(
          polylineId: PolylineId(id),
          points: pts,
          width: 6,
          color: color,
        ),
      );
    } catch (e) {
      debugPrint("ORS error: $e");
    }
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
        backgroundColor: Colors.green,
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

          // 🚀 START RIDE BUTTON
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Ride Started 🚴")),
                );
              },
              child: const Text(
                "Start Ride",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // =====================================================
  // 🎯 FIT CAMERA
  // =====================================================
  void _fitCamera() {
    if (_mapController == null ||
        _userLocation == null ||
        _destination == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _userLocation!.latitude < _destination!.latitude
            ? _userLocation!.latitude
            : _destination!.latitude,
        _userLocation!.longitude < _destination!.longitude
            ? _userLocation!.longitude
            : _destination!.longitude,
      ),
      northeast: LatLng(
        _userLocation!.latitude > _destination!.latitude
            ? _userLocation!.latitude
            : _destination!.latitude,
        _userLocation!.longitude > _destination!.longitude
            ? _userLocation!.longitude
            : _destination!.longitude,
      ),
    );

    _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }
}

