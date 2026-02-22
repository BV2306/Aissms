import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lastmile_transport/Paid_Lift/Driver/ride_matching.dart';
import 'seeker_location_service.dart';
import 'seeker_matched_drivers_sheet.dart';

class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  static const String _apiKey = "AIzaSyCzzyDtUQMFsybFHN7AXe_0fCZvjrILnPE";

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final SeekerLocationService _locationService = SeekerLocationService();

  // ── FIX: Declare as late — initialized in initState with _uid ─────────────
  late final RideMatchingService _matchingService;

  // ── Route inputs ──────────────────────────────────────────────────────────
  final TextEditingController _sourceCtrl = TextEditingController();
  final TextEditingController _destCtrl = TextEditingController();
  LatLng? _seekerSource;
  LatLng? _seekerDest;
  String _seekerSourceName = "";
  String _seekerDestName = "";

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isActive = false;
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _matchedRides = [];
  bool _goingActive = false;

  StreamSubscription<DatabaseEvent>? _locationSub;
  StreamSubscription<DatabaseEvent>? _matchesSub;

  // ── Init / Dispose ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      // ── FIX: RideMatchingService is the new class with setSeekerRoute ──
      _matchingService = RideMatchingService(seekerId: _uid!);
      _listenToMyLocation();
      _listenToMatches();
    }
  }

  @override
  void dispose() {
    if (_uid != null) {
      _locationService.stopTracking(_uid!);
      _matchingService.stopMatching();
    }
    _locationSub?.cancel();
    _matchesSub?.cancel();
    _sourceCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  // ── Firebase listeners ────────────────────────────────────────────────────

  void _listenToMyLocation() {
    _locationSub = FirebaseDatabase.instance
        .ref("seekers/$_uid")
        .onValue
        .listen((event) {
      if (!event.snapshot.exists || !mounted) return;
      final d = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      LatLng? loc;
      if (d['location'] != null) {
        loc = LatLng(
          (d['location']['lat'] as num).toDouble(),
          (d['location']['lng'] as num).toDouble(),
        );
      }
      setState(() {
        _isActive = d['isActive'] ?? false;
        _currentLocation = loc;
      });
    });
  }

  void _listenToMatches() {
    _matchesSub = FirebaseDatabase.instance
        .ref("seekerMatches/$_uid")
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (!event.snapshot.exists) {
        setState(() => _matchedRides = []);
        return;
      }
      final data =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final rides = data.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((r) => r['status'] == 'pending')
          .toList();
      setState(() => _matchedRides = rides);
    });
  }

  // ── Places autocomplete ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _searchPlaces(String query) async {
    if (query.length < 2) return [];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json'
      '?query=${Uri.encodeComponent(query)}&key=$_apiKey',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final d = json.decode(res.body) as Map<String, dynamic>;
        if (d['status'] == 'OK') {
          return (d['results'] as List)
              .map<Map<String, dynamic>>((p) => {
                    'name': p['name'],
                    'address': p['formatted_address'],
                    'lat': p['geometry']['location']['lat'],
                    'lng': p['geometry']['location']['lng'],
                  })
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // ── Active toggle ─────────────────────────────────────────────────────────

  Future<void> _goActive() async {
    if (_uid == null) return;

    if (_seekerSource == null || _seekerDest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your pickup and drop-off first"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _goingActive = true);

    try {
      await _locationService.startTracking(_uid!);

      // ── FIX: This now correctly calls the new setSeekerRoute method ───
      _matchingService.setSeekerRoute(
        source: _seekerSource!,
        destination: _seekerDest!,
        sourceName: _seekerSourceName,
        destName: _seekerDestName,
      );

      _matchingService.startMatching();

      setState(() => _isActive = true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _goingActive = false);
    }
  }

  Future<void> _goInactive() async {
    if (_uid == null) return;
    await _locationService.stopTracking(_uid!);
    _matchingService.stopMatching();
    setState(() {
      _isActive = false;
      _matchedRides = [];
    });
  }

  // ── Send ride request ─────────────────────────────────────────────────────

  /// The matching service already auto-wrote the request.
  /// This method is called when the seeker manually confirms from the sheet
  /// — it just updates the timestamp to signal fresh intent.
  Future<void> _sendRideRequest(String driverId, String rideId) async {
    if (_uid == null || _seekerSource == null || _seekerDest == null) return;

    // Fetch the meeting/drop points already computed by the matching service
    final matchSnap = await FirebaseDatabase.instance
        .ref("seekerMatches/$_uid/$rideId")
        .get();

    Map<dynamic, dynamic> matchData = {};
    if (matchSnap.exists) {
      matchData =
          Map<dynamic, dynamic>.from(matchSnap.value as Map);
    }

    // Re-write with fresh timestamp — driver listener uses onValue so it
    // will re-fire, but _shownDialogs prevents a duplicate dialog.
    await FirebaseDatabase.instance
        .ref("rideRequests/$rideId/$_uid")
        .update({
      "seekerId": _uid,
      "seekerSourceName": _seekerSourceName,
      "seekerDestName": _seekerDestName,
      "seekerSourceLat": _seekerSource!.latitude,
      "seekerSourceLng": _seekerSource!.longitude,
      "seekerDestLat": _seekerDest!.latitude,
      "seekerDestLng": _seekerDest!.longitude,
      "meetingPointLat": matchData['meetingPointLat'],
      "meetingPointLng": matchData['meetingPointLng'],
      "dropPointLat": matchData['dropPointLat'],
      "dropPointLng": matchData['dropPointLng'],
      "status": "pending",
      "updatedAt": ServerValue.timestamp,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✓ Request sent — waiting for driver to accept"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void _showMatchedDrivers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SeekerMatchedDriversSheet(
        drivers: _matchedRides,
        onSendRequest: _sendRideRequest,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find a Ride"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Route card ─────────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.route, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      const Text(
                        "Your Journey",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _PlaceField(
                      controller: _sourceCtrl,
                      label: "Pickup Location",
                      icon: Icons.trip_origin,
                      iconColor: Colors.green,
                      enabled: !_isActive,
                      onSearch: _searchPlaces,
                      onSelected: (s) => setState(() {
                        _seekerSourceName = s['name'];
                        _seekerSource =
                            LatLng(s['lat'], s['lng']);
                        _sourceCtrl.text = s['name'];
                      }),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Column(
                        children: List.generate(
                          3,
                          (_) => Container(
                            width: 2,
                            height: 4,
                            margin:
                                const EdgeInsets.symmetric(vertical: 1),
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _PlaceField(
                      controller: _destCtrl,
                      label: "Drop-off Location",
                      icon: Icons.location_on,
                      iconColor: Colors.red,
                      enabled: !_isActive,
                      onSearch: _searchPlaces,
                      onSelected: (s) => setState(() {
                        _seekerDestName = s['name'];
                        _seekerDest = LatLng(s['lat'], s['lng']);
                        _destCtrl.text = s['name'];
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Status pulse ───────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _isActive ? Colors.green : Colors.grey.shade300,
                boxShadow: _isActive
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 6,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                _isActive
                    ? Icons.wifi_tethering
                    : Icons.wifi_tethering_off,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isActive ? "You're Active" : "You're Offline",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isActive ? Colors.green : Colors.grey,
              ),
            ),
            if (_currentLocation != null) ...[
              const SizedBox(height: 4),
              Text(
                "📍 ${_currentLocation!.latitude.toStringAsFixed(5)}, "
                "${_currentLocation!.longitude.toStringAsFixed(5)}",
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),

            // ── Toggle button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goingActive
                    ? null
                    : (_isActive ? _goInactive : _goActive),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor:
                      _isActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _goingActive
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isActive ? "GO OFFLINE" : "GO ACTIVE",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Matched drivers section ────────────────────────────────
            if (_isActive && _matchedRides.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Searching for drivers on your route...",
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_matchedRides.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showMatchedDrivers,
                  icon: const Icon(Icons.directions_car),
                  label: Text(
                      "${_matchedRides.length} Driver(s) Found Near Your Route"),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...(_matchedRides
                  .take(3)
                  .map((ride) => _MatchPreviewCard(
                        ride: ride,
                        onTap: _showMatchedDrivers,
                      ))),
              if (_matchedRides.length > 3)
                TextButton(
                  onPressed: _showMatchedDrivers,
                  child: Text(
                      "View all ${_matchedRides.length} drivers →"),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reusable place field ──────────────────────────────────────────────────────

class _PlaceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool enabled;
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;
  final void Function(Map<String, dynamic>) onSelected;

  const _PlaceField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onSearch,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Map<String, dynamic>>(
      controller: controller,
      suggestionsCallback: onSearch,
      builder: (ctx, ctrl, focusNode) => TextField(
        controller: ctrl,
        focusNode: focusNode,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          prefixIcon: Icon(icon, color: iconColor),
          filled: !enabled,
          fillColor: Colors.grey.shade100,
        ),
      ),
      itemBuilder: (ctx, s) => ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor, size: 18),
        title: Text(s['name'],
            style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          s['address'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
      onSelected: onSelected,
    );
  }
}

// ── Inline preview card ───────────────────────────────────────────────────────

class _MatchPreviewCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onTap;

  const _MatchPreviewCard(
      {required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade800,
          child: const Icon(Icons.directions_car,
              color: Colors.white, size: 18),
        ),
        title: Text(
          "${ride['sourceName'] ?? '?'} → "
          "${ride['destinationName'] ?? '?'}",
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.handshake,
                size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              "Board: "
              "${(ride['meetingPointLat'] as num?)?.toStringAsFixed(4) ?? '?'}, "
              "${(ride['meetingPointLng'] as num?)?.toStringAsFixed(4) ?? '?'}",
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}