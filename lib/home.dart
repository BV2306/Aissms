import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:sliding_up_panel/sliding_up_panel.dart';
import './widgets/app_drawer.dart';
import 'EV_smartHub_screens/search_page.dart';
import 'EV_smartHub_screens/payment_page.dart';

class EVMapScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const EVMapScreen({super.key, this.bookingData});

  @override
  State<EVMapScreen> createState() => _EVMapScreenState();
}

class _EVMapScreenState extends State<EVMapScreen> {
  GoogleMapController? mapController;
  Position? currentPosition;

  Set<Marker> userMarkers = {};
  Set<Marker> hubMarkers = {};
  Set<Circle> localityCircles = {};
  Set<Polyline> polylines = {};

  List<Map<String, dynamic>> nearestLocalities = [];
  List<Map<String, dynamic>> nearestHubs = [];

  static const String orsApiKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  // =====================================================
  // 🚀 INIT PIPELINE
  // =====================================================
  @override
  void initState() {
    super.initState();
    _initPipeline();
  }

  Future<void> _initPipeline() async {
    await _handleLocationPermission();

    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _saveUserLocation();

    if (widget.bookingData != null) {
      await _drawBookingRoutes();
    } else {
      await _loadLocalitiesAndFindNearest();
      await _loadNearestHubs();
      await _drawOptimalRoute();
    }

    _createUserMarker();
    setState(() {});
  }

  // =====================================================
  // 🔐 LOCATION PERMISSION
  // =====================================================
  Future<void> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions permanently denied");
    }
  }

  // =====================================================
  // 📍 SAVE USER LOCATION
  // =====================================================
  Future<void> _saveUserLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "demo_user";
    await FirebaseFirestore.instance.collection("users").doc(uid).set({
      "location": {
        "lat": currentPosition!.latitude,
        "long": currentPosition!.longitude,
      },
      "timestamp": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =====================================================
  // 📏 HAVERSINE DISTANCE
  // =====================================================
  double calculateDistanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371;
    var dLat = (lat2 - lat1) * pi / 180;
    var dLon = (lon2 - lon1) * pi / 180;
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // =====================================================
  // 🔥 FIND NEAREST LOCALITIES (TOP 4)
  // =====================================================
  Future<void> _loadLocalitiesAndFindNearest() async {
    final snapshot =
        await FirebaseFirestore.instance.collection("EV-Hubs").get();

    List<Map<String, dynamic>> temp = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data["region"] == null) continue;

      final center = data["region"]["center"];
      final radius = data["region"]["radius_m"];

      final dist = calculateDistanceInKm(
        currentPosition!.latitude,
        currentPosition!.longitude,
        center["lat"],
        center["long"],
      );

      temp.add({
        "name": doc.id,
        "distance": dist,
        "center": center,
        "radius": radius,
      });
    }

    temp.sort((a, b) => a["distance"].compareTo(b["distance"]));
    nearestLocalities = temp.take(4).toList();
    _createLocalityCircles();
  }

  // =====================================================
  // 🟢 DRAW LOCALITY CIRCLES
  // =====================================================
  void _createLocalityCircles() {
    localityCircles.clear();
    for (var loc in nearestLocalities) {
      localityCircles.add(
        Circle(
          circleId: CircleId(loc["name"]),
          center: LatLng(loc["center"]["lat"], loc["center"]["long"]),
          radius: (loc["radius"] as num).toDouble(),
          fillColor: Colors.green.withOpacity(0.15),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ),
      );
    }
  }

  // =====================================================
  // 🔥 FIND NEAREST HUBS (TOP 10)
  // =====================================================
  Future<void> _loadNearestHubs() async {
    List<Map<String, dynamic>> hubTemp = [];

    for (var locality in nearestLocalities) {
      final hubsSnap = await FirebaseFirestore.instance
          .collection("EV-Hubs")
          .doc(locality["name"])
          .collection("Hubs")
          .get();

      for (var hubDoc in hubsSnap.docs) {
        final data = hubDoc.data();
        for (var dir in ["Up", "Down"]) {
          if (data[dir] == null) continue;
          final hubLat = data[dir]["lat"];
          final hubLon = data[dir]["long"];
          final dist = calculateDistanceInKm(
            currentPosition!.latitude,
            currentPosition!.longitude,
            hubLat,
            hubLon,
          );
          hubTemp.add({
            "name": hubDoc.id,
            "lat": hubLat,
            "lon": hubLon,
            "distance": dist,
          });
        }
      }
    }

    hubTemp.sort((a, b) => a["distance"].compareTo(b["distance"]));
    nearestHubs = hubTemp.take(10).toList();
    _createHubMarkers();
  }

  // =====================================================
  // 📍 HUB MARKERS (exploration mode)
  // =====================================================
  void _createHubMarkers() {
    hubMarkers.clear();
    for (var hub in nearestHubs) {
      hubMarkers.add(
        Marker(
          markerId: MarkerId(hub["name"]),
          position: LatLng(hub["lat"], hub["lon"]),
          infoWindow: InfoWindow(title: hub["name"]),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
        ),
      );
    }
  }

  // =====================================================
  // 🧭 ORS OPTIMAL ROUTE (exploration mode)
  // =====================================================
  Future<void> _drawOptimalRoute() async {
    if (nearestHubs.isEmpty) return;

    List<List<double>> coords = [
      [currentPosition!.longitude, currentPosition!.latitude],
    ];
    for (var hub in nearestHubs) {
      coords.add([hub["lon"], hub["lat"]]);
    }

    final response = await http.post(
      Uri.parse(
          "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
      headers: {
        "Authorization": orsApiKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "coordinates": coords,
        "optimize_waypoints": true,
      }),
    );

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body);
    final geometry = data["features"][0]["geometry"]["coordinates"];
    List<LatLng> routePoints =
        geometry.map<LatLng>((p) => LatLng(p[1], p[0])).toList();

    polylines.clear();
    polylines.add(Polyline(
      polylineId: const PolylineId("route"),
      width: 5,
      color: Colors.blue,
      points: routePoints,
    ));
  }

  // =====================================================
  // 👤 USER MARKER
  // =====================================================
  void _createUserMarker() {
    userMarkers.clear();
    userMarkers.add(
      Marker(
        markerId: const MarkerId("user"),
        position: LatLng(
            currentPosition!.latitude, currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "You"),
      ),
    );
  }

  // =====================================================
  // 🗺️ DRAW BOOKING ROUTES (booking mode)
  // Handles hub-to-hub: uses sourceLat/sourceLon/destLat/destLon
  // =====================================================
  Future<void> _drawBookingRoutes() async {
    if (widget.bookingData == null) return;
    final bd = widget.bookingData!;

    try {
      final sourceLat = (bd["sourceLat"] as num).toDouble();
      final sourceLon = (bd["sourceLon"] as num).toDouble();
      final destLat = (bd["destLat"] as num).toDouble();
      final destLon = (bd["destLon"] as num).toDouble();

      // ─── Hub markers ───────────────────────────────────
      hubMarkers.clear();
      hubMarkers.add(Marker(
        markerId: const MarkerId("source_hub"),
        position: LatLng(sourceLat, sourceLon),
        infoWindow: InfoWindow(
          title: bd["sourceHub"] as String? ?? "Source Hub",
          snippet: "Pickup",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ));
      hubMarkers.add(Marker(
        markerId: const MarkerId("dest_hub"),
        position: LatLng(destLat, destLon),
        infoWindow: InfoWindow(
          title: bd["destHub"] as String? ?? "Destination Hub",
          snippet: "Drop-off",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
      ));

      // ─── Route 1: user → source hub (blue) ─────────────
      final resp1 = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [currentPosition!.longitude, currentPosition!.latitude],
            [sourceLon, sourceLat],
          ],
        }),
      );

      // ─── Route 2: source hub → dest hub (purple) ────────
      final resp2 = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [sourceLon, sourceLat],
            [destLon, destLat],
          ],
        }),
      );

      if (resp1.statusCode == 200 && resp2.statusCode == 200) {
        polylines.clear();

        final g1 =
            jsonDecode(resp1.body)["features"][0]["geometry"]["coordinates"];
        final route1 =
            (g1 as List).map<LatLng>((p) => LatLng(p[1], p[0])).toList();

        final g2 =
            jsonDecode(resp2.body)["features"][0]["geometry"]["coordinates"];
        final route2 =
            (g2 as List).map<LatLng>((p) => LatLng(p[1], p[0])).toList();

        polylines.add(Polyline(
          polylineId: const PolylineId("user_to_source"),
          points: route1,
          width: 5,
          color: Colors.blue,
        ));
        polylines.add(Polyline(
          polylineId: const PolylineId("source_to_dest"),
          points: route2,
          width: 5,
          color: Colors.purple,
        ));

        // Fit camera to all route points after map is ready
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mapController != null) {
            final all = [...route1, ...route2];
            final bounds = _getLatLngBounds(all);
            await Future.delayed(const Duration(milliseconds: 400));
            mapController!
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
          }
        });
      }
    } catch (e) {
      debugPrint("Error drawing booking routes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading route: $e")),
        );
      }
    }
  }

  // =====================================================
  // 🧭 ROUTE TO SELECTED HUB (exploration mode tap)
  // =====================================================
  Future<void> _routeToHub(Map<String, dynamic> hub) async {
    final response = await http.post(
      Uri.parse(
          "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
      headers: {
        "Authorization": orsApiKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "coordinates": [
          [currentPosition!.longitude, currentPosition!.latitude],
          [hub["lon"], hub["lat"]],
        ],
      }),
    );

    if (response.statusCode != 200) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Failed to get route")));
      }
      return;
    }

    final data = jsonDecode(response.body);
    final geometry = data["features"][0]["geometry"]["coordinates"];
    final routePoints =
        (geometry as List).map<LatLng>((p) => LatLng(p[1], p[0])).toList();

    setState(() {
      polylines.clear();
      polylines.add(Polyline(
        polylineId: PolylineId(hub["name"]),
        width: 5,
        color: Colors.blue,
        points: routePoints,
      ));
    });

    if (mapController != null && routePoints.isNotEmpty) {
      final bounds = _getLatLngBounds(routePoints);
      mapController!
          .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  // =====================================================
  // 📐 LAT/LNG BOUNDS HELPER
  // =====================================================
  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    double minLat = points[0].latitude,
        maxLat = points[0].latitude;
    double minLng = points[0].longitude,
        maxLng = points[0].longitude;
    for (var p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // =====================================================
  // 💳 NAVIGATE TO PAYMENT
  // =====================================================
  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(bookingData: widget.bookingData),
      ),
    );
  }

  // =====================================================
  // 🧱 BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.bookingData != null ? "Booking Map" : "EV Map",
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          if (widget.bookingData == null)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EVSmartHubSearchPage(),
                  ),
                );
              },
            ),
        ],
      ),
      body: SlidingUpPanel(
        minHeight: widget.bookingData != null ? 220 : 180,
        maxHeight: widget.bookingData != null ? 420 : 420,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(30)),
        panel: _buildBottomPanel(),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
                currentPosition!.latitude, currentPosition!.longitude),
            zoom: 13,
          ),
          myLocationEnabled: true,
          markers: {...userMarkers, ...hubMarkers},
          circles: localityCircles,
          polylines: polylines,
          onMapCreated: (controller) {
            mapController = controller;
            // If in booking mode, fit camera once map is ready
            if (widget.bookingData != null && polylines.isNotEmpty) {
              final allPts = polylines
                  .expand((p) => p.points)
                  .toList();
              if (allPts.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  mapController!.animateCamera(
                    CameraUpdate.newLatLngBounds(
                        _getLatLngBounds(allPts), 80),
                  );
                });
              }
            }
          },
        ),
      ),
    );
  }

  // =====================================================
  // 📋 BOTTOM PANEL
  // =====================================================
  Widget _buildBottomPanel() {
    if (widget.bookingData != null) {
      return _buildBookingPanel(widget.bookingData!);
    }
    return _buildExplorationPanel();
  }

  // ─── Booking Summary Panel (Hub-to-Hub) ──────────────
  Widget _buildBookingPanel(Map<String, dynamic> bd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Drag handle + label
          Column(
            children: [
              const Icon(Icons.drag_handle, color: Colors.grey),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  const Text(
                    "Hub-to-Hub Booking",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable summary cards
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _infoCard(
                    icon: Icons.location_on,
                    color: Colors.green,
                    title: "From",
                    value: bd["sourceHub"] as String? ?? "Unknown",
                  ),
                  _infoCard(
                    icon: Icons.flag,
                    color: Colors.red,
                    title: "To",
                    value: bd["destHub"] as String? ?? "Unknown",
                  ),
                  _infoCard(
                    icon: Icons.straighten,
                    color: Colors.blue,
                    title: "Distance",
                    value:
                        "${(bd["distanceKm"] as num).toStringAsFixed(2)} km",
                  ),
                  _infoCard(
                    icon: Icons.timer,
                    color: Colors.orange,
                    title: "Estimated Time",
                    value: "${bd["estimatedMinutes"]} minutes"
                        "${(bd["extraMinutes"] as num? ?? 0) > 0 ? ' + ${bd["extraMinutes"]} extra' : ''}",
                  ),
                  _infoCard(
                    icon: Icons.currency_rupee,
                    color: Colors.purple,
                    title: "Total Price",
                    value: "₹${(bd["price"] as num).toStringAsFixed(2)}",
                    bold: true,
                  ),
                  const SizedBox(height: 8),

                  // Route legend
                  Row(
                    children: [
                      _legendDot(Colors.blue),
                      const SizedBox(width: 6),
                      const Text("You → Pickup hub",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 16),
                      _legendDot(Colors.purple),
                      const SizedBox(width: 6),
                      const Text("Pickup → Destination",
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Pay button — always visible
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  "Proceed to Payment  ₹${(bd["price"] as num).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Exploration Panel (nearby hubs list) ────────────
  Widget _buildExplorationPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.drag_handle, color: Colors.grey),
          const SizedBox(height: 10),
          const Text(
            "Nearby EV Hubs",
            style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: nearestHubs.length,
              itemBuilder: (context, index) {
                final hub = nearestHubs[index];
                return ListTile(
                  leading:
                      const Icon(Icons.ev_station, color: Colors.green),
                  title: GestureDetector(
                    onTap: () => _routeToHub(hub),
                    child: Text(
                      hub["name"],
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  subtitle: Text(
                      "${(hub["distance"] as double).toStringAsFixed(2)} km away"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared info card widget ──────────────────────────
  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    bool bold = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 1,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(title,
            style:
                const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.w500,
            color: bold ? const Color(0xFF2563EB) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}