import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';
import 'seeker_location_service.dart';
import '../Driver/ride_matching.dart';


class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final SeekerLocationService _locationService = SeekerLocationService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late final DatabaseReference _dbRef;
  late final DatabaseReference _ridesRef;

  bool isActive = false;
  LatLng? currentLocation;

  /// List of matched rides for this seeker
  List<Map<String, dynamic>> matchedRides = [];

  StreamSubscription<DatabaseEvent>? _rideSub;

  /// Ride matching service
  late final RideMatchingService _matchingService;

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _dbRef = FirebaseDatabase.instance.ref("seekers/$_uid");
      _ridesRef = FirebaseDatabase.instance.ref("rideDrivers/$_uid");

      _matchingService = RideMatchingService(seekerId: _uid!);

      _listenToMyLocation();
      _listenToMatchedRides();
    }
  }

  /// Listen to seeker location changes
  void _listenToMyLocation() {
    _dbRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final isActiveValue = data["isActive"] ?? false;

      LatLng? loc;
      if (data["location"] != null) {
        loc = LatLng(
          (data["location"]["lat"] as num).toDouble(),
          (data["location"]["lng"] as num).toDouble(),
        );
      }

      if (mounted) {
        setState(() {
          isActive = isActiveValue;
          currentLocation = loc;
        });
      }
    });
  }

  /// Listen to rideDrivers collection for matched rides
  void _listenToMatchedRides() {
    _rideSub = _ridesRef.onValue.listen((event) {
      if (!event.snapshot.exists) {
        setState(() => matchedRides = []);
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      List<Map<String, dynamic>> rides = [];

      data.forEach((key, value) {
        final ride = Map<String, dynamic>.from(value);
        rides.add(ride);
      });

      setState(() => matchedRides = rides);
    });
  }

  /// Activate seeker: start tracking & matching
  Future<void> _goActive() async {
    if (_uid == null) return;
    await _locationService.startTracking(_uid!);

    // Start automatic ride matching
    _matchingService.startMatching();

    setState(() {
      isActive = true;
    });
  }

  /// Deactivate seeker: stop tracking & matching
  Future<void> _goInactive() async {
    if (_uid == null) return;
    await _locationService.stopTracking(_uid!);

    // Stop ride matching
    _matchingService.stopMatching();

    setState(() {
      isActive = false;
    });
  }

  /// Send ride request manually (optional)
  Future<void> _sendRideRequest(String rideId, String driverId) async {
    if (_uid == null) return;

    final requestRef = FirebaseDatabase.instance
        .ref("rideRequests/$rideId/${_uid!}");

    await requestRef.set({
      "seekerId": _uid,
      "driverId": driverId,
      "status": "pending",
      "createdAt": ServerValue.timestamp,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride request sent")),
    );
  }

  @override
  void dispose() {
    if (_uid != null) {
      _locationService.stopTracking(_uid!);
      _matchingService.stopMatching();
    }
    _rideSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seeker Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// Current status
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.green : Colors.grey.shade300,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                isActive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? "You're Active" : "You're Offline",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.green : Colors.grey),
            ),
            if (currentLocation != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "📍 ${currentLocation!.latitude.toStringAsFixed(5)}, "
                  "${currentLocation!.longitude.toStringAsFixed(5)}",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),

            /// Button to toggle active/inactive
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActive ? _goInactive : _goActive,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isActive ? "GO OFFLINE" : "GO ACTIVE",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            /// Matched Rides List
            Expanded(
              child: matchedRides.isEmpty
                  ? const Center(child: Text("No rides nearby"))
                  : ListView.builder(
                      itemCount: matchedRides.length,
                      itemBuilder: (context, index) {
                        final ride = matchedRides[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(
                                "${ride['sourceName']} → ${ride['destinationName']}"),
                            subtitle: Text("Driver: ${ride['driverId']}"),
                            trailing: ElevatedButton(
                              onPressed: () => _sendRideRequest(
                                  ride['rideId'], ride['driverId']),
                              child: const Text("Request"),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}