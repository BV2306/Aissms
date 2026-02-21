import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lastmile_transport/Grouping_feature/ride_group_screen.dart';

class NearbyUsersPage extends StatefulWidget {
  final String destinationId;
  final String priorityGender;

  const NearbyUsersPage({
    super.key,
    required this.destinationId,
    required this.priorityGender,
  });

  @override
  State<NearbyUsersPage> createState() => _NearbyUsersPageState();
}

class _NearbyUsersPageState extends State<NearbyUsersPage> {
  StreamSubscription<Position>? positionStream;

  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String? myId;
  double? myLat;
  double? myLng;

  double? selectedDestLat;
  double? selectedDestLng;

  List<String> validDestinationIds = [];
  List<Map<String, dynamic>> nearbyUsers = [];

  bool hasNavigatedToGroup = false;

  @override
  void initState() {
    super.initState();
    initUser();
  }

  Future<void> initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    myId = (user.phoneNumber ?? "").replaceAll('+', '');

    await fetchDestinationAndNearbyLocations();

    startLocationTracking();
    listenForNearbyUsers();
    listenForIncomingRequests();
  }

  Future<void> fetchDestinationAndNearbyLocations() async {
    final doc = await firestore
        .collection("Locations")
        .doc(widget.destinationId)
        .get();

    selectedDestLat = doc["lat"];
    selectedDestLng = doc["long"];

    final allLocations =
        await firestore.collection("Locations").get();

    for (var location in allLocations.docs) {
      double lat = location["lat"];
      double lng = location["long"];

      double distance = calculateDistance(
        selectedDestLat!,
        selectedDestLng!,
        lat,
        lng,
      );

      if (distance <= 2000) {
        validDestinationIds.add(location.id);
      }
    }
  }

  Future<void> startLocationTracking() async {
    LocationPermission permission =
        await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      myLat = position.latitude;
      myLng = position.longitude;

      await dbRef.child("users/$myId").update({
        "lat": myLat,
        "long": myLng,
        "destinationId": widget.destinationId,
        "isActive": true,
      });

      setState(() {});
    });
  }

  void listenForNearbyUsers() {
    dbRef.child("users").onValue.listen((event) {
      if (myLat == null || myLng == null) return;

      final data = event.snapshot.value as Map?;
      if (data == null) return;

      List<Map<String, dynamic>> tempList = [];

      data.forEach((key, value) {
        if (key == myId) return;

        final user = Map<String, dynamic>.from(value);

        if (user["isActive"] == true &&
            user["lat"] != null &&
            user["long"] != null &&
            validDestinationIds.contains(user["destinationId"])) {

          if (widget.priorityGender != "No Preference") {
            if (user["gender"] != widget.priorityGender) {
              return;
            }
          }

          double distance = calculateDistance(
            myLat!,
            myLng!,
            user["lat"],
            user["long"],
          );

          if (distance <= 500) {
            tempList.add({
              "id": key,
              "distance": distance.toStringAsFixed(1),
            });
          }
        }
      });

      setState(() {
        nearbyUsers = tempList;
      });
    });
  }

  Future<void> sendRideRequest(String receiverId) async {
    String requestId = dbRef.child("rideRequests").push().key!;

    await dbRef.child("rideRequests/$requestId").set({
      "from": myId,
      "to": receiverId,
      "status": "pending",
      "createdAt": ServerValue.timestamp,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Request Sent")),
    );

    listenForRequestStatus(requestId);
  }

  void listenForRequestStatus(String requestId) {
    dbRef.child("rideRequests/$requestId").onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      if (data["status"] == "accepted" &&
          data["groupId"] != null &&
          !hasNavigatedToGroup) {

        hasNavigatedToGroup = true;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RideGroupScreen(groupId: data["groupId"]),
          ),
        );
      }
    });
  }

  void listenForIncomingRequests() {
    dbRef
        .child("rideRequests")
        .orderByChild("to")
        .equalTo(myId)
        .onChildAdded
        .listen((event) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      if (data["status"] == "pending") {
        showRequestDialog(event.snapshot.key!, data["from"]);
      }
    });
  }

  void showRequestDialog(String requestId, String senderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ride Request"),
          content: Text("$senderId is requesting to share ride"),
          actions: [
            TextButton(
              onPressed: () async {
                await dbRef
                    .child("rideRequests/$requestId")
                    .update({"status": "rejected"});
                Navigator.pop(context);
              },
              child: const Text("Reject"),
            ),
            ElevatedButton(
              onPressed: () async {
                await dbRef
                    .child("rideRequests/$requestId")
                    .update({"status": "accepted"});

                createRideGroup(senderId, requestId);
                Navigator.pop(context);
              },
              child: const Text("Accept"),
            ),
          ],
        );
      },
    );
  }

  Future<void> createRideGroup(
      String otherUserId, String requestId) async {

    String groupId = dbRef.child("rideGroups").push().key!;

    await dbRef.child("rideGroups/$groupId").set({
      "members": {
        myId!: true,
        otherUserId: true,
      },
      "createdAt": ServerValue.timestamp,
    });

    await dbRef.child("rideRequests/$requestId").update({
      "groupId": groupId,
    });

    if (!hasNavigatedToGroup) {
      hasNavigatedToGroup = true;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              RideGroupScreen(groupId: groupId),
        ),
      );
    }
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000;
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(deg) => deg * pi / 180;

  @override
  void dispose() {
    positionStream?.cancel();
    if (myId != null) {
      dbRef.child("users/$myId").update({"isActive": false});
    }
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        "Nearby Sharing Users",
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: primary,
      elevation: 0,
    ),
    body: nearbyUsers.isEmpty
        ? Center(
            child: Text(
              "No matching users",
              style: TextStyle(
                color: primary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: nearbyUsers.length,
            itemBuilder: (context, index) {
              final user = nearbyUsers[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: primary,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            "User: ${user["id"]}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Distance: ${user["distance"]} m",
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        sendRideRequest(user["id"]);
                      },
                      child: const Text(
                        "Request",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
  );
}
}