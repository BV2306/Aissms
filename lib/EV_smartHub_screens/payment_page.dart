import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './qr_code_screen.dart'; // 🔴 adjust path if needed

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const PaymentPage({super.key, this.bookingData});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool isProcessing = false;
  String? selectedMethod;

  final DatabaseReference bicyclesRef =
      FirebaseDatabase.instance.ref("bicycles");

  final DatabaseReference bookingsRef =
      FirebaseDatabase.instance.ref("bookings");

  final List<Map<String, dynamic>> paymentMethods = [
    {"title": "Google Pay", "icon": Icons.account_balance_wallet},
    {"title": "PhonePe", "icon": Icons.phone_android},
    {"title": "Paytm", "icon": Icons.payment},
    {"title": "Credit / Debit Card", "icon": Icons.credit_card},
    {"title": "UPI ID", "icon": Icons.qr_code},
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(child: Text('No booking data available')),
      );
    }

    final data = widget.bookingData!;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Payment"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= ORDER SUMMARY =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Amount"),
                  const SizedBox(height: 5),
                  Text(
                    "₹ ${data['price'].toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text("From: ${data['sourceHub']}"),
                  Text("To: ${data['destHub']}"),
                  Text(
                      "Distance: ${data['distanceKm'].toStringAsFixed(2)} km"),
                  Text("Time: ${data['estimatedMinutes']} min"),
                ],
              ),
            ),

            const Text(
              "Choose Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: ListView(
                children: paymentMethods
                    .map((m) => _paymentTile(m["title"], m["icon"]))
                    .toList(),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (selectedMethod == null || isProcessing)
                        ? null
                        : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        selectedMethod == null
                            ? "Select a Method"
                            : "Pay ₹${data['price'].toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(String title, IconData icon) {
    return Card(
      child: RadioListTile(
        value: title,
        groupValue: selectedMethod,
        onChanged: (value) {
          setState(() => selectedMethod = value.toString());
        },
        title: Text(title),
        secondary: Icon(icon),
      ),
    );
  }

  // =====================================================
  // 🔥 MAIN BOOKING LOGIC
  // =====================================================
  Future<void> _processPayment() async {
    setState(() => isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final data = widget.bookingData!;
      final sourceLocality = data['sourceLocality'];
      final sourceHub = data['sourceHub'];
      final destHub = data['destHub'];

      final userPhone =
          FirebaseAuth.instance.currentUser?.phoneNumber ?? "unknown";

      // 🔥 find available bicycle
      final hubSnap = await bicyclesRef
          .child(sourceLocality)
          .child(sourceHub)
          .get();

      if (!hubSnap.exists) throw Exception("No bicycles at hub");

      final bikesMap = Map<String, dynamic>.from(hubSnap.value as Map);

      String? allocatedBikeId;

      for (final entry in bikesMap.entries) {
        final bike = Map<String, dynamic>.from(entry.value);
        if (bike['availability'] == 'yes') {
          allocatedBikeId = entry.key;
          break;
        }
      }

      if (allocatedBikeId == null) {
        throw Exception("No available bicycle");
      }

      // 🔥 lock bike
      await bicyclesRef
          .child(sourceLocality)
          .child(sourceHub)
          .child(allocatedBikeId)
          .update({
        "availability": "no",
        "allocated_to": userPhone,
      });

      // 🔥 create booking
      final bookingRef = bookingsRef.push();

      final int allocatedMinutes = (data['estimatedMinutes'] ?? 0) + (data['extraMinutes'] ?? 0);

      final bookingPayload = {
        "bookingId": bookingRef.key,
        "userPhone": userPhone,
        "sourceHub": sourceHub,
        "destinationHub": destHub,
        "bicycleId": allocatedBikeId,
        "bookingStatus": "booked",
        "allocatedMinutes": allocatedMinutes,
        "createdAt": ServerValue.timestamp,
      };

      await bookingRef.set(bookingPayload);

      if (!mounted) return;
      setState(() => isProcessing = false);

      // Push QR screen and remove intermediate routes so back returns to the app's home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => QRCodeScreen(qrData: bookingPayload),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Booking failed: $e")));
    }
  }
}