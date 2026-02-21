import 'package:flutter/material.dart';
import 'package:lastmile_transport/Paid_Lift/Driver/add_ride_screen_.dart';

class ProviderDashboard extends StatelessWidget {
  const ProviderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Provider Dashboard")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddRideScreen(),
              ),
            );
          },
          child: const Text("Create Ride"),
        ),
      ),
    );
  }
}