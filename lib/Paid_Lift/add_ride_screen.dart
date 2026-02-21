import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddRideScreen extends StatefulWidget {
  const AddRideScreen({super.key});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  final MapController _mapController = MapController();

  LatLng? sourceLatLng;
  LatLng? destinationLatLng;

  String sourceName = "";
  String destinationName = "";

  static const String googleApiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  // ================= GOOGLE SEARCH =================
  Future<List<Map<String, dynamic>>> findPlaces(String query) async {
    if (query.isEmpty) return [];

    const baseUrl =
        'https://maps.googleapis.com/maps/api/place/textsearch/json';

    final url = Uri.parse(
        '$baseUrl?query=${Uri.encodeComponent(query)}&key=$googleApiKey');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'];

          return results.map<Map<String, dynamic>>((place) {
            return {
              'name': place['name'],
              'address': place['formatted_address'],
              'lat': place['geometry']['location']['lat'],
              'lng': place['geometry']['location']['lng'],
            };
          }).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  // ================= CREATE RIDE =================
  Future<void> createRide() async {
    if (sourceLatLng == null || destinationLatLng == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? "unknown_user";

    await FirebaseFirestore.instance.collection("rides").add({
      "userId": uid,
      "sourceName": sourceName,
      "sourceLat": sourceLatLng!.latitude,
      "sourceLng": sourceLatLng!.longitude,
      "destinationName": destinationName,
      "destinationLat": destinationLatLng!.latitude,
      "destinationLng": destinationLatLng!.longitude,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  // ================= MARKERS =================
  List<Marker> buildMarkers() {
    List<Marker> markers = [];

    if (sourceLatLng != null) {
      markers.add(
        Marker(
          point: sourceLatLng!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on,
              color: Colors.green, size: 40),
        ),
      );
    }

    if (destinationLatLng != null) {
      markers.add(
        Marker(
          point: destinationLatLng!,
          width: 50,
          height: 50,
          child:
              const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialCenter =
        sourceLatLng ?? const LatLng(18.5204, 73.8567);

    return Scaffold(
      appBar: AppBar(title: const Text("Create Ride")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // ================= SOURCE =================
                TypeAheadField<Map<String, dynamic>>(
                  suggestionsCallback: findPlaces,
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['name']),
                      subtitle: Text(suggestion['address']),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      sourceName = suggestion['name'];
                      sourceLatLng =
                          LatLng(suggestion['lat'], suggestion['lng']);
                      _mapController.move(sourceLatLng!, 14);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Source selected: $sourceName")),
                    );
                  },
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: "Source",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.my_location),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ================= DESTINATION =================
                TypeAheadField<Map<String, dynamic>>(
                  suggestionsCallback: findPlaces,
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['name']),
                      subtitle: Text(suggestion['address']),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      destinationName = suggestion['name'];
                      destinationLatLng =
                          LatLng(suggestion['lat'], suggestion['lng']);
                      _mapController.move(destinationLatLng!, 14);
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text("Destination selected: $destinationName")),
                    );
                  },
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: "Destination",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: createRide,
                    child: const Text("Create Ride"),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName:
                      "com.example.lastmile_transport",
                ),
                MarkerLayer(markers: buildMarkers()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}