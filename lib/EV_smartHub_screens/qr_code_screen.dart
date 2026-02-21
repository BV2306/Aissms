import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'ride_started_screen.dart';

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

    final bookingId = widget.qrData["bookingId"] as String;
    final bookingType = widget.qrData["bookingType"] as String? ?? "hub_to_hub";

    // ✅ Listen on the correct sub-path based on booking type
    final String dbPath = bookingType == "rental"
        ? "bookings/rental/$bookingId"
        : "bookings/hub_to_hub/$bookingId";

    bookingRef = FirebaseDatabase.instance.ref(dbPath);

    _listenBookingStatus();
  }

  // =====================================================
  // 🔥 LISTEN FOR STATUS CHANGE (alloted → start ride)
  // =====================================================
  void _listenBookingStatus() {
    _bookingSub = bookingRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      final status = data["bookingStatus"];

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
    final bool isRental =
        (widget.qrData["bookingType"] as String?) == "rental";

    return Scaffold(
      appBar: AppBar(
        title: Text(isRental ? "Rental QR Code" : "Unlock Cycle"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Booking type badge ─────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isRental
                      ? const Color(0xFF10B981)
                      : const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isRental ? "🚲 Rental Booking" : "🗺️ Hub-to-Hub Booking",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Scan this QR to unlock your bicycle",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // ─── Quick info ──────────────────────────────
              if (isRental) ...[
                Text(
                  "${widget.qrData['sourceHub']}  →  ${widget.qrData['submissionHub']}",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "${widget.qrData['scheduledDate']}  •  "
                  "${widget.qrData['startTime']} – ${widget.qrData['endTime']}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ] else ...[
                Text(
                  "${widget.qrData['sourceHub']}  →  ${widget.qrData['destinationHub']}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 28),

              // ─── QR Code ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 28),

              // ─── Booking ID ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Booking ID: ${widget.qrData['bookingId']}",
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Status indicator ─────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isRental
                        ? "Waiting for bicycle to be allotted..."
                        : "Waiting for cycle to be allotted...",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}