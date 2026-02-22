import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

/// Handles real-time GPS tracking for the seeker.
///
/// Writes to: `seekers/{uid} { uid, isActive, location: { lat, lng } }`
class SeekerLocationService {
  StreamSubscription<Position>? _positionSub;

  // ── Start tracking ────────────────────────────────────────────────────────

  Future<void> startTracking(String uid) async {
    final db = FirebaseDatabase.instance.ref("seekers/$uid");

    // ── Permission checks ─────────────────────────────────────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled. Please enable GPS.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
          "Location permission denied. Please allow location access.");
    }

    // ── Write initial position ────────────────────────────────────────
    final initial = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await db.set({
      "uid": uid,
      "isActive": true,
      "location": {
        "lat": initial.latitude,
        "lng": initial.longitude,
      },
    });

    // ── Stream updates ────────────────────────────────────────────────
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 metres
      ),
    ).listen((pos) {
      db.update({
        "isActive": true,
        "location": {"lat": pos.latitude, "lng": pos.longitude},
      });
    });
  }

  // ── Stop tracking ─────────────────────────────────────────────────────────

  Future<void> stopTracking(String uid) async {
    await _positionSub?.cancel();
    _positionSub = null;
    await FirebaseDatabase.instance
        .ref("seekers/$uid")
        .update({"isActive": false});
  }
}