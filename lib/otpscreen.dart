import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;

  const OTPScreen({super.key, required this.verificationId});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  void verifyOTP() async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otpController.text.trim(),
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      String phoneNumber = userCredential.user?.phoneNumber ?? '';
      String documentId = phoneNumber.replaceAll('+', '').replaceAll(' ', '');

      // Save to Firestore
      await _firestore.collection('users').doc(documentId).set({
        'phoneNumber': phoneNumber,
        'uid': userCredential.user?.uid,
        'registeredAt': FieldValue.serverTimestamp(),
      });

      // Save to Realtime Database
      await _database.ref('users/$documentId').set({
        'phoneNumber': phoneNumber,
        'uid': userCredential.user?.uid,
        'registeredAt': DateTime.now().toIso8601String(),
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const EVMapScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter OTP")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter OTP",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: verifyOTP,
              child: const Text("Verify"),
            ),
          ],
        ),
      ),
    );
  }
}
