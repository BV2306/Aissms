import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class SeekerLocationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> startLocationUpdates() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    ).listen((Position position) {
      _db.child("seekers/$uid").set({
        "location": {
          "lat": position.latitude,
          "lng": position.longitude,
        },
        "updatedAt": ServerValue.timestamp,
      });
    });
  }
}