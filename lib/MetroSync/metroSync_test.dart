import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:async';


// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------
class RideGroup {
  final String title;
  final List<Map<String, dynamic>> vehicles;


  RideGroup({required this.title, required this.vehicles});
}


class MetroStation {
  final String name;
  final double lat;
  final double lon;


  MetroStation(this.name, this.lat, this.lon);
}


// -----------------------------------------------------------------------------
// MAIN WIDGET
// -----------------------------------------------------------------------------
class MetroBookingScreen extends StatefulWidget {
  const MetroBookingScreen({Key? key}) : super(key: key);


  @override
  _MetroBookingScreenState createState() => _MetroBookingScreenState();
}


class _MetroBookingScreenState extends State<MetroBookingScreen> {
  // 1. All Pune Metro Stations (Dummy Coordinates for real-life scaling)
  final List<MetroStation> stations = [
    MetroStation("PCMC", 18.6298, 73.7997),
    MetroStation("Sant Tukaram Nagar", 18.6180, 73.8056),
    MetroStation("Bhosari", 18.6110, 73.8120),
    MetroStation("Kasarwadi", 18.6030, 73.8200),
    MetroStation("Phugewadi", 18.5950, 73.8270),
    MetroStation("Dapodi", 18.5830, 73.8340),
    MetroStation("Bopodi", 18.5720, 73.8410),
    MetroStation("Shivajinagar", 18.5314, 73.8552),
    MetroStation("Civil Court", 18.5285, 73.8565),
    MetroStation("Pune Railway Station", 18.5289, 73.8744),
    MetroStation("Ruby Hall Clinic", 18.5330, 73.8810),
    MetroStation("Bund Garden", 18.5360, 73.8870),
    MetroStation("Kalyani Nagar", 18.5482, 73.9015),
    MetroStation("Ramwadi", 18.5530, 73.9120),
  ];


  MetroStation? selectedSource;
  MetroStation? selectedDestination;


  bool isJourneyActive = false;
  String journeyStatus = "Select stations to start journey";
  double journeyProgress = 0.0;
  Timer? journeyTimer;


  bool isLoading = false;
  bool isOptimized = false;
  List<RideGroup> displayGroups = [];


  @override
  void initState() {
    super.initState();
    selectedSource = stations[0]; // Default PCMC
    selectedDestination = stations[7]; // Default Shivajinagar
  }


  @override
  void dispose() {
    journeyTimer?.cancel();
    super.dispose();
  }


  // -----------------------------------------------------------------------------
  // MATH & LOGIC
  // -----------------------------------------------------------------------------


  // Haversine formula to calculate distance in kilometers
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0; // Earth radius in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);


    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);


    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }


  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }


  // Generate dynamic drivers around the DESTINATION station
  List<Map<String, dynamic>> _generateDriversNear(MetroStation destination) {
    final random = math.Random();
    List<Map<String, dynamic>> generatedDrivers = [];
    List<String> companies = ['ola', 'uber', 'rapido', 'namma yatri'];
    List<String> types = ['cab', 'bike', 'rickshaw'];


    for (int i = 0; i < 15; i++) {
      // Offset coordinates by roughly 0 to 3 km max
      double latOffset = (random.nextDouble() - 0.5) * 0.03;
      double lonOffset = (random.nextDouble() - 0.5) * 0.03;


      double driverLat = destination.lat + latOffset;
      double driverLon = destination.lon + lonOffset;


      // Calculate how far the driver is from the station
      double distKm = _calculateDistance(
          driverLat, driverLon, destination.lat, destination.lon);


      // Assume city speed of 25 km/h -> Time = Distance / Speed
      int etaMins = ((distKm / 25.0) * 60).round();
      if (etaMins < 1) etaMins = 1; // Minimum 1 min ETA


      String type = types[random.nextInt(types.length)];
      String company = companies[random.nextInt(companies.length)];


      generatedDrivers.add({
        "name": "$type-${random.nextInt(900) + 100}",
        "company": company,
        "type": type,
        "eta": etaMins, // Time to reach the station
        "dist": double.parse(distKm.toStringAsFixed(1)),
        "fare": (distKm * 15 + 30).round(), // Mock fare calculation
      });
    }


    // Sort by ETA ascending
    generatedDrivers
        .sort((a, b) => (a['eta'] as int).compareTo(b['eta'] as int));
    return generatedDrivers;
  }


  // -----------------------------------------------------------------------------
  // SIMULATION PIPELINE
  // -----------------------------------------------------------------------------
  void _startJourneySimulation() {
    if (selectedSource == null || selectedDestination == null) return;
    if (selectedSource == selectedDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Source and Destination cannot be the same!')),
      );
      return;
    }


    // 1. Calculate Metro Journey Distance and Time
    double journeyDistKm = _calculateDistance(
        selectedSource!.lat,
        selectedSource!.lon,
        selectedDestination!.lat,
        selectedDestination!.lon);


    // Assume metro goes ~35 km/h in a straight line
    int totalJourneyMins = ((journeyDistKm / 35.0) * 60).round();
    if (totalJourneyMins < 6)
      totalJourneyMins = 8; // Force a minimum time for demo purposes


    // 2. Determine Trigger Time (5 mins before arrival)
    int driverBufferMins = 5;
    int triggerTimeMins = totalJourneyMins - driverBufferMins;


    setState(() {
      isJourneyActive = true;
      journeyProgress = 0.0;
      journeyStatus =
          "Traveling from ${selectedSource!.name} to ${selectedDestination!.name}\nETA: $totalJourneyMins mins";
      displayGroups.clear(); // Clear old rides
    });


    // HACKATHON TIME SCALE: 1 simulated minute = 1 real second
    int currentSimulatedMin = 0;


    journeyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentSimulatedMin++;


      setState(() {
        journeyProgress = currentSimulatedMin / totalJourneyMins;
        journeyStatus =
            "In Transit... Arriving in ${totalJourneyMins - currentSimulatedMin} mins";
      });


      // TRIGGER THE BOOKING PROMPT
      if (currentSimulatedMin == triggerTimeMins) {
        timer.cancel(); // Pause journey so they can book
        _showSmartBookingPrompt(
            selectedDestination!, totalJourneyMins - currentSimulatedMin);
      }
    });
  }


  void _showSmartBookingPrompt(MetroStation destination, int minsRemaining) {
    // Generate the dummy drivers dynamically
    List<Map<String, dynamic>> nearbyDrivers =
        _generateDriversNear(destination);


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.train, color: Colors.blueAccent, size: 28),
              SizedBox(width: 10),
              Text("Arriving Soon!",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You will reach ${destination.name} in $minsRemaining minutes.",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "We found ${nearbyDrivers.length} drivers 2-5 mins away from the station. Book now to avoid waiting.",
                        style: TextStyle(
                            color: Colors.green.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _finishJourney();
              },
              child:
                  const Text("I'll wait", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _processBookings(nearbyDrivers);
                _finishJourney();
              },
              child: const Text("Show Rides"),
            ),
          ],
        );
      },
    );
  }


  void _processBookings(List<Map<String, dynamic>> rawDrivers) {
    setState(() {
      isLoading = true;
    });


    // Simulate an API call / Optimization calculation delay
    Future.delayed(const Duration(seconds: 1), () {
      List<RideGroup> newGroups = [];


      // Group 1: Perfect Matches (Drivers <= 5 mins away)
      List<Map<String, dynamic>> perfectMatches =
          rawDrivers.where((d) => d['eta'] <= 5).toList();
      if (perfectMatches.isNotEmpty) {
        newGroups.add(RideGroup(
            title: "🏆 Perfect Timing (Arriving as you step out)",
            vehicles: perfectMatches));
      }


      // Group 2: Others (Drivers > 5 mins away)
      List<Map<String, dynamic>> others =
          rawDrivers.where((d) => d['eta'] > 5).toList();
      if (others.isNotEmpty) {
        newGroups.add(RideGroup(
            title: "⏳ Slight Wait (Arriving shortly after)", vehicles: others));
      }


      setState(() {
        displayGroups = newGroups;
        isLoading = false;
        isOptimized = true;
      });
    });
  }


  void _finishJourney() {
    setState(() {
      journeyProgress = 1.0;
      journeyStatus = "Arrived at ${selectedDestination!.name}!";
      isJourneyActive = false;
    });
  }


  // -----------------------------------------------------------------------------
  // UI BUILDER
  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Micro Transit Booking",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // SIMULATION CONTROLS
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MetroStation>(
                        decoration: const InputDecoration(
                            labelText: "From", border: OutlineInputBorder()),
                        value: selectedSource,
                        isExpanded: true,
                        items: stations
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)))
                            .toList(),
                        onChanged: isJourneyActive
                            ? null
                            : (val) => setState(() => selectedSource = val),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<MetroStation>(
                        decoration: const InputDecoration(
                            labelText: "To", border: OutlineInputBorder()),
                        value: selectedDestination,
                        isExpanded: true,
                        items: stations
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)))
                            .toList(),
                        onChanged: isJourneyActive
                            ? null
                            : (val) =>
                                setState(() => selectedDestination = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),


                // Progress Bar
                if (isJourneyActive || journeyProgress == 1.0) ...[
                  LinearProgressIndicator(
                    value: journeyProgress,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.blueAccent,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(journeyStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold)),
                ],


                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isJourneyActive ? Colors.red.shade400 : Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isJourneyActive
                      ? () {
                          journeyTimer?.cancel();
                          setState(() => isJourneyActive = false);
                        }
                      : _startJourneySimulation,
                  icon: Icon(
                      isJourneyActive ? Icons.stop : Icons.directions_transit),
                  label: Text(
                      isJourneyActive
                          ? "Stop Simulation"
                          : "Start Metro Journey",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),


          // LOADING STATE
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),


          // GROUPED RIDES LIST
          if (!isLoading && displayGroups.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: displayGroups.length,
                itemBuilder: (context, groupIndex) {
                  final group = displayGroups[groupIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 8.0),
                          child: Text(
                            group.title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade800),
                          ),
                        ),
                        ...group.vehicles
                            .map((vehicle) => _buildVehicleCard(vehicle))
                            .toList(),
                      ],
                    ),
                  );
                },
              ),
            ),


          if (!isLoading && displayGroups.isEmpty && !isJourneyActive)
            Expanded(
              child: Center(
                child: Text("Start a journey to see smart recommendations.",
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ),
            )
        ],
      ),
    );
  }


  // Modernized Card Widget
  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_getIconForType(vehicle["type"]),
                  color: Colors.blue.shade700, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle["name"].toString().toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(vehicle["company"].toString().toUpperCase(),
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text("${vehicle['eta']} min away",
                            style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Padding(
                //   padding: const EdgeInsets.only(bottom: 8.0),
                //   child: Text("₹${vehicle["fare"]}",
                //       style: const TextStyle(
                //           fontWeight: FontWeight.w900,
                //           fontSize: 18,
                //           color: Colors.black87)),
                // ),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Booking ${vehicle["name"]}... Driver will meet you at the exit!')));
                    },
                    child: const Text("Book",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'cab':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      case 'rickshaw':
        return Icons.electric_rickshaw;
      default:
        return Icons.commute;
    }
  }


  Future<void> _openRideApp(String company) async {
    Uri url;


    switch (company.toLowerCase()) {
      case 'ola':
        url = Uri.parse('https://book.olacabs.com/');
        break;
      case 'uber':
        url = Uri.parse('https://m.uber.com/');
        break;
      case 'rapido':
        url = Uri.parse('https://www.rapido.bike/');
        break;
      case 'namma yatri':
        url = Uri.parse('https://nammayatri.in/');
        break;
      default:
        return;
    }


    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open ride app")),
      );
    }
  }
}






