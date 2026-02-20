import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../utlis/meter_price.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LocationSelectionScreen(),
  ));
}


class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});


  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}


class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropController = TextEditingController();


  String activeField = "pickup";


  double? pickupLat;
  double? pickupLong;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Locations")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: pickupController,
                  decoration: const InputDecoration(
                    hintText: "Enter Pickup Location",
                    prefixIcon: Icon(Icons.my_location, color: Colors.green),
                  ),
                  onTap: () {
                    activeField = "pickup";
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dropController,
                  decoration: const InputDecoration(
                    hintText: "Enter Destination",
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                  ),
                  onTap: () {
                    activeField = "drop";
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore.collection('Locations').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }


                final docs = snapshot.data!.docs;


                String searchText = activeField == "pickup"
                    ? pickupController.text.toLowerCase()
                    : dropController.text.toLowerCase();


                final filteredDocs = docs.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  return name.contains(searchText);
                }).toList();


                if (filteredDocs.isEmpty) {
                  return const Center(child: Text("No matching locations"));
                }


                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data() as Map<String, dynamic>;


                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(data['name']),
                      subtitle: Text(data['type']),
                      onTap: () {
                        if (activeField == "pickup") {
                          pickupController.text = data['name'];
                          pickupLat = data['lat'];
                          pickupLong = data['long'];
                        } else {
                          dropController.text = data['name'];
                        }
                        setState(() {});
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (pickupLat != null && pickupLong != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RidersPage(
                        pickupLat: pickupLat!,
                        pickupLong: pickupLong!,
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}


class RidersPage extends StatelessWidget {
  final double pickupLat;
  final double pickupLong;


  const RidersPage({
    super.key,
    required this.pickupLat,
    required this.pickupLong,
  });


  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;


    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);


    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);


    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }


  int calculatePlatformPrice(double distanceKm, String type) {
    if (type == "rickshaw") {
      return (distanceKm * 22).round();
    } else if (type == "cab") {
      return (distanceKm * 30).round();
    } else {
      return (distanceKm * 18).round();
    }
  }


  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;


    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Choose a Ride"),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('Riders').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }


          final docs = snapshot.data!.docs;


          final nearbyRiders = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;


            double riderLat = data['lat'];
            double riderLong = data['long'];


            double distance = calculateDistance(
              pickupLat,
              pickupLong,
              riderLat,
              riderLong,
            );


            return distance <= 0.5;
          }).toList();


          if (nearbyRiders.isEmpty) {
            return const Center(child: Text("No riders within 500m"));
          }


          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: nearbyRiders.length,
            itemBuilder: (context, index) {
              final data =
                  nearbyRiders[index].data() as Map<String, dynamic>;


              double riderLat = data['lat'];
              double riderLong = data['long'];


              double distanceKm = calculateDistance(
                pickupLat,
                pickupLong,
                riderLat,
                riderLong,
              );


              double distanceMeters = distanceKm * 1000;


              bool isAuto = data['type'] == "rickshaw";


              int meterPrice = PuneFareCalculator.calculateFare(
                distance: distanceKm,
                isAuto: isAuto,
              );


              int platformPrice =
                  calculatePlatformPrice(distanceKm, data['type']);


              bool isMeterCheaper = meterPrice < platformPrice;


              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.black,
                      child: Icon(
                        data['type'] == "cab"
                            ? Icons.local_taxi
                            : Icons.electric_rickshaw,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'],
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${data['company']} • ${distanceMeters.toStringAsFixed(0)} m away",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                "Meter: ₹$meterPrice",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isMeterCheaper
                                      ? Colors.green
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Platform: ₹$platformPrice",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}





