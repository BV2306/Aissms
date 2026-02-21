import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './qr_code_screen.dart';

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

  // ✅ Hub-to-hub and rental bookings stored in separate sub-paths
  final DatabaseReference hubToHubRef =
      FirebaseDatabase.instance.ref("bookings/hub_to_hub");

  final DatabaseReference rentalRef =
      FirebaseDatabase.instance.ref("bookings/rental");

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
    final bool isRental = data['bookingType'] == 'rental';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isRental ? "Rental Payment" : "Payment"),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Order Summary ─────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isRental ? Icons.pedal_bike : Icons.route,
                        color: const Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRental ? "Rental Booking" : "Hub-to-Hub Booking",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text("Total Amount",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    "₹ ${(data['price'] as num).toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 12),
                  if (isRental) ...[
                    _summaryRow(Icons.location_on, "Pickup Hub",
                        "${data['sourceHub']}"),
                    _summaryRow(
                        Icons.flag,
                        "Submission Hub",
                        data['sameHub'] == true
                            ? "${data['submissionHub']} (same)"
                            : "${data['submissionHub']}"),
                    _summaryRow(Icons.calendar_today, "Date",
                        "${data['scheduledDate']}"),
                    _summaryRow(Icons.access_time, "Time",
                        "${data['startTime']} → ${data['endTime']}"),
                    _summaryRow(Icons.timer, "Duration",
                        "${(data['durationMinutes'] as num) ~/ 60}h ${(data['durationMinutes'] as num) % 60}m"),
                    if ((data['distanceKm'] as num) > 0)
                      _summaryRow(Icons.straighten, "Drop-off distance",
                          "${(data['distanceKm'] as num).toStringAsFixed(2)} km"),
                  ] else ...[
                    _summaryRow(Icons.location_on, "From",
                        "${data['sourceHub']}"),
                    _summaryRow(
                        Icons.flag, "To", "${data['destHub']}"),
                    _summaryRow(Icons.straighten, "Distance",
                        "${(data['distanceKm'] as num).toStringAsFixed(2)} km"),
                    _summaryRow(Icons.timer, "Estimated Time",
                        "${data['estimatedMinutes']} min"),
                  ],
                ],
              ),
            ),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Choose Payment Method",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: paymentMethods
                    .map((m) =>
                        _paymentTile(m["title"] as String, m["icon"] as IconData))
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
                            : "Pay ₹${(data['price'] as num).toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  Widget _summaryRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text("$label: ",
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _paymentTile(String title, IconData icon) => Card(
        child: RadioListTile<String>(
          value: title,
          groupValue: selectedMethod,
          onChanged: (v) =>
              setState(() => selectedMethod = v),
          title: Text(title),
          secondary: Icon(icon, color: const Color(0xFF2563EB)),
        ),
      );

  // =====================================================
  // 🔥 MAIN BOOKING LOGIC
  // =====================================================
  Future<void> _processPayment() async {
    setState(() => isProcessing = true);

    // Simulated payment processing delay
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final data = widget.bookingData!;
    final bool isRental = data['bookingType'] == 'rental';

    try {
      final userPhone =
          FirebaseAuth.instance.currentUser?.phoneNumber ?? "unknown";
      final sourceLocality = data['sourceLocality'] as String;
      final sourceHub = data['sourceHub'] as String;

      // ─── Find & allocate an available bicycle ──────────
      final hubSnap =
          await bicyclesRef.child(sourceLocality).child(sourceHub).get();

      if (!hubSnap.exists) throw Exception("No bicycles at hub");

      final bikesMap =
          Map<String, dynamic>.from(hubSnap.value as Map);

      String? allocatedBikeId;
      for (final entry in bikesMap.entries) {
        final bike = Map<String, dynamic>.from(entry.value as Map);
        if (bike['availability'] == 'yes') {
          allocatedBikeId = entry.key;
          break;
        }
      }

      if (allocatedBikeId == null) {
        throw Exception("No available bicycle at this hub");
      }

      // ─── Lock the bicycle ───────────────────────────────
      await bicyclesRef
          .child(sourceLocality)
          .child(sourceHub)
          .child(allocatedBikeId)
          .update({
        "availability": "no",
        "allocated_to": userPhone,
      });

      Map<String, dynamic> bookingPayload;

      if (isRental) {
        // ─── RENTAL BOOKING ─────────────────────────────
        final bookingRef = rentalRef.push();

        bookingPayload = {
          "bookingId": bookingRef.key,
          "bookingType": "rental",
          "userPhone": userPhone,
          "sourceLocality": sourceLocality,
          "sourceHub": sourceHub,
          "submissionLocality": data['submissionLocality'],
          "submissionHub": data['submissionHub'],
          "sameHub": data['sameHub'] ?? true,
          "bicycleId": allocatedBikeId,
          "scheduledDate": data['scheduledDate'],
          "startTime": data['startTime'],
          "endTime": data['endTime'],
          "durationMinutes": data['durationMinutes'],
          "distanceKm": data['distanceKm'],
          "price": data['price'],
          "bookingStatus": "booked",
          "penaltyCharge": 0,
          "createdAt": ServerValue.timestamp,
        };

        await bookingRef.set(bookingPayload);
      } else {
        // ─── HUB-TO-HUB BOOKING ─────────────────────────
        final bookingRef = hubToHubRef.push();

        final int allocatedMinutes =
            (data['estimatedMinutes'] as num).toInt() +
                (data['extraMinutes'] as num? ?? 0).toInt();

        bookingPayload = {
          "bookingId": bookingRef.key,
          "bookingType": "hub_to_hub",
          "userPhone": userPhone,
          "sourceLocality": sourceLocality,
          "sourceHub": sourceHub,
          "destLocality": data['destLocality'],
          "destinationHub": data['destHub'],
          "bicycleId": allocatedBikeId,
          "distanceKm": data['distanceKm'],
          "allocatedMinutes": allocatedMinutes,
          "price": data['price'],
          "bookingStatus": "booked",
          "createdAt": ServerValue.timestamp,
        };

        await bookingRef.set(bookingPayload);
      }

      if (!mounted) return;
      setState(() => isProcessing = false);

      // Navigate to QR screen, remove intermediate routes from stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => QRCodeScreen(qrData: bookingPayload),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking failed: $e")),
      );
    }
  }
}