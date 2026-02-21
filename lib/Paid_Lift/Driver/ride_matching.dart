import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

class RideMatchingService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String seekerId;
  StreamSubscription<DatabaseEvent>? _seekerSub;

  /// Distance checker
  final Distance distanceCalculator = Distance();

  RideMatchingService({required this.seekerId});

  /// Start matching seeker with active rides
  void startMatching() {
    _seekerSub =
        _db.child("seekers/$seekerId/location").onValue.listen((event) async {
      if (event.snapshot.value == null) return;

      final loc = Map<String, dynamic>.from(event.snapshot.value as Map);
      final LatLng seekerLoc =
          LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble());

      await _matchWithActiveRides(seekerLoc);
    });
  }

  /// Check active rides and create rideRequests if matched
  Future<void> _matchWithActiveRides(LatLng seekerLoc) async {
  final ridesSnapshot = await _db.child("activeRides").get();
  if (!ridesSnapshot.exists) return;

  final rides = Map<dynamic, dynamic>.from(ridesSnapshot.value as Map);

  for (var entry in rides.entries) {
    final rideId = entry.key;
    final rideData = Map<String, dynamic>.from(entry.value);
    final List routePointsData = rideData['route'] ?? [];

    final routePoints = routePointsData.map((p) {
      return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
    }).toList();

    final isMatched = routePoints.any(
        (point) => distanceCalculator.as(LengthUnit.Meter, seekerLoc, point) <= 500);

    final rideRequestRef = _db.child("rideRequests/$rideId/$seekerId");
    final rideDriverRef = _db.child("rideDrivers/$seekerId/$rideId");

    if (isMatched) {
      // Check if request already exists
      final existingSnapshot = await rideRequestRef.get();
      String status = "pending";

      if (existingSnapshot.exists) {
        final existing = Map<String, dynamic>.from(existingSnapshot.value as Map);
        status = existing['status'] ?? "pending"; // preserve current status
      }

      // Create/update ride request
      await rideRequestRef.set({
        "seekerId": seekerId,
        "driverId": rideData['driverId'],
        "status": status,
        "matchedAt": ServerValue.timestamp,
      });

      // Update rideDrivers collection
      await rideDriverRef.set({
        "rideId": rideId,
        "driverId": rideData['driverId'],
        "sourceName": rideData['sourceName'],
        "destinationName": rideData['destinationName'],
        "status": rideData['status'],
        "route": rideData['route'],
        "matchedAt": ServerValue.timestamp,
      });
    } else {
      // Remove ride if seeker moved away
      await rideDriverRef.remove();
      await rideRequestRef.remove();
    }
  }
}
  void stopMatching() {
    _seekerSub?.cancel();
  }
}