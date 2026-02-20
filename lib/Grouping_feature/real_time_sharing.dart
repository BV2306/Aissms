import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SimpleLocationPage(),
  ));
}


class SimpleLocationPage extends StatefulWidget {
  const SimpleLocationPage({super.key});


  @override
  State<SimpleLocationPage> createState() => _SimpleLocationPageState();
}


class _SimpleLocationPageState extends State<SimpleLocationPage> {


  double? latitude;
  double? longitude;


  StreamSubscription<Position>? positionStream;


  @override
  void initState() {
    super.initState();
    startLocationTracking();
  }


  Future<void> startLocationTracking() async {


    LocationPermission permission = await Geolocator.requestPermission();


    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("Location permission denied");
      return;
    }


    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {


      latitude = position.latitude;
      longitude = position.longitude;


      // 🔥 Print in console
      print("Latitude: $latitude");
      print("Longitude: $longitude");


      setState(() {});
    });
  }


  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Location"),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: latitude == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Latitude:",
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    latitude!.toStringAsFixed(6),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Longitude:",
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    longitude!.toStringAsFixed(6),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}





