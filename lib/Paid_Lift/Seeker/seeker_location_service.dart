import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class SeekerLocationService {
  StreamSubscription<Position>? _positionStream;

  Future<void> startTracking(String uid) async {
    final DatabaseReference db = FirebaseDatabase.instance.ref("seekers/$uid");

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    // Get initial location and write to DB
    final position = await Geolocator.getCurrentPosition();
    await db.set({
      "uid": uid,
      "isActive": true,
      "location": {"lat": position.latitude, "lng": position.longitude},
    });

    // Listen for location changes
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      db.update({
        "isActive": true,
        "location": {"lat": pos.latitude, "lng": pos.longitude},
      });
    });
  }

  Future<void> stopTracking(String uid) async {
    _positionStream?.cancel();
    final DatabaseReference db = FirebaseDatabase.instance.ref("seekers/$uid");
    await db.update({"isActive": false});
  }
}