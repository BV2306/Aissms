import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  List<LatLng> routePoints = [];
  bool isLoading = true;

  static const String googleApiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  @override
  void initState() {
    super.initState();
    fetchRoute();
  }

  Future<void> fetchRoute() async {
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?"
      "origin=${widget.source.latitude},${widget.source.longitude}"
      "&destination=${widget.destination.latitude},${widget.destination.longitude}"
      "&key=$googleApiKey",
    );

    final response = await http.get(url);
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final encodedPolyline =
          data['routes'][0]['overview_polyline']['points'];

      final decoded = decodePolyline(encodedPolyline);

      setState(() {
        routePoints = decoded;
        isLoading = false;
      });

      await storeRouteToFirestore(decoded);
    }
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> storeRouteToFirestore(List<LatLng> points) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    List<Map<String, dynamic>> routeData = points.map((p) {
      return {
        "lat": p.latitude,
        "lng": p.longitude,
      };
    }).toList();

    await FirebaseFirestore.instance.collection("activeDrivers").doc(uid).set({
      "userId": uid,
      "sourceName": widget.sourceName,
      "destinationName": widget.destinationName,
      "route": routeData,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Route")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: widget.source,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName:
                      "com.example.lastmile_transport",
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.source,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on,
                          color: Colors.green, size: 40),
                    ),
                    Marker(
                      point: widget.destination,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}