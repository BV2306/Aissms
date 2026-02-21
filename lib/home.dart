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

  // ===== MAP DATA =====
  Set<Marker> userMarkers = {};
  Set<Marker> hubMarkers = {};
  Set<Circle> localityCircles = {};
  Set<Polyline> polylines = {};

  // ===== DATA LISTS =====
  List<Map<String, dynamic>> nearestLocalities = [];
  List<Map<String, dynamic>> nearestHubs = [];

  // 🔴 PUT YOUR ORS KEY HERE
  static const String orsApiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _initPipeline();
  }

  // =====================================================
  // 🚀 MAIN PIPELINE
  // =====================================================
  Future<void> _initPipeline() async {
    await _handleLocationPermission();

    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _saveUserLocation();

    // If booking data exists, draw booking routes
    if (widget.bookingData != null) {
      await _drawBookingRoutes();
    } else {
      // Otherwise, draw optimal route with nearby hubs
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
  // 📏 DISTANCE FORMULA
  // =====================================================
  double calculateDistanceInKm(lat1, lon1, lat2, lon2) {
    const R = 6371;
    var dLat = (lat2 - lat1) * pi / 180;
    var dLon = (lon2 - lon1) * pi / 180;

    var a =
        sin(dLat / 2) * sin(dLat / 2) +
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

    // 🔥 TAKE ONLY 4 LOCALITIES
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
          center: LatLng(
            loc["center"]["lat"],
            loc["center"]["long"],
          ),
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
  // 📍 HUB MARKERS
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
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
  }

  // =====================================================
  // 🧭 OPENROUTESERVICE OPTIMAL ROUTE
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
    polylines.add(
      const Polyline(
        polylineId: PolylineId("route"),
        width: 5,
        color: Colors.blue,
      ).copyWith(pointsParam: routePoints),
    );
  }

  // =====================================================
  // 🧱 PAYMENT PAGE NAVIGATION
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
  // 👤 USER MARKER
  // =====================================================
  void _createUserMarker() {
    userMarkers.clear();

    userMarkers.add(
      Marker(
        markerId: const MarkerId("user"),
        position: LatLng(
          currentPosition!.latitude,
          currentPosition!.longitude,
        ),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
  }

  // =====================================================
  // 🗺️ DRAW DUAL BOOKING ROUTES
  // =====================================================
  Future<void> _drawBookingRoutes() async {
    if (widget.bookingData == null) return;

    try {
      // Extract coordinates from booking data
      final sourceLat = widget.bookingData!["sourceLat"] as double;
      final sourceLon = widget.bookingData!["sourceLon"] as double;
      final destLat = widget.bookingData!["destLat"] as double;
      final destLon = widget.bookingData!["destLon"] as double;

      // Add markers for source and destination hubs
      hubMarkers.clear();
      hubMarkers.add(
        Marker(
          markerId: const MarkerId("source_hub"),
          position: LatLng(sourceLat, sourceLon),
          infoWindow: InfoWindow(
            title: widget.bookingData!["sourceHub"],
            snippet: "Source Hub",
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      hubMarkers.add(
        Marker(
          markerId: const MarkerId("dest_hub"),
          position: LatLng(destLat, destLon),
          infoWindow: InfoWindow(
            title: widget.bookingData!["destHub"],
            snippet: "Destination Hub",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Draw route from user location to source hub
      final response1 = await http.post(
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

      // Draw route from source hub to destination hub
      final response2 = await http.post(
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

      if (response1.statusCode == 200 && response2.statusCode == 200) {
        polylines.clear();

        // Process first route (user to source)
        final data1 = jsonDecode(response1.body);
        final geometry1 = data1["features"][0]["geometry"]["coordinates"];
        List<LatLng> routePoints1 =
            geometry1.map<LatLng>((p) => LatLng(p[1], p[0])).toList();

        polylines.add(
          Polyline(
            polylineId: const PolylineId("user_to_source"),
            width: 5,
            color: Colors.blue,
            points: routePoints1,
          ),
        );

        // Process second route (source to destination)
        final data2 = jsonDecode(response2.body);
        final geometry2 = data2["features"][0]["geometry"]["coordinates"];
        List<LatLng> routePoints2 =
            geometry2.map<LatLng>((p) => LatLng(p[1], p[0])).toList();

        polylines.add(
          Polyline(
            polylineId: const PolylineId("source_to_dest"),
            width: 5,
            color: Colors.purple,
            points: routePoints2,
          ),
        );

        // Animate camera to show entire route
        if (mapController != null) {
          // Combine all points to get bounds
          List<LatLng> allPoints = [...routePoints1, ...routePoints2];
          final bounds = _getLatLngBounds(allPoints);
          mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }

        setState(() {});
      }
    } catch (e) {
      print("Error drawing booking routes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // =====================================================
  // 🧱 UI
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
        title: const Text(
          "EV Map",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
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
        minHeight: 180,
        maxHeight: 420,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        panel: _buildBottomPanel(),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              currentPosition!.latitude,
              currentPosition!.longitude,
            ),
            zoom: 13,
          ),
          myLocationEnabled: true,
          markers: {...userMarkers, ...hubMarkers},
          circles: localityCircles,
          polylines: polylines,
          onMapCreated: (controller) => mapController = controller,
        ),
      ),
    );
  }

  // =====================================================
  // 🧭 ROUTE TO SELECTED HUB
  // =====================================================
  Future<void> _routeToHub(Map<String, dynamic> hub) async {
    List<List<double>> coords = [
      [currentPosition!.longitude, currentPosition!.latitude],
      [hub["lon"], hub["lat"]],
    ];

    final response = await http.post(
      Uri.parse(
          "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
      headers: {
        "Authorization": orsApiKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "coordinates": coords,
      }),
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get route")),
      );
      return;
    }

    final data = jsonDecode(response.body);
    final geometry = data["features"][0]["geometry"]["coordinates"];

    List<LatLng> routePoints =
        geometry.map<LatLng>((p) => LatLng(p[1], p[0])).toList();

    setState(() {
      polylines.clear();
      polylines.add(
        Polyline(
          polylineId: PolylineId(hub["name"]),
          width: 5,
          color: Colors.blue,
          points: routePoints,
        ),
      );
    });

    // Animate camera to show the route
    if (mapController != null && routePoints.isNotEmpty) {
      final bounds = _getLatLngBounds(routePoints);
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    }
  }

  // =====================================================
  // 📐 CALCULATE BOUNDS FOR ROUTE
  // =====================================================
  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // =====================================================
  // 📋 BOTTOM PANEL
  // =====================================================
  Widget _buildBottomPanel() {
    if (widget.bookingData != null) {
      final bookingData = widget.bookingData!;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.drag_handle),
            const SizedBox(height: 16),

            /// ✅ SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      "Booking Summary",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    _infoCard(
                      icon: Icons.location_on,
                      color: Colors.blue,
                      title: "From",
                      value: bookingData["sourceHub"] ?? "Unknown",
                    ),

                    _infoCard(
                      icon: Icons.location_on,
                      color: Colors.red,
                      title: "To",
                      value: bookingData["destHub"] ?? "Unknown",
                    ),

                    _infoCard(
                      icon: Icons.straighten,
                      color: Colors.green,
                      title: "Distance",
                      value:
                          "${bookingData["distanceKm"].toStringAsFixed(2)} km",
                    ),

                    _infoCard(
                      icon: Icons.timer,
                      color: Colors.orange,
                      title: "Estimated Time",
                      value: "${bookingData["estimatedMinutes"]} minutes",
                    ),

                    _infoCard(
                      icon: Icons.currency_rupee,
                      color: Colors.purple,
                      title: "Total Price",
                      value:
                          "₹${bookingData["price"].toStringAsFixed(2)}",
                      bold: true,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            /// ✅ BUTTON ALWAYS VISIBLE
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    "Proceed to Payment",
                    style: TextStyle(
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
    } else {
      // Your nearby hubs code remains same
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.drag_handle),
            const SizedBox(height: 10),
            const Text(
              "Nearby EV Hubs",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      "${hub["distance"].toStringAsFixed(2)} km away",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
  }

Widget _infoCard({
  required IconData icon,
  required Color color,
  required String title,
  required String value,
  bool bold = false,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(
        value,
        style: bold
            ? const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              )
            : null,
      ),
    ),
  );
}
}

