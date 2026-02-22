import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles creating a driver's active ride in Firebase.
///
/// Firebase structure written:
/// ```
/// rideDrivers/{rideId}: {
///   driverId, sourceName, destinationName,
///   sourceLat, sourceLng, destLat, destLng,
///   route: [{lat, lng}, ...],
///   status: "active",
///   createdAt
/// }
/// ```
class DriverRouteService {
  // ── Replace with your actual Google Maps API key ──────────────────────────
  static const String _apiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  /// Fetches the route from Google Directions, stores it in Firebase,
  /// and returns `(rideId, routePoints)`.
  static Future<(String, List<LatLng>)> createActiveRide({
    required LatLng source,
    required LatLng destination,
    required String sourceName,
    required String destinationName,
  }) async {
    final driverId = FirebaseAuth.instance.currentUser!.uid;
    final rideId = const Uuid().v4();

    // ── Fetch route from Google Directions API ────────────────────────────
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json"
      "?origin=${source.latitude},${source.longitude}"
      "&destination=${destination.latitude},${destination.longitude}"
      "&key=$_apiKey",
    );

    final response = await http.get(url);
    final data = json.decode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw Exception("Directions API error: ${data['status']}");
    }

    final encoded =
        data['routes'][0]['overview_polyline']['points'] as String;
    final points = _decodePolyline(encoded);

    if (points.isEmpty) throw Exception("Empty route returned");

    // Subsample to at most 500 points to stay within Firebase write limits
    final routeSample = _subsample(points, 500);

    final routeData = routeSample
        .map((p) => {"lat": p.latitude, "lng": p.longitude})
        .toList();

    // ── Write to Firebase ─────────────────────────────────────────────────
    await FirebaseDatabase.instance.ref("rideDrivers/$rideId").set({
      "driverId": driverId,
      "sourceName": sourceName,
      "destinationName": destinationName,
      "sourceLat": source.latitude,
      "sourceLng": source.longitude,
      "destLat": destination.latitude,
      "destLng": destination.longitude,
      "route": routeData,
      "status": "active",
      "createdAt": ServerValue.timestamp,
    });

    return (rideId, points);
  }

  /// Marks a ride as completed and removes driver presence.
  static Future<void> completeRide(String rideId) async {
    await FirebaseDatabase.instance
        .ref("rideDrivers/$rideId")
        .update({"status": "completed"});

    final driverId = FirebaseAuth.instance.currentUser?.uid;
    if (driverId != null) {
      await FirebaseDatabase.instance.ref("drivers/$driverId").remove();
    }
  }

  // ── Polyline decoder ──────────────────────────────────────────────────────

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// Evenly subsample [points] to at most [maxPoints] entries.
  static List<LatLng> _subsample(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = points.length / maxPoints;
    return List.generate(
      maxPoints,
      (i) => points[(i * step).round().clamp(0, points.length - 1)],
    );
  }

  // ── Public geometry helpers ───────────────────────────────────────────────

  /// Haversine distance in metres between two coordinates.
  static double distanceInMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final s1 = sin(dLat / 2);
    final s2 = sin(dLng / 2);
    final c = s1 * s1 + cos(lat1) * cos(lat2) * s2 * s2;
    return R * 2 * atan2(sqrt(c), sqrt(1 - c));
  }
}