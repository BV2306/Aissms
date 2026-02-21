import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class DriverRouteService {
  static const String googleApiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  static Future<(String, List<LatLng>)> createActiveRide({
    required LatLng source,
    required LatLng destination,
    required String sourceName,
    required String destinationName,
  }) async {
    final driverId = FirebaseAuth.instance.currentUser!.uid;
    final rideId = const Uuid().v4();

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?"
      "origin=${source.latitude},${source.longitude}"
      "&destination=${destination.latitude},${destination.longitude}"
      "&key=$googleApiKey",
    );

    final response = await http.get(url);
    final data = json.decode(response.body);

    final encoded = data['routes'][0]['overview_polyline']['points'];
    final points = _decodePolyline(encoded);

    final routeData =
        points.map((p) => {"lat": p.latitude, "lng": p.longitude}).toList();

    await FirebaseDatabase.instance.ref("activeRides/$rideId").set({
      "driverId": driverId,
      "sourceName": sourceName,
      "destinationName": destinationName,
      "route": routeData,
      "status": "active",
      "createdAt": ServerValue.timestamp,
    });

    return (rideId, points);
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
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
}