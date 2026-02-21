// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:sliding_up_panel/sliding_up_panel.dart';
// import 'EV_smartHub_screens/payment_page.dart';

// class BookingMapScreen extends StatefulWidget {
//   final Map<String, dynamic> bookingData;

//   const BookingMapScreen({super.key, required this.bookingData});

//   @override
//   State<BookingMapScreen> createState() => _BookingMapScreenState();
// }

// class _BookingMapScreenState extends State<BookingMapScreen> {
//   GoogleMapController? mapController;
//   Position? currentPosition;

//   Set<Marker> userMarkers = {};
//   Set<Marker> hubMarkers = {};
//   Set<Polyline> polylines = {};

//   static const String orsApiKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }

//   Future<void> _init() async {
//     await _handleLocationPermission();
//     currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
//     _createUserMarker();
//     _createHubMarkers();
//     await _drawBookingRoutes();
//     setState(() {});
//   }

//   Future<void> _handleLocationPermission() async {
//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.deniedForever) throw Exception('Location permissions permanently denied');
//   }

//   void _createUserMarker() {
//     if (currentPosition == null) return;
//     userMarkers.clear();
//     userMarkers.add(
//       Marker(
//         markerId: const MarkerId('user'),
//         position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
//       ),
//     );
//   }

//   void _createHubMarkers() {
//     final data = widget.bookingData;
//     final sourceLat = data['sourceLat'] as double;
//     final sourceLon = data['sourceLon'] as double;
//     final destLat = data['destLat'] as double;
//     final destLon = data['destLon'] as double;

//     hubMarkers.clear();
//     hubMarkers.add(
//       Marker(
//         markerId: const MarkerId('source_hub'),
//         position: LatLng(sourceLat, sourceLon),
//         infoWindow: InfoWindow(title: data['sourceHub']),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//       ),
//     );
//     hubMarkers.add(
//       Marker(
//         markerId: const MarkerId('dest_hub'),
//         position: LatLng(destLat, destLon),
//         infoWindow: InfoWindow(title: data['destHub']),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//       ),
//     );
//   }

//   Future<void> _drawBookingRoutes() async {
//     if (currentPosition == null) return;

//     final sourceLat = widget.bookingData['sourceLat'] as double;
//     final sourceLon = widget.bookingData['sourceLon'] as double;
//     final destLat = widget.bookingData['destLat'] as double;
//     final destLon = widget.bookingData['destLon'] as double;

//     try {
//       final resp1 = await http.post(
//         Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
//         headers: {'Authorization': orsApiKey, 'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'coordinates': [
//             [currentPosition!.longitude, currentPosition!.latitude],
//             [sourceLon, sourceLat]
//           ]
//         }),
//       );

//       final resp2 = await http.post(
//         Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
//         headers: {'Authorization': orsApiKey, 'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'coordinates': [
//             [sourceLon, sourceLat],
//             [destLon, destLat]
//           ]
//         }),
//       );

//       if (resp1.statusCode == 200 && resp2.statusCode == 200) {
//         final d1 = jsonDecode(resp1.body);
//         final g1 = d1['features'][0]['geometry']['coordinates'];
//         final route1 = (g1 as List).map<LatLng>((p) => LatLng(p[1], p[0])).toList();

//         final d2 = jsonDecode(resp2.body);
//         final g2 = d2['features'][0]['geometry']['coordinates'];
//         final route2 = (g2 as List).map<LatLng>((p) => LatLng(p[1], p[0])).toList();

//         polylines.clear();
//         polylines.add(
//           Polyline(polylineId: const PolylineId('user_to_source'), points: route1, width: 5, color: Colors.blue),
//         );
//         polylines.add(
//           Polyline(polylineId: const PolylineId('source_to_dest'), points: route2, width: 5, color: Colors.purple),
//         );

//         if (mapController != null) {
//           final all = [...route1, ...route2];
//           final bounds = _getLatLngBounds(all);
//           await Future.delayed(const Duration(milliseconds: 300));
//           mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
//         }

//         setState(() {});
//       }
//     } catch (e) {
//       print('Error drawing booking routes: $e');
//       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
//     }
//   }

//   LatLngBounds _getLatLngBounds(List<LatLng> points) {
//     double minLat = points[0].latitude, maxLat = points[0].latitude;
//     double minLng = points[0].longitude, maxLng = points[0].longitude;
//     for (var p in points) {
//       minLat = min(minLat, p.latitude);
//       maxLat = max(maxLat, p.latitude);
//       minLng = min(minLng, p.longitude);
//       maxLng = max(maxLng, p.longitude);
//     }
//     return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (currentPosition == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

//     final bd = widget.bookingData;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Booking Map')),
//       body: SlidingUpPanel(
//         minHeight: 200,
//         maxHeight: 480,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
//         panel: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
//           child: Column(
//             children: [
//               const Icon(Icons.drag_handle),
//               const SizedBox(height: 12),
//               const Text(
//                 'Booking Summary',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),
//               Expanded(
//                 child: ListView(
//                   shrinkWrap: true,
//                   children: [
//                     Card(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       child: ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.location_on, color: Colors.blue, size: 20),
//                         title: const Text('From', style: TextStyle(fontSize: 13)),
//                         subtitle: Text(
//                           bd['sourceHub'] ?? 'Unknown',
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       ),
//                     ),
//                     Card(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       child: ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.location_on, color: Colors.red, size: 20),
//                         title: const Text('To', style: TextStyle(fontSize: 13)),
//                         subtitle: Text(
//                           bd['destHub'] ?? 'Unknown',
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       ),
//                     ),
//                     Card(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       child: ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.straighten, color: Colors.green, size: 20),
//                         title: const Text('Distance', style: TextStyle(fontSize: 13)),
//                         subtitle: Text(
//                           '${bd['distanceKm'].toStringAsFixed(2)} km',
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       ),
//                     ),
//                     Card(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       child: ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.timer, color: Colors.orange, size: 20),
//                         title: const Text('Est. Time', style: TextStyle(fontSize: 13)),
//                         subtitle: Text(
//                           '${bd['estimatedMinutes']} minutes',
//                           style: const TextStyle(fontSize: 12),
//                         ),
//                       ),
//                     ),
//                     Card(
//                       margin: const EdgeInsets.symmetric(vertical: 6),
//                       child: ListTile(
//                         dense: true,
//                         leading: const Icon(Icons.currency_rupee, color: Colors.purple, size: 20),
//                         title: const Text('Total Price', style: TextStyle(fontSize: 13)),
//                         subtitle: Text(
//                           '₹${bd['price'].toStringAsFixed(2)}',
//                           style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(bookingData: bd))),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 12),
//                     backgroundColor: Colors.green,
//                   ),
//                   child: const Text(
//                     'Proceed to Payment',
//                     style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         body: GoogleMap(
//           initialCameraPosition: CameraPosition(target: LatLng(currentPosition!.latitude, currentPosition!.longitude), zoom: 13),
//           myLocationEnabled: true,
//           markers: {...userMarkers, ...hubMarkers},
//           polylines: polylines,
//           onMapCreated: (c) => mapController = c,
//         ),
//       ),
//     );
//   }
// }
