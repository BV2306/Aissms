import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:lastmile_transport/Paid_Lift/Driver/driver_route_screen_.dart';

/// Screen where the driver enters their pick-up (source) and drop-off
/// (destination) before creating an active ride.
///
/// Uses Google Maps Flutter for the preview map and
/// Google Places Text Search for address autocomplete.
class AddRideScreen extends StatefulWidget {
  const AddRideScreen({super.key});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  // ── Replace with your actual Google Maps API key ──────────────────────────
  static const String _apiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  GoogleMapController? _mapController;
  final TextEditingController _sourceCtrl = TextEditingController();
  final TextEditingController _destCtrl = TextEditingController();

  LatLng? _source;
  LatLng? _destination;
  String _sourceName = "";
  String _destName = "";
  bool _isCreating = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // ── Place search ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.length < 2) return [];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json'
      '?query=${Uri.encodeComponent(query)}&key=$_apiKey',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          return (data['results'] as List).map<Map<String, dynamic>>((p) => {
                'name': p['name'],
                'address': p['formatted_address'],
                'lat': p['geometry']['location']['lat'],
                'lng': p['geometry']['location']['lng'],
              }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // ── Map helpers ───────────────────────────────────────────────────────────

  void _updateMarkers() {
    final markers = <Marker>{};
    if (_source != null) {
      markers.add(Marker(
        markerId: const MarkerId('source'),
        position: _source!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _sourceName, snippet: 'Your start'),
      ));
    }
    if (_destination != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _destName, snippet: 'Your end'),
      ));
    }
    setState(() => _markers = markers);

    // Fit both pins if both are set
    if (_source != null && _destination != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              [_source!.latitude, _destination!.latitude].reduce((a, b) => a < b ? a : b),
              [_source!.longitude, _destination!.longitude].reduce((a, b) => a < b ? a : b),
            ),
            northeast: LatLng(
              [_source!.latitude, _destination!.latitude].reduce((a, b) => a > b ? a : b),
              [_source!.longitude, _destination!.longitude].reduce((a, b) => a > b ? a : b),
            ),
          ),
          80,
        ),
      );
    }
  }

  // ── Create ride ───────────────────────────────────────────────────────────

  Future<void> _createRide() async {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both source and destination")),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverRouteScreen(
            source: _source!,
            destination: _destination!,
            sourceName: _sourceName,
            destinationName: _destName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Ride"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Input panel ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                _PlaceField(
                  controller: _sourceCtrl,
                  label: "Starting Point",
                  icon: Icons.trip_origin,
                  iconColor: Colors.green,
                  onSearch: _searchPlaces,
                  onSelected: (s) {
                    _sourceName = s['name'];
                    _source = LatLng(s['lat'], s['lng']);
                    _sourceCtrl.text = s['name'];
                    _updateMarkers();
                  },
                ),
                const SizedBox(height: 10),
                _PlaceField(
                  controller: _destCtrl,
                  label: "Destination",
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  onSearch: _searchPlaces,
                  onSelected: (s) {
                    _destName = s['name'];
                    _destination = LatLng(s['lat'], s['lng']);
                    _destCtrl.text = s['name'];
                    _updateMarkers();
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCreating ? null : _createRide,
                    icon: _isCreating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.directions_car),
                    label: Text(_isCreating ? "Setting up..." : "Create Ride"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Map preview ────────────────────────────────────────────────
          Expanded(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition: const CameraPosition(
                target: LatLng(18.5204, 73.8567), // Pune default
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable place search field ─────────────────────────────────────────────

class _PlaceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;
  final void Function(Map<String, dynamic>) onSelected;

  const _PlaceField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onSearch,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      controller: controller,
      suggestionsCallback: onSearch,
      builder: (ctx, ctrl, focusNode) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(icon, color: iconColor),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        ),
      ),
      itemBuilder: (ctx, s) => ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor, size: 18),
        title: Text(s['name'], style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          s['address'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
      onSelected: onSelected,
    );
  }
}