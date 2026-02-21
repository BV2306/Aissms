import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'provider_dashboard.dart';

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});

  @override
  State<ProviderRegisterScreen> createState() =>
      _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final nameController = TextEditingController();
  final vehicleTypeController = TextEditingController();
  final vehicleNumberController = TextEditingController();

  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    phoneNumber = user.phoneNumber;
  }

  Future<void> registerProvider() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection("rideProviders")
        .doc(uid)
        .set({
      "name": nameController.text.trim(),
      "phone": phoneNumber,
      "vehicleType": vehicleTypeController.text.trim(),
      "vehicleNumber": vehicleNumberController.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProviderDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Provider Registration")),
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
              controller: vehicleTypeController,
              decoration: const InputDecoration(labelText: "Vehicle Type"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vehicleNumberController,
              decoration: const InputDecoration(labelText: "Vehicle Number"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: registerProvider,
              child: const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}