import 'package:flutter/material.dart';

class ConvoyJoinSuccess extends StatelessWidget {
  const ConvoyJoinSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle,
                  size: 100, color: Colors.green),
              SizedBox(height: 20),
              Text(
                "You Joined the Smart Convoy 🎉",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "Pickup auto will arrive at\nAditya Shagun Gate A at 8:25 AM",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}