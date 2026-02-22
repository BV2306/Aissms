import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MetroSmartHubDemo extends StatefulWidget {
  const MetroSmartHubDemo({super.key});

  @override
  State<MetroSmartHubDemo> createState() => _MetroSmartHubDemoState();
}

class _MetroSmartHubDemoState extends State<MetroSmartHubDemo>
    with SingleTickerProviderStateMixin {
  int remainingSeconds = 30;
  bool isSearching = false;
  bool syncing = false;
  bool rideReady = false;
  String selectedRide = "";
  String? selectedDestination;
  Timer? timer;

  late AnimationController _metroAnimController;
  late Animation<Offset> _metroAnimation;

  // Real-time user location
  LatLng? userLocation;
  bool isLoadingLocation = true;

  // Comprehensive list of Pune Metro Stations
  final List<String> puneDestinations = [
    "Anand Nagar Metro Station",
    "Bhosari (Nashik Phata) Metro Station",
    "Bopodi Metro Station",
    "Budhwar Peth Metro Station",
    "Bund Garden Metro Station",
    "Chhatrapati Sambhaji Udyan Metro Station",
    "Civil Court Metro Station",
    "Dapodi Metro Station",
    "Deccan Gymkhana Metro Station",
    "Garware College Metro Station",
    "Ideal Colony Metro Station",
    "Kalyani Nagar Metro Station",
    "Kasarwadi Metro Station",
    "Khadki Metro Station",
    "Mandai Metro Station",
    "Mangalwar Peth Metro Station",
    "Nal Stop Metro Station",
    "PCMC Metro Station",
    "Phugewadi Metro Station",
    "PMC Metro Station",
    "Pune Railway Station Metro Station",
    "Ramwadi Metro Station",
    "Range Hill Metro Station",
    "Ruby Hall Clinic Metro Station",
    "Sant Tukaram Nagar Metro Station",
    "Shivaji Nagar Metro Station",
    "Swargate Metro Station",
    "Vanaz Metro Station",
    "Yerawada Metro Station"
  ];

  late Map<String, Map<String, dynamic>> rideOptions;

  @override
  void initState() {
    super.initState();
    // Initialize animation for the moving metro
    _metroAnimController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _metroAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0.0), // Start slightly left
      end: const Offset(0.5, 0.0), // Move to slightly right
    ).animate(CurvedAnimation(
      parent: _metroAnimController,
      curve: Curves.easeInOut,
    ));

    // Fetch user's actual location
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setFallbackLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setFallbackLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setFallbackLocation();
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    
    _initializeVehiclesNearLocation(LatLng(position.latitude, position.longitude));
  }

  void _setFallbackLocation() {
    // Default to Pune Swargate if location fails/denied
    _initializeVehiclesNearLocation(const LatLng(18.5018, 73.8636));
  }

  void _initializeVehiclesNearLocation(LatLng location) {
    setState(() {
      userLocation = location;
      // Dynamically generate vehicle coordinates slightly offset from user's REAL location
      rideOptions = {
        "Smart Hub Bike": {
          "icon": "🚲",
          "message": "Your bike is ready at Exit Gate 2",
          "number": "MH-12-BK-9921",
          "driver": "Self-driven",
          "model": "Yulu Miracle",
          "lat": location.latitude + 0.0012, // slightly north
          "lng": location.longitude + 0.0015, // slightly east
        },
        "Auto": {
          "icon": "🛵",
          "message": "Your auto is waiting at Exit Gate 3",
          "number": "MH-12-AU-4521",
          "driver": "Suresh Kale",
          "model": "Bajaj RE",
          "lat": location.latitude - 0.0015, // slightly south
          "lng": location.longitude + 0.0010,
        },
        "Cab": {
          "icon": "🚕",
          "message": "Your cab is arriving at Pickup Zone A",
          "number": "MH-12-CB-1122",
          "driver": "Prakash Patil",
          "model": "Maruti Dzire",
          "lat": location.latitude + 0.0020,
          "lng": location.longitude - 0.0018,
        },
        "Bike Taxi": {
          "icon": "🏍️",
          "message": "Your bike taxi captain is ready at Gate 1",
          "number": "MH-14-BT-7744",
          "driver": "Amit",
          "model": "Honda Activa",
          "lat": location.latitude - 0.0010,
          "lng": location.longitude - 0.0020,
        },
      };
      isLoadingLocation = false;
    });
  }

  void confirmBooking(String ride) {
    if (selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a destination first!")),
      );
      return;
    }

    setState(() {
      selectedRide = ride;
      isSearching = true;
    });

    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;

      setState(() {
        isSearching = false;
      });

      startSync();
    });
  }

  void startSync() {
    setState(() {
      syncing = true;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        remainingSeconds--;
      });

      if (remainingSeconds == 10) {
        setState(() {
          rideReady = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "${rideOptions[selectedRide]!["icon"]} ${rideOptions[selectedRide]!["message"]}",
            ),
          ),
        );
      }

      if (remainingSeconds <= 0) {
        timer.cancel();
      }
    });
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  void dispose() {
    timer?.cancel();
    _metroAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pune Metro Smart Sync")),
      body: isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Detecting your location..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Moving Metro instead of static icon
                  SizedBox(
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Draw a track line
                        Container(
                          height: 4,
                          width: 200,
                          color: Colors.grey.shade300,
                        ),
                        SlideTransition(
                          position: _metroAnimation,
                          child: const Icon(Icons.directions_subway,
                              size: 80, color: Colors.blueAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dynamically show the current location Coordinates
                  Text(
                    "Arriving at Current Location\n(${userLocation!.latitude.toStringAsFixed(4)}, ${userLocation!.longitude.toStringAsFixed(4)})",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 30),

                  // 1. Initial State: Choosing Destination & Ride
                  if (!isSearching && !syncing) ...[
                    // Destination Selection Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Where are you heading?"),
                          value: selectedDestination,
                          icon:
                              const Icon(Icons.location_on, color: Colors.red),
                          items: puneDestinations.map((String dest) {
                            return DropdownMenuItem<String>(
                              value: dest,
                              child: Text(dest,
                                  style: const TextStyle(fontSize: 16)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedDestination = newValue;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      "Choose Your Ride",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),

                    ...rideOptions.keys.map((ride) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: selectedDestination == null
                                ? null // Disable buttons until destination is selected
                                : () => confirmBooking(ride),
                            icon: Text(rideOptions[ride]!["icon"],
                                style: const TextStyle(fontSize: 20)),
                            label: Text(ride,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  // 2. Searching State
                  if (isSearching) ...[
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: Colors.black87),
                    const SizedBox(height: 30),
                    Text(
                      "Locating nearest $selectedRide...",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Booking trip to $selectedDestination.\nConfirming vehicle details with the hub.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],

                  // 3. Syncing State: Ride confirmed, showing details & timer
                  if (syncing) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              rideOptions[selectedRide]!["icon"],
                              style: const TextStyle(fontSize: 40),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Booking Confirmed to $selectedDestination",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rideOptions[selectedRide]!["number"],
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5),
                            ),
                            const Divider(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Model",
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                    Text(rideOptions[selectedRide]!["model"],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Driver",
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                    Text(rideOptions[selectedRide]!["driver"],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      "Syncing ride with metro arrival...",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      formatTime(remainingSeconds),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: rideReady ? Colors.green : Colors.black87,
                      ),
                    ),
                  ],

                  // 4. Ride Ready State
                  if (rideReady) ...[
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VehicleLocationMapScreen(
                                vehicleDetails: rideOptions[selectedRide]!,
                                userLocation: userLocation!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: const Text("View Map & Start Ride",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Map Screen
// -----------------------------------------------------------------------------

class VehicleLocationMapScreen extends StatelessWidget {
  final Map<String, dynamic> vehicleDetails;
  final LatLng userLocation;

  const VehicleLocationMapScreen({
    super.key,
    required this.vehicleDetails,
    required this.userLocation,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng vehicleLocation =
        LatLng(vehicleDetails["lat"], vehicleDetails["lng"]);

    return Scaffold(
      appBar: AppBar(title: const Text("Locate Your Ride")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Text(vehicleDetails["icon"],
                    style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleDetails["message"],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Vehicle: ${vehicleDetails["number"]}"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: userLocation,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.lastmile_transport",
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [userLocation, vehicleLocation],
                      strokeWidth: 4,
                      color: Colors.blueAccent,
                      isDotted: true,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userLocation,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.blue, size: 40),
                    ),
                    Marker(
                      point: vehicleLocation,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on,
                          color: Colors.green, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan QR to Unlock",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}