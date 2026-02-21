import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Driver/provider_register_screen.dart';
import 'Seeker/seeker_register_screen.dart';
import 'Driver/provider_dashboard.dart';
import 'Seeker/seeker_dashboard.dart';

class CheckUserRoleScreen extends StatefulWidget {
  final String role;
  const CheckUserRoleScreen({super.key, required this.role});

  @override
  State<CheckUserRoleScreen> createState() => _CheckUserRoleScreenState();
}

class _CheckUserRoleScreenState extends State<CheckUserRoleScreen> {
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  Future<void> checkUser() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final collection =
        widget.role == "provider" ? "rideProviders" : "rideSeekers";

    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(uid)
        .get();

    if (doc.exists) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == "provider"
              ? const ProviderDashboard()
              : const SeekerDashboard(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.role == "provider"
              ? const ProviderRegisterScreen()
              : const SeekerRegisterScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}