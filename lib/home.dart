import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import './widgets/app_drawer.dart';

class EVMapScreen extends StatefulWidget {
  const EVMapScreen({super.key});

  @override
  State<EVMapScreen> createState() => _EVMapScreenState();
}

class _EVMapScreenState extends State<EVMapScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;

  // 🔥 Static Hub Data
  final double hubLat = 18.608913;
  final double hubLong = 74.01542;
  final String hubName = "EV-Hubs ↓";

  Set<Marker> markers = {};
  double distanceInKm = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await Geolocator.requestPermission();

    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    calculateDistance();
    createMarkers();

    setState(() {});
  }

  // 📏 Distance Formula
  double calculateDistanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371;
    var dLat = (lat2 - lat1) * pi / 180;
    var dLon = (lon2 - lon1) * pi / 180;

    var a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void calculateDistance() {
    distanceInKm = calculateDistanceInKm(
      currentPosition!.latitude,
      currentPosition!.longitude,
      hubLat,
      hubLong,
    );
  }

  void createMarkers() {
    markers.clear();

    // User marker
    markers.add(
      Marker(
        markerId: const MarkerId("user"),
        position:
            LatLng(currentPosition!.latitude, currentPosition!.longitude),
        infoWindow: const InfoWindow(title: "You"),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // Hub marker
    markers.add(
      Marker(
        markerId: const MarkerId("hub"),
        position: LatLng(hubLat, hubLong),
        infoWindow: InfoWindow(
          title: hubName,
          snippet: "Tap for directions",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(), // ✅ ADDED DRAWER
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "EV Map",
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SlidingUpPanel(
        minHeight: 180,
        maxHeight: 320,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        panel: buildBottomPanel(),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target:
                LatLng(currentPosition!.latitude, currentPosition!.longitude),
            zoom: 14,
          ),
          myLocationEnabled: true,
          markers: markers,
          onMapCreated: (controller) {
            mapController = controller;
          },
        ),
      ),
    );
  }

  Widget buildBottomPanel() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              height: 5,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Nearest EV Hub",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.electric_bike, color: Colors.white),
              ),
              title: Text(
                hubName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text("${distanceInKm.toStringAsFixed(2)} km away"),
              trailing: const Icon(
                Icons.arrow_downward,
                color: Colors.green,
              ),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {},
            child: const Text(
              "Get Directions",
              style: TextStyle(fontSize: 16),
            ),
          )
        ],
      ),
    );
  }
}