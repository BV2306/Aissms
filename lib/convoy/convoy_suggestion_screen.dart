import 'package:flutter/material.dart';
import 'convoy_join_success.dart';

class ConvoySuggestionScreen extends StatelessWidget {
  const ConvoySuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = "Aditya Shagun Society";
    final metro = "Baner Metro";
    final time = "8:30 AM";
    final people = 6;
    final totalFare = 48;
    final pricePerPerson = totalFare ~/ people;
    final saving = 50 - pricePerPerson;

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Convoy Alert")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups,
                size: 80, color: Colors.blue),
            const SizedBox(height: 20),

            Text(
              "$people people in $society\nare going to $metro at $time",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            Text(
              "Shared ride costs ₹$pricePerPerson each",
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              "You save ₹$saving today",
              style: const TextStyle(color: Colors.green),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConvoyJoinSuccess(),
                  ),
                );
              },
              child: const Text("Tap to Join Convoy"),
            )
          ],
        ),
      ),
    );
  }
}