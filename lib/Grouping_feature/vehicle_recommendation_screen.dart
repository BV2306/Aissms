import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RideGroup {
  final String title;
  final List<Map<String, dynamic>> vehicles;

  RideGroup({required this.title, required this.vehicles});
}

class VehicleRecommendationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles; // 🔥 dynamic data

  const VehicleRecommendationScreen({
    super.key,
    required this.vehicles,
  });

  @override
  State<VehicleRecommendationScreen> createState() =>
      _VehicleRecommendationScreenState();
}

class _VehicleRecommendationScreenState
    extends State<VehicleRecommendationScreen> {
  bool isLoading = false;
  bool isOptimized = false;
  List<RideGroup> displayGroups = [];

  @override
  void initState() {
    super.initState();

    // Initially show all vehicles
    displayGroups = [
      RideGroup(title: "Available Rides", vehicles: widget.vehicles)
    ];
  }

  Future<void> fetchOptimizedOrder() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://wwrhvg0w-8000.inc1.devtunnels.ms/recommend'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "start_lat": widget.vehicles.first['pickupLat'],
          "start_lon": widget.vehicles.first['pickupLong'],
          "end_lat": widget.vehicles.first['lat'],
          "end_lon": widget.vehicles.first['long'],
        }),
      );

      final responseData = jsonDecode(response.body);
      final List rankingList = responseData['ranking'];

      List<RideGroup> newGroups = [];
      List<String> titles = [
        "🏆 Top Recommendation",
        "🌟 Second Choice",
        "👍 Alternative Options"
      ];

      int titleIndex = 0;
      Set<String> processedTypes = {};

      for (var rank in rankingList) {
        String apiType = rank['type'];

        List<Map<String, dynamic>> matchingVehicles =
            widget.vehicles.where((v) {
          String vType = v["type"] == "rickshaw" ? "auto" : v["type"];
          return vType == apiType;
        }).toList();

        if (matchingVehicles.isNotEmpty) {
          newGroups.add(
            RideGroup(
              title: titleIndex < titles.length
                  ? titles[titleIndex]
                  : "Other Options",
              vehicles: matchingVehicles,
            ),
          );

          processedTypes.add(apiType);
          titleIndex++;
        }
      }

      List<Map<String, dynamic>> unranked = widget.vehicles.where((v) {
        String vType = v["type"] == "rickshaw" ? "auto" : v["type"];
        return !processedTypes.contains(vType);
      }).toList();

      if (unranked.isNotEmpty) {
        newGroups.add(RideGroup(title: "More Options", vehicles: unranked));
      }

      setState(() {
        displayGroups = newGroups;
        isOptimized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Slightly off-white background for modern look
      appBar: AppBar(
        title: const Text(
          "Optimized Rides",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // -----------------------------------------------------------------
          // Top Action Button
          // -----------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, // Full width button
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : fetchOptimizedOrder,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.route),
                label: const Text(
                  "Weather and Traffic FACTOR",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
          
          // -----------------------------------------------------------------
          // Vehicle List
          // -----------------------------------------------------------------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: displayGroups.length,
              itemBuilder: (context, groupIndex) {
                final group = displayGroups[groupIndex];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.grey[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    
                    // Vehicle Cards
                    ...group.vehicles.map((vehicle) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icon container
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Text Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle["name"] ?? "Vehicle",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      vehicle["company"] ?? "Company",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Book Now Button
                              ElevatedButton(
                                onPressed: () {
                                  // TODO: Add Booking Action logic here
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "BOOK NOW",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}