import 'package:flutter/material.dart';
import '../Grouping_feature/single_ride.dart';
import '../Grouping_feature//shared_ride.dart';


class RidesPage extends StatelessWidget {
  const RidesPage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), // Uber-like light grey
      appBar: AppBar(
        title: const Text(
          "Rides",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 Single Ride Card
            RideOptionCard(
              title: "Single Ride",
              subtitle: "Private ride for you",
              icon: Icons.directions_car,
              onTap: () {              
              Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LocationSelectionScreen()),
            );
              },
            ),


            const SizedBox(height: 16),


            // 🔹 Shared Ride Card
            RideOptionCard(
              title: "Shared Ride",
              subtitle: "Save money by sharing",
              icon: Icons.people,
              onTap: () {
                  Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SharedRideSelectionPage()),
            );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class RideOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;


  const RideOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),


              const SizedBox(width: 16),


              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),


              // Arrow
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}





