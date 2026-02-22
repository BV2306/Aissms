// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:geolocator/geolocator.dart';
// import '../Paid_Lift/Driver/driver_route_service.dart';
// import '../Paid_Lift/Driver/matched_seekers_sheet.dart';
// import '../Paid_Lift/Driver/driver_seeker_live_map.dart';

// class DriverRouteScreen extends StatefulWidget {
//   final LatLng source;
//   final LatLng destination;
//   final String sourceName;
//   final String destinationName;

//   const DriverRouteScreen({
//     super.key,
//     required this.source,
//     required this.destination,
//     required this.sourceName,
//     required this.destinationName,
//   });

//   @override
//   State<DriverRouteScreen> createState() => _DriverRouteScreenState();
// }

// class _DriverRouteScreenState extends State<DriverRouteScreen> {
//   List<LatLng> routePoints = [];
//   bool isLoading = true;
//   String? errorMessage;
//   int pendingRequestCount = 0;
//   late Stream<QuerySnapshot> _requestStream;

//   @override
//   void initState() {
//     super.initState();
//     _fetchAndStoreRoute();
//     _listenForRequests();
//   }

//   Future<void> _fetchAndStoreRoute() async {
//     try {
//       final points = await DriverRouteService.fetchAndStoreRoute(
//         source: widget.source,
//         destination: widget.destination,
//         sourceName: widget.sourceName,
//         destinationName: widget.destinationName,
//       );
//       setState(() {
//         routePoints = points;
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         errorMessage = e.toString();
//         isLoading = false;
//       });
//     }
//   }

//   void _listenForRequests() {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;

//     _requestStream = FirebaseFirestore.instance
//         .collection('rideRequests')
//         .where('driverId', isEqualTo: uid)
//         .where('status', isEqualTo: 'pending')
//         .snapshots();

//     _requestStream.listen((snapshot) {
//       if (mounted) {
//         setState(() => pendingRequestCount = snapshot.docs.length);
//       }
//     });
//   }

//   double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
//     return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
//   }

//   Future<void> _acceptRequest(String seekerUid) async {
//     final driverUid = FirebaseAuth.instance.currentUser?.uid;
//     if (driverUid == null) return;

//     await FirebaseFirestore.instance
//         .collection('rideRequests')
//         .doc(seekerUid)
//         .update({
//       "status": "accepted",
//       "driverId": driverUid,
//       "acceptedAt": FieldValue.serverTimestamp(),
//     });

//     // Navigate to live map with seeker
//     if (mounted) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => DriverSeekerLiveMap(seekerUid: seekerUid),
//         ),
//       );
//     }

//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Ride Accepted!")),
//     );
//   }

//   Future<void> _checkForRequests() async {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;

//     final routeSnapshot = await FirebaseFirestore.instance
//         .collection("activeDrivers")
//         .doc(uid)
//         .get();

//     if (!routeSnapshot.exists) return;

//     final routeData = routeSnapshot.data()?['route'] as List<dynamic>?;
//     if (routeData == null || routeData.isEmpty) return;

//     final seekersSnapshot = await FirebaseDatabase.instance.ref("seekers").get();
//     List<Map<String, dynamic>> matchedSeekers = [];

//     if (seekersSnapshot.exists) {
//       final seekers = Map<dynamic, dynamic>.from(seekersSnapshot.value as Map);

//       seekers.forEach((key, value) {
//         final seekerLat = value['location']['lat'];
//         final seekerLng = value['location']['lng'];

//         for (var point in routeData) {
//           final distance = _calculateDistance(
//             seekerLat, seekerLng,
//             point['lat'], point['lng'],
//           );
//           if (distance <= 500) {
//             matchedSeekers.add({
//               "uid": key,
//               "lat": seekerLat,
//               "lng": seekerLng,
//               "name": value['name'] ?? "Seeker",
//             });
//             break;
//           }
//         }
//       });
//     }

//     if (matchedSeekers.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("No seekers within 500m of your route")),
//       );
//       return;
//     }

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => MatchedSeekersSheet(
//         seekers: matchedSeekers,
//         onAccept: _acceptRequest,
//       ),
//     );
//   }

//   Future<void> _checkPendingRequests() async {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return;

//     final snapshot = await FirebaseFirestore.instance
//         .collection('rideRequests')
//         .where('driverId', isEqualTo: uid)
//         .where('status', isEqualTo: 'pending')
//         .get();

//     if (snapshot.docs.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("No pending requests")),
//       );
//       return;
//     }

//     final requests = snapshot.docs.map((doc) {
//       final data = doc.data();
//       return {
//         "uid": data['seekerId'] ?? doc.id,
//         "name": data['seekerName'] ?? "Seeker",
//         "lat": data['seekerLat'] ?? 0.0,
//         "lng": data['seekerLng'] ?? 0.0,
//       };
//     }).toList();

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => MatchedSeekersSheet(
//         seekers: requests,
//         onAccept: _acceptRequest,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Driver Route"),
//         actions: [
//           if (pendingRequestCount > 0)
//             Stack(
//               alignment: Alignment.center,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.notifications),
//                   onPressed: _checkPendingRequests,
//                 ),
//                 Positioned(
//                   top: 8, right: 8,
//                   child: Container(
//                     padding: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(
//                       color: Colors.red,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Text(
//                       '$pendingRequestCount',
//                       style: const TextStyle(color: Colors.white, fontSize: 10),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//         ],
//       ),
//       body: isLoading
//           ? const Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(),
//                   SizedBox(height: 16),
//                   Text("Fetching route and saving your ride..."),
//                 ],
//               ),
//             )
//           : errorMessage != null
//               ? Center(child: Text("Error: $errorMessage"))
//               : Column(
//                   children: [
//                     // Route info banner
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       color: Colors.green.shade50,
//                       child: Row(
//                         children: [
//                           const Icon(Icons.check_circle, color: Colors.green),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               "Route saved: ${widget.sourceName} → ${widget.destinationName}",
//                               style: const TextStyle(fontWeight: FontWeight.w500),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Expanded(
//                       child: FlutterMap(
//                         options: MapOptions(
//                           initialCenter: widget.source,
//                           initialZoom: 13,
//                         ),
//                         children: [
//                           TileLayer(
//                             urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
//                             userAgentPackageName: "com.example.lastmile_transport",
//                           ),
//                           PolylineLayer(polylines: [
//                             Polyline(
//                               points: routePoints,
//                               strokeWidth: 5,
//                               color: Colors.blue,
//                             ),
//                           ]),
//                           MarkerLayer(markers: [
//                             Marker(
//                               point: widget.source,
//                               width: 50, height: 50,
//                               child: const Icon(Icons.location_on, color: Colors.green, size: 40),
//                             ),
//                             Marker(
//                               point: widget.destination,
//                               width: 50, height: 50,
//                               child: const Icon(Icons.location_on, color: Colors.red, size: 40),
//                             ),
//                           ]),
//                         ],
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: _checkForRequests,
//                               icon: const Icon(Icons.radar),
//                               label: const Text("FIND SEEKERS"),
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(vertical: 14),
//                                 backgroundColor: Colors.black87,
//                                 foregroundColor: Colors.white,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: _checkPendingRequests,
//                               icon: const Icon(Icons.inbox),
//                               label: Text(
//                                 pendingRequestCount > 0
//                                     ? "REQUESTS ($pendingRequestCount)"
//                                     : "CHECK REQUESTS",
//                               ),
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(vertical: 14),
//                                 backgroundColor: pendingRequestCount > 0
//                                     ? Colors.orange
//                                     : Colors.grey.shade700,
//                                 foregroundColor: Colors.white,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                   ],
//                 ),
//     );
//   }
// }