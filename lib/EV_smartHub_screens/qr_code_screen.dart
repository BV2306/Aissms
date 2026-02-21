import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'ride_started_screen.dart'; // adjust if needed

class QRCodeScreen extends StatefulWidget {
  final Map<String, dynamic> qrData;

  const QRCodeScreen({
    super.key,
    required this.qrData,
  });

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  late final DatabaseReference bookingRef;
  StreamSubscription<DatabaseEvent>? _bookingSub;

  @override
  void initState() {
    super.initState();

    final bookingId = widget.qrData["bookingId"];

    // 🔥 reference to this booking
    bookingRef =
        FirebaseDatabase.instance.ref("bookings").child(bookingId);

    _listenBookingStatus();
  }

  // =====================================================
  // 🔥 LISTEN FOR STATUS CHANGE
  // =====================================================
  void _listenBookingStatus() {
    _bookingSub = bookingRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);

      final status = data["bookingStatus"];

      // ✅ when scanner marks alloted → start ride
      if (status == "alloted") {
        _bookingSub?.cancel();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideStartedScreen(
              bookingData: widget.qrData,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrString = jsonEncode(widget.qrData);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Unlock Cycle"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Scan this QR to unlock your bicycle",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // ✅ QR
              QrImageView(
                data: qrString,
                version: QrVersions.auto,
                size: 240,
              ),

              const SizedBox(height: 20),

              const Text(
                "Waiting for cycle to be alloted...",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
