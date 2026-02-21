import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
  GoogleMapController? mapController;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  LatLng? sourceLatLng;
  LatLng? destLatLng;

  // 🔴 PUT YOUR ORS KEY HERE
  static const String orsKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _initRoute();
  }

  // =====================================================
  // 🔥 MAIN INIT
  // =====================================================
  Future<void> _initRoute() async {
    await _fetchHubCoordinates();
    await _drawRoute();
    setState(() {});
  }

  // =====================================================
  // 📍 FETCH HUB COORDINATES FROM FIRESTORE
  // =====================================================
  Future<void> _fetchHubCoordinates() async {
    final sourceLocality = widget.bookingData["sourceLocality"];
    final sourceHub = widget.bookingData["sourceHub"];
    final destLocality = widget.bookingData["destLocality"];
    final destHub = widget.bookingData["destinationHub"];

    final firestore = FirebaseFirestore.instance;

    // 🔹 SOURCE HUB
    final sourceDoc = await firestore
        .collection("EV-Hubs")
        .doc(sourceLocality)
        .collection("Hubs")
        .doc(sourceHub)
        .get();

    final sourceData = sourceDoc.data()!;
    final sourceCoords = sourceData["Up"] ?? sourceData["Down"];

    sourceLatLng =
        LatLng(sourceCoords["lat"], sourceCoords["long"]);

    // 🔹 DEST HUB
    final destDoc = await firestore
        .collection("EV-Hubs")
        .doc(destLocality)
        .collection("Hubs")
        .doc(destHub)
        .get();

    final destData = destDoc.data()!;
    final destCoords = destData["Up"] ?? destData["Down"];

    destLatLng =
        LatLng(destCoords["lat"], destCoords["long"]);

    // 🔹 markers
    markers.add(
      Marker(
        markerId: const MarkerId("source"),
        position: sourceLatLng!,
        infoWindow: const InfoWindow(title: "Source Hub"),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId("destination"),
        position: destLatLng!,
        infoWindow: const InfoWindow(title: "Destination Hub"),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
      ),
    );
  }

  // =====================================================
  // 🧭 DRAW ROUTE USING ORS
  // =====================================================
  Future<void> _drawRoute() async {
    if (sourceLatLng == null || destLatLng == null) return;

    final response = await http.post(
      Uri.parse(
          "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
      headers: {
        "Authorization": orsKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "coordinates": [
          [sourceLatLng!.longitude, sourceLatLng!.latitude],
          [destLatLng!.longitude, destLatLng!.latitude],
        ]
      }),
    );

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final coords =
        data["features"][0]["geometry"]["coordinates"] as List;

    final points = coords
        .map<LatLng>((c) => LatLng(c[1], c[0]))
        .toList();

    polylines.add(
      Polyline(
        polylineId: const PolylineId("ride_route"),
        points: points,
        width: 6,
        color: Colors.blue,
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (sourceLatLng == null || destLatLng == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Started"),
        backgroundColor: Colors.green,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: sourceLatLng!,
          zoom: 14,
        ),
        markers: markers,
        polylines: polylines,
        myLocationEnabled: true,
        onMapCreated: (controller) {
          mapController = controller;
          _fitCamera();
        },
      ),
    );
  }

  // =====================================================
  // 🎯 FIT CAMERA TO ROUTE
  // =====================================================
  void _fitCamera() {
    if (mapController == null ||
        sourceLatLng == null ||
        destLatLng == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        sourceLatLng!.latitude < destLatLng!.latitude
            ? sourceLatLng!.latitude
            : destLatLng!.latitude,
        sourceLatLng!.longitude < destLatLng!.longitude
            ? sourceLatLng!.longitude
            : destLatLng!.longitude,
      ),
      northeast: LatLng(
        sourceLatLng!.latitude > destLatLng!.latitude
            ? sourceLatLng!.latitude
            : destLatLng!.latitude,
        sourceLatLng!.longitude > destLatLng!.longitude
            ? sourceLatLng!.longitude
            : destLatLng!.longitude,
      ),
    );

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }
}
