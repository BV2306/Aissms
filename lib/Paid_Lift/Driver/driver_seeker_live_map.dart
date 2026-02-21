import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class DriverLiveMap extends StatefulWidget {
  final String rideId;
  final String seekerUid;

  const DriverLiveMap({
    super.key,
    required this.rideId,
    required this.seekerUid,
  });

  @override
  State<DriverLiveMap> createState() => _DriverLiveMapState();
}

class _DriverLiveMapState extends State<DriverLiveMap> {
  LatLng? driverLoc;
  LatLng? seekerLoc;

  @override
  void initState() {
    super.initState();

    FirebaseDatabase.instance
        .ref("seekers/${widget.seekerUid}/location")
        .onValue
        .listen((e) {
      final data = e.snapshot.value as Map;
      setState(() =>
          seekerLoc = LatLng(data["lat"], data["lng"]));
    });

    Geolocator.getPositionStream().listen((pos) {
      setState(() =>
          driverLoc = LatLng(pos.latitude, pos.longitude));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Ride")),
      body: FlutterMap(
        options: MapOptions(initialZoom: 14),
        children: [
          TileLayer(
              urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
          MarkerLayer(markers: [
            if (driverLoc != null)
              Marker(
                  point: driverLoc!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.car_rental)),
            if (seekerLoc != null)
              Marker(
                  point: seekerLoc!,
                  width: 50,
                  height: 50,
                  child: const Icon(Icons.person_pin)),
          ])
        ],
      ),
    );
  }
}