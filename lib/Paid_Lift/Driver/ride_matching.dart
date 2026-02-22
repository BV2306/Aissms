import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Handles automatic matching between a seeker's requested route
/// and all active driver routes stored in Firebase under "rideDrivers/".
///
/// Matching criteria (either condition satisfies):
///   1. Seeker's pickup  is within [_matchRadiusMeters] of any point on driver's route
///      AND seeker's drop-off is within [_matchRadiusMeters] of a later point on that route.
///   2. Seeker's pickup  is within [_matchRadiusMeters] of driver's source location.
///      AND seeker's drop-off is within [_matchRadiusMeters] of driver's destination.
///
/// On a successful match the service writes:
///   - rideRequests/{rideId}/{seekerId}  — notifies the driver
///   - seekerMatches/{seekerId}/{rideId} — lets the seeker see the match in their UI
class RideMatchingService {
  final String seekerId;

  LatLng? _seekerSource;
  LatLng? _seekerDestination;
  String _seekerSourceName = "";
  String _seekerDestName = "";

  Timer? _timer;

  /// Matching radius in metres (2 km).
  static const double _matchRadiusMeters = 2000.0;

  RideMatchingService({required this.seekerId});

  // ─── Public API ───────────────────────────────────────────────────────────

  void setSeekerRoute({
    required LatLng source,
    required LatLng destination,
    required String sourceName,
    required String destName,
  }) {
    _seekerSource = source;
    _seekerDestination = destination;
    _seekerSourceName = sourceName;
    _seekerDestName = destName;
  }

  /// Start polling for matching driver rides every 30 seconds.
  void startMatching() {
    _timer?.cancel();
    _runMatching(); // immediate first pass
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _runMatching());
  }

  void stopMatching() {
    _timer?.cancel();
    _timer = null;
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _runMatching() async {
    if (_seekerSource == null || _seekerDestination == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref("rideDrivers")
          .orderByChild("status")
          .equalTo("active")
          .get();

      if (!snapshot.exists) return;

      final rides = Map<dynamic, dynamic>.from(snapshot.value as Map);

      for (final entry in rides.entries) {
        final rideId = entry.key as String;
        final rideData = Map<dynamic, dynamic>.from(entry.value as Map);

        // Skip own rides
        if (rideData['driverId'] == seekerId) continue;

        // Skip if a request already exists for this ride
        final existing = await FirebaseDatabase.instance
            .ref("rideRequests/$rideId/$seekerId")
            .get();
        if (existing.exists) continue;

        // Decode route polyline stored as list of {lat, lng} maps
        final rawRoute = rideData['route'];
        if (rawRoute == null) continue;

        final route = (rawRoute as List)
            .map<LatLng>((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList();

        if (route.isEmpty) continue;

        // ── Find closest route index to seeker's pickup ──────────────────
        final pickupIndex = _closestIndex(route, _seekerSource!);
        final pickupDist = _haversine(route[pickupIndex], _seekerSource!);

        if (pickupDist > _matchRadiusMeters) continue;

        // ── Find closest route index to seeker's drop-off (must come AFTER pickup) ─
        int dropIndex = -1;
        double minDropDist = double.infinity;

        for (int i = pickupIndex; i < route.length; i++) {
          final d = _haversine(route[i], _seekerDestination!);
          if (d < minDropDist) {
            minDropDist = d;
            dropIndex = i;
          }
        }

        if (dropIndex == -1 || minDropDist > _matchRadiusMeters) continue;

        // ── Match found ──────────────────────────────────────────────────
        final meetingPoint = route[pickupIndex];
        final dropPoint = route[dropIndex];

        final requestData = {
          "seekerId": seekerId,
          "seekerSourceName": _seekerSourceName,
          "seekerDestName": _seekerDestName,
          "seekerSourceLat": _seekerSource!.latitude,
          "seekerSourceLng": _seekerSource!.longitude,
          "seekerDestLat": _seekerDestination!.latitude,
          "seekerDestLng": _seekerDestination!.longitude,
          "meetingPointLat": meetingPoint.latitude,
          "meetingPointLng": meetingPoint.longitude,
          "dropPointLat": dropPoint.latitude,
          "dropPointLng": dropPoint.longitude,
          "status": "pending",
          "createdAt": ServerValue.timestamp,
        };

        // Notify driver
        await FirebaseDatabase.instance
            .ref("rideRequests/$rideId/$seekerId")
            .set(requestData);

        // Notify seeker (for the matched-drivers bottom sheet)
        await FirebaseDatabase.instance
            .ref("seekerMatches/$seekerId/$rideId")
            .set({
          "rideId": rideId,
          "driverId": rideData['driverId'],
          "sourceName": rideData['sourceName'] ?? '',
          "destinationName": rideData['destinationName'] ?? '',
          "meetingPointLat": meetingPoint.latitude,
          "meetingPointLng": meetingPoint.longitude,
          "dropPointLat": dropPoint.latitude,
          "dropPointLng": dropPoint.longitude,
          "status": "pending",
          "matchedAt": ServerValue.timestamp,
        });
      }
    } catch (e) {
      // Silently log — don't crash the UI
      debugPrint("[RideMatchingService] Error: $e");
    }
  }

  // ─── Geometry helpers ─────────────────────────────────────────────────────

  /// Haversine distance in metres between two LatLng points.
  static double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final sin1 = sin(dLat / 2);
    final sin2 = sin(dLng / 2);
    final c = sin1 * sin1 + cos(lat1) * cos(lat2) * sin2 * sin2;
    return R * 2 * atan2(sqrt(c), sqrt(1 - c));
  }

  /// Index of the route point closest to [point].
  static int _closestIndex(List<LatLng> route, LatLng point) {
    double minDist = double.infinity;
    int idx = 0;
    for (int i = 0; i < route.length; i++) {
      final d = _haversine(route[i], point);
      if (d < minDist) {
        minDist = d;
        idx = i;
      }
    }
    return idx;
  }

  /// Exposes the haversine helper publicly so other services can reuse it.
  static double distanceInMeters(LatLng a, LatLng b) => _haversine(a, b);
}