import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'seeker_dashboard.dart';

class SeekerRegisterScreen extends StatefulWidget {
  const SeekerRegisterScreen({super.key});

  @override
  State<SeekerRegisterScreen> createState() =>
      _SeekerRegisterScreenState();
}

class _SeekerRegisterScreenState extends State<SeekerRegisterScreen> {
  final nameController = TextEditingController();
  final rideTypeController = TextEditingController();

  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    phoneNumber = user.phoneNumber;
  }

  Future<void> registerSeeker() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection("rideSeekers")
        .doc(uid)
        .set({
      "name": nameController.text.trim(),
      "phone": phoneNumber,
      "preferredRideType": rideTypeController.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SeekerDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seeker Registration")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Full Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: "Phone",
                hintText: phoneNumber ?? "",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rideTypeController,
              decoration:
                  const InputDecoration(labelText: "Preferred Ride Type"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: registerSeeker,
              child: const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}