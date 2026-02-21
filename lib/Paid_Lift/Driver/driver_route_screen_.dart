import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastmile_transport/Paid_Lift/Driver/driver_seeker_live_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_route_service.dart';


class DriverRouteScreen extends StatefulWidget {
  final LatLng source;
  final LatLng destination;
  final String sourceName;
  final String destinationName;

  const DriverRouteScreen({
    super.key,
    required this.source,
    required this.destination,
    required this.sourceName,
    required this.destinationName,
  });

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  String? rideId;
  List<LatLng> routePoints = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _startRide();
  }

  Future<void> _startRide() async {
    final result = await DriverRouteService.createActiveRide(
      source: widget.source,
      destination: widget.destination,
      sourceName: widget.sourceName,
      destinationName: widget.destinationName,
    );

    rideId = result.$1;
    routePoints = result.$2;

    _broadcastDriverLocation();
    _listenForRequests();

    setState(() => loading = false);
  }

  void _broadcastDriverLocation() {
    final driverId = FirebaseAuth.instance.currentUser!.uid;

    Geolocator.getPositionStream().listen((pos) {
      FirebaseDatabase.instance.ref("drivers/$driverId").set({
        "lat": pos.latitude,
        "lng": pos.longitude,
        "rideId": rideId,
        "status": "online",
      });
    });
  }

  void _listenForRequests() {
    FirebaseDatabase.instance
        .ref("rideRequests/$rideId")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) return;

      final requests =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      requests.forEach((seekerUid, data) {
        if (data["status"] == "pending") {
          _showAcceptDialog(seekerUid);
        }
      });
    });
  }

  void _showAcceptDialog(String seekerUid) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Ride Request"),
        content: Text("Seeker: $seekerUid"),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseDatabase.instance
                  .ref("rideRequests/$rideId/$seekerUid")
                  .update({"status": "accepted"});

              await FirebaseDatabase.instance
                  .ref("ongoingRides/$rideId")
                  .set({
                "driverId": FirebaseAuth.instance.currentUser!.uid,
                "seekerUid": seekerUid,
                "status": "ongoing"
              });

              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DriverLiveMap(rideId: rideId!, seekerUid: seekerUid),
                ),
              );
            },
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Driver Active Ride")),
      body: FlutterMap(
        options: MapOptions(initialCenter: widget.source, initialZoom: 13),
        children: [
          TileLayer(
              urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
          PolylineLayer(
            polylines: [
              Polyline(points: routePoints, strokeWidth: 5),
            ],
          ),
        ],
      ),
    );
  }
}