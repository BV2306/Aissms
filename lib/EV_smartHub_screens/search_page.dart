import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_map.dart';
import 'package:lastmile_transport/home.dart';

class EVSmartHubSearchPage extends StatefulWidget {
  const EVSmartHubSearchPage({super.key});

  @override
  State<EVSmartHubSearchPage> createState() =>
      _EVSmartHubSearchPageState();
}

class _EVSmartHubSearchPageState extends State<EVSmartHubSearchPage> {
  String? sourceLocality;
  String? sourceHub;
  String? destLocality;
  String? destHub;

  double distanceKm = 0;
  int estimatedMinutes = 0;
  int extraMinutes = 0;
  bool isCalculatingDistance = false;

  List<String> localities = [];
  List<String> sourceHubs = [];
  List<String> destHubs = [];
  
  // Hub location cache
  Map<String, Map<String, double>> hubLocations = {};

  final DatabaseReference bicyclesRef =
      FirebaseDatabase.instance.ref("bicycles");
  
  static const String orsApiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _loadLocalties();
  }

  Future<void> _loadLocalties() async {
    final snap =
        await FirebaseFirestore.instance.collection("EV-Hubs").get();

    setState(() {
      localities = snap.docs.map((e) => e.id).toList();
    });
  }

  Future<void> _loadHubs(String locality, bool isSource) async {
    final snap = await FirebaseFirestore.instance
        .collection("EV-Hubs")
        .doc(locality)
        .collection("Hubs")
        .get();

    if (isSource) {
      sourceHubs = snap.docs.map((e) => e.id).toList();
    } else {
      destHubs = snap.docs.map((e) => e.id).toList();
    }

    setState(() {});
  }

  Future<Map<String, double>?> _getHubCoordinates(
      String locality, String hub) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("EV-Hubs")
          .doc(locality)
          .collection("Hubs")
          .doc(hub)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      // Try "Up" direction first, then "Down"
      final location = data?["Up"] ?? data?["Down"];

      if (location != null) {
        // Handle numeric values stored as int or double, and multiple possible keys for longitude
        final dynamic latVal = location["lat"];
        final dynamic lonVal = location["long"] ?? location["lon"] ?? location["lng"];

        double? lat;
        double? lon;

        if (latVal is num) {
          lat = latVal.toDouble();
        } else if (latVal != null) {
          lat = double.tryParse(latVal.toString());
        }

        if (lonVal is num) {
          lon = lonVal.toDouble();
        } else if (lonVal != null) {
          lon = double.tryParse(lonVal.toString());
        }

        if (lat != null && lon != null) {
          return {
            "lat": lat,
            "lon": lon,
          };
        }
      }
    } catch (e) {
      print("Error getting hub coordinates: $e");
    }
    return null;
  }

  Future<void> _calculateDistanceAndPrice() async {
    if (sourceLocality == null ||
        sourceHub == null ||
        destLocality == null ||
        destHub == null) {
      return;
    }

    setState(() {
      isCalculatingDistance = true;
    });

    try {
      final sourceCoords = await _getHubCoordinates(sourceLocality!, sourceHub!);
      final destCoords = await _getHubCoordinates(destLocality!, destHub!);

      if (sourceCoords == null || destCoords == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not find hub coordinates")),
        );
        setState(() {
          isCalculatingDistance = false;
        });
        return;
      }

      // Cache the locations
      hubLocations["source"] = sourceCoords;
      hubLocations["dest"] = destCoords;

      // Call ORS API for distance
      final response = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [sourceCoords["lon"], sourceCoords["lat"]],
            [destCoords["lon"], destCoords["lat"]],
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ORS may return different shapes depending on endpoint/params.
        // Try multiple known locations for distance (meters).
        num distanceMeters = 0;

        if (data is Map && data["routes"] != null && data["routes"] is List && (data["routes"] as List).isNotEmpty) {
          final r0 = (data["routes"] as List)[0];
          if (r0 is Map && r0["summary"] != null && r0["summary"]["distance"] != null) {
            distanceMeters = r0["summary"]["distance"] as num;
          }
        } else if (data is Map && data["features"] != null && data["features"] is List && (data["features"] as List).isNotEmpty) {
          final f0 = (data["features"] as List)[0];
          if (f0 is Map && f0["properties"] != null) {
            final props = f0["properties"] as Map;
            if (props["summary"] != null && props["summary"]["distance"] != null) {
              distanceMeters = props["summary"]["distance"] as num;
            } else if (props["segments"] != null && props["segments"] is List) {
              // Sum segment distances
              distanceMeters = (props["segments"] as List).fold<num>(0, (s, seg) {
                if (seg is Map && seg["distance"] != null) return s + (seg["distance"] as num);
                return s;
              });
            }
          }
        }

        if (distanceMeters <= 0) {
          throw Exception('Unexpected ORS response structure');
        }

        final distance = distanceMeters / 1000;

        setState(() {
          distanceKm = distance;
          // 10 minutes per km
          estimatedMinutes = (distance * 10).ceil();
          isCalculatingDistance = false;
        });
      } else {
        throw Exception("ORS API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calculating distance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
      setState(() {
        isCalculatingDistance = false;
      });
    }
  }

  int get baseMinutes => (distanceKm * 10).ceil();

  double get price {
    double base = distanceKm * 5;
    double extra = extraMinutes * 1;
    return base + extra;
  }

  Future<bool> _checkBicycleAvailability() async {
    if (sourceLocality == null || sourceHub == null) return false;

    final snapshot = await bicyclesRef
        .child(sourceLocality!)
        .child(sourceHub!)
        .get();

    if (!snapshot.exists) return false;

    final data = snapshot.value;

    if (data is! Map) return false;

    final bikes = Map<String, dynamic>.from(data);

    // check any bike available
    for (final bike in bikes.values) {
      if (bike is Map && bike["availability"] == "yes") {
        return true;
      }
    }

    return false;
  }

  Future<void> _proceed() async {
    if (sourceLocality == null ||
        sourceHub == null ||
        destLocality == null ||
        destHub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all selections")),
      );
      return;
    }

    if (distanceKm == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for distance calculation")),
      );
      return;
    }

    final available = await _checkBicycleAvailability();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No bicycles available at source hub")),
      );
      return;
    }

    final sourceCoords = hubLocations["source"];
    final destCoords = hubLocations["dest"];

    if (sourceCoords == null || destCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hub coordinates not available")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EVMapScreen(
          bookingData: {
            "sourceLocality": sourceLocality,
            "sourceHub": sourceHub,
            "sourceLat": sourceCoords["lat"],
            "sourceLon": sourceCoords["lon"],
            "destLocality": destLocality,
            "destHub": destHub,
            "destLat": destCoords["lat"],
            "destLon": destCoords["lon"],
            "distanceKm": distanceKm,
            "estimatedMinutes": estimatedMinutes,
            "extraMinutes": extraMinutes,
            "price": price,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EV Hub Booking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text("Source Locality"),
            DropdownButtonFormField(
              value: sourceLocality,
              items: localities
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                sourceLocality = v;
                sourceHub = null;
                _loadHubs(v!, true);
                _calculateDistanceAndPrice();
              },
            ),
            const SizedBox(height: 12),
            const Text("Source Hub"),
            DropdownButtonFormField(
              value: sourceHub,
              items: sourceHubs
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                sourceHub = v;
                _calculateDistanceAndPrice();
              },
            ),
            const SizedBox(height: 20),
            const Text("Destination Locality"),
            DropdownButtonFormField(
              value: destLocality,
              items: localities
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                destLocality = v;
                destHub = null;
                _loadHubs(v!, false);
                _calculateDistanceAndPrice();
              },
            ),
            const SizedBox(height: 12),
            const Text("Destination Hub"),
            DropdownButtonFormField(
              value: destHub,
              items: destHubs
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                destHub = v;
                _calculateDistanceAndPrice();
              },
            ),
            const SizedBox(height: 20),
            if (isCalculatingDistance)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text("Calculating distance..."),
                  ],
                ),
              )
            else if (distanceKm > 0)
              Column(
                children: [
                  Card(
                    child: ListTile(
                      title: const Text("Distance"),
                      subtitle: Text("${distanceKm.toStringAsFixed(2)} km"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text("Estimated Time"),
                      subtitle: Text("$estimatedMinutes minutes"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: const Text("Estimated Price"),
                      subtitle: Text("₹${price.toStringAsFixed(2)}"),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Extra minutes (optional)",
              ),
              onChanged: (v) =>
                  extraMinutes = int.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (distanceKm > 0 && !isCalculatingDistance) ? () async { await _proceed(); } : null,
              child: const Text("Proceed to Map"),
            ),
          ],
        ),
      ),
    );
  }
}

