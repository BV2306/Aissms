import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lastmile_transport/Grouping_feature/payment_shared_screen.dart';

class RideGroupScreen extends StatefulWidget {
  final String groupId;

  const RideGroupScreen({super.key, required this.groupId});

  @override
  State<RideGroupScreen> createState() => _RideGroupScreenState();
}

class _RideGroupScreenState extends State<RideGroupScreen> {
  final dbRef = FirebaseDatabase.instance.ref();

  bool showPaymentButton = false;
  bool bookingStarted = false;

  void startBookingFlow() {
    if (bookingStarted) return;
    bookingStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  "Booking your shared ride...",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).pop();

        setState(() {
          showPaymentButton = true;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Ride Group",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: dbRef
                  .child("rideGroups/${widget.groupId}/members")
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }

                final data = snapshot.data!.snapshot.value as Map?;

                if (data == null) {
                  return const Center(child: Text("No members"));
                }

                final members = data.keys.toList();

                if (members.length == 3 && !bookingStarted) {
                  startBookingFlow();
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      "Group Members",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    ...members.map((member) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primary,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "User: $member",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 20),
                    Divider(color: primary.withOpacity(0.3)),
                    const SizedBox(height: 20),

                    const Text(
                      "Nearby Users",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    StreamBuilder(
                      stream: dbRef.child("users").onValue,
                      builder: (context, snapshot2) {
                        if (!snapshot2.hasData) {
                          return const SizedBox();
                        }

                        final usersData =
                            snapshot2.data!.snapshot.value as Map?;

                        if (usersData == null) {
                          return const SizedBox();
                        }

                        return Column(
                          children: usersData.entries.map((entry) {
                            final userId = entry.key;

                            if (members.contains(userId)) {
                              return const SizedBox();
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: primary,
                                    child: const Icon(
                                      Icons.person_add,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text("User: $userId")),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                    ),
                                    onPressed: () {
                                      dbRef
                                          .child(
                                              "rideGroups/${widget.groupId}/members/$userId")
                                          .set(true);
                                    },
                                    child: const Text(
                                      "Add",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const PaymentScreen(),
                  ),
                );
              },
              child: Text(
                showPaymentButton
                    ? "Continue to Payment"
                    : "Continue to Ride",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}