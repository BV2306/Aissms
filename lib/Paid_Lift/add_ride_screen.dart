import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastmile_transport/Paid_Lift/driver_route_service.dart';
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

  final TextEditingController sourceController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  LatLng? sourceLatLng;
  LatLng? destinationLatLng;

  String sourceName = "";
  String destinationName = "";

  static const String googleApiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  Future<List<Map<String, dynamic>>> findPlaces(String query) async {
    if (query.isEmpty) return [];

    const baseUrl =
        'https://maps.googleapis.com/maps/api/place/textsearch/json';

    final url = Uri.parse(
      '$baseUrl?query=${Uri.encodeComponent(query)}&key=$googleApiKey',
    );

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

Future<void> createRide() async {
  if (sourceLatLng == null || destinationLatLng == null) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DriverRouteScreen(
        source: sourceLatLng!,
        destination: destinationLatLng!,
        sourceName: sourceName,
        destinationName: destinationName,
      ),
    ),
  );
}

  List<Marker> buildMarkers() {
    List<Marker> markers = [];

    if (sourceLatLng != null) {
      markers.add(
        Marker(
          point: sourceLatLng!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
    }

    if (destinationLatLng != null) {
      markers.add(
        Marker(
          point: destinationLatLng!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    LatLng initialCenter = sourceLatLng ?? const LatLng(18.5204, 73.8567);

    return Scaffold(
      appBar: AppBar(title: const Text("Create Ride")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TypeAheadField<Map<String, dynamic>>(
                  controller: sourceController,
                  suggestionsCallback: findPlaces,
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
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['name']),
                      subtitle: Text(suggestion['address']),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      sourceName = suggestion['name'];
                      sourceLatLng = LatLng(
                        suggestion['lat'],
                        suggestion['lng'],
                      );
                      sourceController.text = suggestion['name'];
                      _mapController.move(sourceLatLng!, 14);
                    });

                    print(
                      "SOURCE PLACE ID: ${suggestion['placeId']}",
                    ); // ✅ PRINT HERE
                  },
                ),

                const SizedBox(height: 16),

                TypeAheadField<Map<String, dynamic>>(
                  controller: destinationController,
                  suggestionsCallback: findPlaces,
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
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion['name']),
                      subtitle: Text(suggestion['address']),
                    );
                  },
                  onSelected: (suggestion) {
                    setState(() {
                      destinationName = suggestion['name'];
                      destinationLatLng = LatLng(
                        suggestion['lat'],
                        suggestion['lng'],
                      );
                      destinationController.text = suggestion['name'];
                      _mapController.move(destinationLatLng!, 14);
                    });

                    print(
                      "DESTINATION PLACE ID: ${suggestion['placeId']}",
                    ); // ✅ PRINT HERE
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
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.lastmile_transport",
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
