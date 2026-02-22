import 'dart:async';
import 'package:flutter/material.dart';
import 'convoy_suggestion_screen.dart';

class ConvoyLearningScreen extends StatefulWidget {
  const ConvoyLearningScreen({super.key});

  @override
  State<ConvoyLearningScreen> createState() =>
      _ConvoyLearningScreenState();
}

class _ConvoyLearningScreenState extends State<ConvoyLearningScreen> {
  int daysAnalysed = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      setState(() {
        daysAnalysed++;
      });

      if (daysAnalysed == 14) {
        timer.cancel();

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ConvoySuggestionScreen(),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Behaviour Engine")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology,
                size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            const Text(
              "Learning commute patterns...",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              "Days analysed: $daysAnalysed / 14",
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}