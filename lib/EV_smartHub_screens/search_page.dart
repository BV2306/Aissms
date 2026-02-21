import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lastmile_transport/home.dart'; // EVMapScreen
import 'payment_page.dart';

class EVSmartHubSearchPage extends StatefulWidget {
  const EVSmartHubSearchPage({super.key});

  @override
  State<EVSmartHubSearchPage> createState() =>
      _EVSmartHubSearchPageState();
}

class _EVSmartHubSearchPageState extends State<EVSmartHubSearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EV Hub Booking'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.route), text: 'Hub to Hub'),
            Tab(icon: Icon(Icons.pedal_bike), text: 'Rental'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HubToHubTab(),
          _RentalTab(),
        ],
      ),
    );
  }
}

// =========================================================
// TAB 1 — HUB TO HUB
// =========================================================

class _HubToHubTab extends StatefulWidget {
  const _HubToHubTab();

  @override
  State<_HubToHubTab> createState() => _HubToHubTabState();
}

class _HubToHubTabState extends State<_HubToHubTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? sourceLocality;
  String? sourceHub;
  String? destLocality;
  String? destHub;

  double distanceKm = 0;
  int estimatedMinutes = 0;
  int extraMinutes = 0;
  bool isCalculatingDistance = false;

  List<String> localities = [];
  List<String> sourceHubs = [];
  List<String> destHubs = [];

  Map<String, Map<String, double>> hubLocations = {};

  final DatabaseReference bicyclesRef =
      FirebaseDatabase.instance.ref("bicycles");

  static const String orsApiKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  @override
  void initState() {
    super.initState();
    _loadLocalities();
  }

  Future<void> _loadLocalities() async {
    final snap =
        await FirebaseFirestore.instance.collection("EV-Hubs").get();
    setState(() {
      localities = snap.docs.map((e) => e.id).toList();
    });
  }

  Future<void> _loadHubs(String locality, bool isSource) async {
    final snap = await FirebaseFirestore.instance
        .collection("EV-Hubs")
        .doc(locality)
        .collection("Hubs")
        .get();
    setState(() {
      if (isSource) {
        sourceHubs = snap.docs.map((e) => e.id).toList();
      } else {
        destHubs = snap.docs.map((e) => e.id).toList();
      }
    });
  }

  Future<Map<String, double>?> _getHubCoordinates(
      String locality, String hub) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("EV-Hubs")
          .doc(locality)
          .collection("Hubs")
          .doc(hub)
          .get();

      if (!doc.exists) return null;
      final data = doc.data();
      final location = data?["Up"] ?? data?["Down"];
      if (location == null) return null;

      final dynamic latVal = location["lat"];
      final dynamic lonVal =
          location["long"] ?? location["lon"] ?? location["lng"];

      double? lat = latVal is num ? latVal.toDouble() : double.tryParse(latVal.toString());
      double? lon = lonVal is num ? lonVal.toDouble() : double.tryParse(lonVal.toString());

      if (lat != null && lon != null) return {"lat": lat, "lon": lon};
    } catch (e) {
      debugPrint("Error getting hub coordinates: $e");
    }
    return null;
  }

  Future<void> _calculateDistanceAndPrice() async {
    if (sourceLocality == null ||
        sourceHub == null ||
        destLocality == null ||
        destHub == null) return;

    setState(() => isCalculatingDistance = true);

    try {
      final sourceCoords =
          await _getHubCoordinates(sourceLocality!, sourceHub!);
      final destCoords =
          await _getHubCoordinates(destLocality!, destHub!);

      if (sourceCoords == null || destCoords == null) {
        _showSnack("Could not find hub coordinates");
        setState(() => isCalculatingDistance = false);
        return;
      }

      hubLocations["source"] = sourceCoords;
      hubLocations["dest"] = destCoords;

      final response = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [sourceCoords["lon"], sourceCoords["lat"]],
            [destCoords["lon"], destCoords["lat"]],
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        num distanceMeters = _parseOrsDistance(data);

        if (distanceMeters <= 0) throw Exception('Unexpected ORS response');

        setState(() {
          distanceKm = distanceMeters / 1000;
          estimatedMinutes = (distanceKm * 10).ceil();
          isCalculatingDistance = false;
        });
      } else {
        throw Exception("ORS API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error calculating distance: $e");
      _showSnack("Error: ${e.toString()}");
      setState(() => isCalculatingDistance = false);
    }
  }

  num _parseOrsDistance(dynamic data) {
    if (data is Map) {
      if (data["routes"] is List && (data["routes"] as List).isNotEmpty) {
        final r0 = (data["routes"] as List)[0];
        if (r0 is Map && r0["summary"]?["distance"] != null) {
          return r0["summary"]["distance"] as num;
        }
      }
      if (data["features"] is List && (data["features"] as List).isNotEmpty) {
        final f0 = (data["features"] as List)[0];
        if (f0 is Map) {
          final props = f0["properties"] as Map?;
          if (props?["summary"]?["distance"] != null) {
            return props!["summary"]["distance"] as num;
          }
          if (props?["segments"] is List) {
            return (props!["segments"] as List).fold<num>(0, (s, seg) {
              if (seg is Map && seg["distance"] != null) {
                return s + (seg["distance"] as num);
              }
              return s;
            });
          }
        }
      }
    }
    return 0;
  }

  double get price {
    double base = distanceKm * 5;
    double extra = extraMinutes * 1.0;
    return base + extra;
  }

  Future<bool> _checkBicycleAvailability() async {
    if (sourceLocality == null || sourceHub == null) return false;
    final snapshot =
        await bicyclesRef.child(sourceLocality!).child(sourceHub!).get();
    if (!snapshot.exists || snapshot.value is! Map) return false;
    final bikes = Map<String, dynamic>.from(snapshot.value as Map);
    return bikes.values
        .any((bike) => bike is Map && bike["availability"] == "yes");
  }

  Future<void> _proceed() async {
    if (sourceLocality == null ||
        sourceHub == null ||
        destLocality == null ||
        destHub == null) {
      _showSnack("Please complete all selections");
      return;
    }
    if (distanceKm == 0) {
      _showSnack("Please wait for distance calculation");
      return;
    }

    final available = await _checkBicycleAvailability();
    if (!available) {
      _showSnack("No bicycles available at source hub");
      return;
    }

    final sourceCoords = hubLocations["source"];
    final destCoords = hubLocations["dest"];
    if (sourceCoords == null || destCoords == null) {
      _showSnack("Hub coordinates not available");
      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EVMapScreen(
          bookingData: {
            "bookingType": "hub_to_hub",
            "sourceLocality": sourceLocality,
            "sourceHub": sourceHub,
            "sourceLat": sourceCoords["lat"],
            "sourceLon": sourceCoords["lon"],
            "destLocality": destLocality,
            "destHub": destHub,
            "destLat": destCoords["lat"],
            "destLon": destCoords["lon"],
            "distanceKm": distanceKm,
            "estimatedMinutes": estimatedMinutes,
            "extraMinutes": extraMinutes,
            "price": price,
          },
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _sectionLabel("Source"),
          _localityDropdown(
            value: sourceLocality,
            onChanged: (v) {
              setState(() {
                sourceLocality = v;
                sourceHub = null;
                sourceHubs = [];
                distanceKm = 0;
              });
              _loadHubs(v!, true);
            },
          ),
          const SizedBox(height: 10),
          _hubDropdown(
            label: "Source Hub",
            value: sourceHub,
            hubs: sourceHubs,
            onChanged: (v) {
              setState(() {
                sourceHub = v;
                distanceKm = 0;
              });
              _calculateDistanceAndPrice();
            },
          ),
          const SizedBox(height: 20),
          _sectionLabel("Destination"),
          _localityDropdown(
            value: destLocality,
            onChanged: (v) {
              setState(() {
                destLocality = v;
                destHub = null;
                destHubs = [];
                distanceKm = 0;
              });
              _loadHubs(v!, false);
            },
          ),
          const SizedBox(height: 10),
          _hubDropdown(
            label: "Destination Hub",
            value: destHub,
            hubs: destHubs,
            onChanged: (v) {
              setState(() {
                destHub = v;
                distanceKm = 0;
              });
              _calculateDistanceAndPrice();
            },
          ),
          const SizedBox(height: 20),
          if (isCalculatingDistance)
            const _LoadingRow(label: "Calculating distance...")
          else if (distanceKm > 0)
            _TripSummaryCard(
              distanceKm: distanceKm,
              estimatedMinutes: estimatedMinutes,
              price: price,
            ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Extra minutes (optional)",
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              setState(() {
                extraMinutes = int.tryParse(v) ?? 0;
              });
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                (distanceKm > 0 && !isCalculatingDistance) ? _proceed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              "Proceed to Map",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF2563EB))),
      );

  Widget _localityDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
            labelText: "Select Locality", border: OutlineInputBorder()),
        items: localities
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      );

  Widget _hubDropdown({
    required String label,
    required String? value,
    required List<String> hubs,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items:
            hubs.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      );
}

// =========================================================
// TAB 2 — RENTAL
// =========================================================

class _RentalTab extends StatefulWidget {
  const _RentalTab();

  @override
  State<_RentalTab> createState() => _RentalTabState();
}

class _RentalTabState extends State<_RentalTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Source
  String? sourceLocality;
  String? sourceHub;

  // Same hub toggle
  bool sameHub = true;

  // Submission hub (when different)
  String? submissionLocality;
  String? submissionHub;

  // Time selection
  DateTime? scheduledDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // Calculated values
  double distanceKm = 0;
  int durationMinutes = 0;
  bool isCalculatingDistance = false;

  List<String> localities = [];
  List<String> sourceHubs = [];
  List<String> submissionHubs = [];

  Map<String, Map<String, double>> hubLocations = {};

  final DatabaseReference bicyclesRef =
      FirebaseDatabase.instance.ref("bicycles");

  static const String orsApiKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImFlYTdiMjdmM2NlNDY5NTAwYTM0YzNlZDdlYzI5MmM1YTkwMjhlMzQwNjI5OTQ4OTZmOTliZGQ3IiwiaCI6Im11cm11cjY0In0=";

  // Rental: ₹2/min base + ₹5/km if different hub
  static const double ratePerMinute = 2.0;

  @override
  void initState() {
    super.initState();
    _loadLocalities();
  }

  Future<void> _loadLocalities() async {
    final snap =
        await FirebaseFirestore.instance.collection("EV-Hubs").get();
    setState(() {
      localities = snap.docs.map((e) => e.id).toList();
    });
  }

  Future<void> _loadHubs(String locality, bool isSource) async {
    final snap = await FirebaseFirestore.instance
        .collection("EV-Hubs")
        .doc(locality)
        .collection("Hubs")
        .get();
    setState(() {
      if (isSource) {
        sourceHubs = snap.docs.map((e) => e.id).toList();
      } else {
        submissionHubs = snap.docs.map((e) => e.id).toList();
      }
    });
  }

  Future<Map<String, double>?> _getHubCoordinates(
      String locality, String hub) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("EV-Hubs")
          .doc(locality)
          .collection("Hubs")
          .doc(hub)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      final location = data?["Up"] ?? data?["Down"];
      if (location == null) return null;
      final dynamic latVal = location["lat"];
      final dynamic lonVal =
          location["long"] ?? location["lon"] ?? location["lng"];
      double? lat =
          latVal is num ? latVal.toDouble() : double.tryParse(latVal.toString());
      double? lon =
          lonVal is num ? lonVal.toDouble() : double.tryParse(lonVal.toString());
      if (lat != null && lon != null) return {"lat": lat, "lon": lon};
    } catch (e) {
      debugPrint("Error getting hub coordinates: $e");
    }
    return null;
  }

  Future<void> _calculateDistanceForDifferentHub() async {
    if (submissionLocality == null || submissionHub == null) return;
    if (sourceLocality == null || sourceHub == null) return;

    setState(() => isCalculatingDistance = true);

    try {
      final sourceCoords =
          await _getHubCoordinates(sourceLocality!, sourceHub!);
      final subCoords =
          await _getHubCoordinates(submissionLocality!, submissionHub!);

      if (sourceCoords == null || subCoords == null) {
        _showSnack("Could not find hub coordinates");
        setState(() => isCalculatingDistance = false);
        return;
      }

      hubLocations["source"] = sourceCoords;
      hubLocations["submission"] = subCoords;

      final response = await http.post(
        Uri.parse(
            "https://api.openrouteservice.org/v2/directions/driving-car/geojson"),
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "coordinates": [
            [sourceCoords["lon"], sourceCoords["lat"]],
            [subCoords["lon"], subCoords["lat"]],
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        num distanceMeters = _parseOrsDistance(data);
        setState(() {
          distanceKm = distanceMeters > 0 ? distanceMeters / 1000 : 0;
          isCalculatingDistance = false;
        });
      } else {
        throw Exception("ORS error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Distance calc error: $e");
      _showSnack("Error calculating distance: $e");
      setState(() => isCalculatingDistance = false);
    }
  }

  num _parseOrsDistance(dynamic data) {
    if (data is Map) {
      if (data["routes"] is List && (data["routes"] as List).isNotEmpty) {
        final r0 = (data["routes"] as List)[0];
        if (r0 is Map && r0["summary"]?["distance"] != null) {
          return r0["summary"]["distance"] as num;
        }
      }
      if (data["features"] is List && (data["features"] as List).isNotEmpty) {
        final f0 = (data["features"] as List)[0];
        if (f0 is Map) {
          final props = f0["properties"] as Map?;
          if (props?["summary"]?["distance"] != null) {
            return props!["summary"]["distance"] as num;
          }
          if (props?["segments"] is List) {
            return (props!["segments"] as List).fold<num>(0, (s, seg) {
              if (seg is Map && seg["distance"] != null) {
                return s + (seg["distance"] as num);
              }
              return s;
            });
          }
        }
      }
    }
    return 0;
  }

  /// Duration in minutes between startTime and endTime on scheduledDate
  int _calcDurationMinutes() {
    if (scheduledDate == null || startTime == null || endTime == null) return 0;

    final start = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      startTime!.hour,
      startTime!.minute,
    );
    var end = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      endTime!.hour,
      endTime!.minute,
    );

    // If end is before start (crosses midnight), add a day
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));

    final diff = end.difference(start).inMinutes;
    // Cap at 24 hours
    return diff.clamp(0, 1440);
  }

  double get rentalPrice {
    final mins = _calcDurationMinutes();
    final timeCost = mins * ratePerMinute;
    final distanceCost = sameHub ? 0.0 : distanceKm * 5.0;
    return timeCost + distanceCost;
  }

  bool get _canProceed {
    if (sourceLocality == null || sourceHub == null) return false;
    if (scheduledDate == null || startTime == null || endTime == null) return false;
    final dur = _calcDurationMinutes();
    if (dur <= 0) return false;
    if (!sameHub && (submissionLocality == null || submissionHub == null)) {
      return false;
    }
    if (!sameHub && isCalculatingDistance) return false;
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        scheduledDate = picked;
        durationMinutes = _calcDurationMinutes();
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
        durationMinutes = _calcDurationMinutes();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      final tentativeDur = _calcDurationMinutesWithEnd(picked);
      if (tentativeDur > 1440) {
        _showSnack("Maximum rental duration is 24 hours");
        return;
      }
      setState(() {
        endTime = picked;
        durationMinutes = _calcDurationMinutes();
      });
    }
  }

  int _calcDurationMinutesWithEnd(TimeOfDay end) {
    if (scheduledDate == null || startTime == null) return 0;
    final start = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      startTime!.hour,
      startTime!.minute,
    );
    var endDt = DateTime(
      scheduledDate!.year,
      scheduledDate!.month,
      scheduledDate!.day,
      end.hour,
      end.minute,
    );
    if (endDt.isBefore(start)) endDt = endDt.add(const Duration(days: 1));
    return endDt.difference(start).inMinutes.clamp(0, 1440);
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  String _formatTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<bool> _checkBicycleAvailability() async {
    if (sourceLocality == null || sourceHub == null) return false;
    final snapshot =
        await bicyclesRef.child(sourceLocality!).child(sourceHub!).get();
    if (!snapshot.exists || snapshot.value is! Map) return false;
    final bikes = Map<String, dynamic>.from(snapshot.value as Map);
    return bikes.values
        .any((bike) => bike is Map && bike["availability"] == "yes");
  }

  Future<void> _proceed() async {
    if (!_canProceed) return;

    final dur = _calcDurationMinutes();

    final available = await _checkBicycleAvailability();
    if (!available) {
      _showSnack("No bicycles available at source hub");
      return;
    }

    // Ensure source coords are cached for same-hub scenario
    if (sameHub || hubLocations["source"] == null) {
      final sc = await _getHubCoordinates(sourceLocality!, sourceHub!);
      if (sc != null) hubLocations["source"] = sc;
    }

    final sourceCoords = hubLocations["source"];
    final subCoords =
        sameHub ? hubLocations["source"] : hubLocations["submission"];

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          bookingData: {
            "bookingType": "rental",
            "sourceLocality": sourceLocality,
            "sourceHub": sourceHub,
            "sourceLat": sourceCoords?["lat"] ?? 0.0,
            "sourceLon": sourceCoords?["lon"] ?? 0.0,
            "submissionLocality":
                sameHub ? sourceLocality : submissionLocality,
            "submissionHub": sameHub ? sourceHub : submissionHub,
            "submissionLat": subCoords?["lat"] ?? 0.0,
            "submissionLon": subCoords?["lon"] ?? 0.0,
            "sameHub": sameHub,
            "scheduledDate": _formatDate(scheduledDate!),
            "startTime": _formatTime(startTime!),
            "endTime": _formatTime(endTime!),
            "durationMinutes": dur,
            "distanceKm": distanceKm,
            "price": rentalPrice,
          },
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dur = _calcDurationMinutes();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // ─── Pickup Hub ───────────────────────────────────
          _sectionLabel("Pickup Hub"),
          _localityDropdown(
            value: sourceLocality,
            label: "Pickup Locality",
            onChanged: (v) {
              setState(() {
                sourceLocality = v;
                sourceHub = null;
                sourceHubs = [];
              });
              _loadHubs(v!, true);
            },
          ),
          const SizedBox(height: 10),
          _hubDropdown(
            label: "Pickup Hub",
            value: sourceHub,
            hubs: sourceHubs,
            onChanged: (v) => setState(() => sourceHub = v),
          ),
          const SizedBox(height: 20),

          // ─── Return to same hub? ──────────────────────────
          Card(
            child: SwitchListTile(
              title: const Text("Return to the same hub"),
              subtitle: Text(
                sameHub
                    ? "Bicycle must be returned to the pickup hub"
                    : "Choose a different submission hub",
              ),
              value: sameHub,
              onChanged: (v) {
                setState(() {
                  sameHub = v;
                  if (v) {
                    submissionLocality = null;
                    submissionHub = null;
                    submissionHubs = [];
                    distanceKm = 0;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // ─── Submission Hub (if different) ────────────────
          if (!sameHub) ...[
            _sectionLabel("Submission Hub"),
            _localityDropdown(
              value: submissionLocality,
              label: "Submission Locality",
              onChanged: (v) {
                setState(() {
                  submissionLocality = v;
                  submissionHub = null;
                  submissionHubs = [];
                  distanceKm = 0;
                });
                _loadHubs(v!, false);
              },
            ),
            const SizedBox(height: 10),
            _hubDropdown(
              label: "Submission Hub",
              value: submissionHub,
              hubs: submissionHubs,
              onChanged: (v) {
                setState(() {
                  submissionHub = v;
                  distanceKm = 0;
                });
                _calculateDistanceForDifferentHub();
              },
            ),
            const SizedBox(height: 12),
            if (isCalculatingDistance)
              const _LoadingRow(label: "Calculating distance between hubs..."),
          ],

          // ─── Schedule ─────────────────────────────────────
          _sectionLabel("Schedule"),
          _dateTile(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _timeTile("Start Time", startTime, _pickStartTime)),
              const SizedBox(width: 10),
              Expanded(child: _timeTile("End Time", endTime, _pickEndTime)),
            ],
          ),
          const SizedBox(height: 8),
          if (startTime != null && endTime != null && dur > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "Duration: ${dur ~/ 60}h ${dur % 60}m"
                "${dur >= 1440 ? ' (max 24h)' : ''}",
                style: TextStyle(
                  color: dur >= 1440 ? Colors.orange : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // ─── Price Summary ────────────────────────────────
          if (dur > 0) ...[
            const SizedBox(height: 12),
            _RentalPriceSummary(
              durationMinutes: dur,
              distanceKm: sameHub ? 0 : distanceKm,
              totalPrice: rentalPrice,
              ratePerMinute: ratePerMinute,
              sameHub: sameHub,
            ),
          ],

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _canProceed ? _proceed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              "Proceed to Payment",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF2563EB))),
      );

  Widget _localityDropdown({
    required String? value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: localities
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      );

  Widget _hubDropdown({
    required String label,
    required String? value,
    required List<String> hubs,
    required ValueChanged<String?> onChanged,
  }) =>
      DropdownButtonFormField<String>(
        value: value,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items:
            hubs.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      );

  Widget _dateTile() => InkWell(
        onTap: _pickDate,
        child: InputDecorator(
          decoration: const InputDecoration(
              labelText: "Scheduled Date",
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today)),
          child: Text(
            scheduledDate != null
                ? _formatDate(scheduledDate!)
                : "Tap to select date",
            style: TextStyle(
              color: scheduledDate != null ? Colors.black : Colors.grey,
            ),
          ),
        ),
      );

  Widget _timeTile(
          String label, TimeOfDay? time, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.access_time)),
          child: Text(
            time != null ? _formatTime(time) : "Tap to select",
            style: TextStyle(
              color: time != null ? Colors.black : Colors.grey,
            ),
          ),
        ),
      );
}

// =========================================================
// SHARED WIDGETS
// =========================================================

class _LoadingRow extends StatelessWidget {
  final String label;
  const _LoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final double distanceKm;
  final int estimatedMinutes;
  final double price;

  const _TripSummaryCard({
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Trip Summary",
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _row(Icons.straighten, "Distance",
                "${distanceKm.toStringAsFixed(2)} km"),
            _row(Icons.timer, "Estimated Time", "$estimatedMinutes min"),
            _row(Icons.currency_rupee, "Estimated Price",
                "₹${price.toStringAsFixed(2)}"),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text("$label: ",
                style: const TextStyle(color: Colors.grey)),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _RentalPriceSummary extends StatelessWidget {
  final int durationMinutes;
  final double distanceKm;
  final double totalPrice;
  final double ratePerMinute;
  final bool sameHub;

  const _RentalPriceSummary({
    required this.durationMinutes,
    required this.distanceKm,
    required this.totalPrice,
    required this.ratePerMinute,
    required this.sameHub,
  });

  @override
  Widget build(BuildContext context) {
    final timeCost = durationMinutes * ratePerMinute;
    final distCost = sameHub ? 0.0 : distanceKm * 5.0;

    return Card(
      elevation: 2,
      color: const Color(0xFFF0F7FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rental Price Breakdown",
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            _row("Time charge",
                "${durationMinutes ~/ 60}h ${durationMinutes % 60}m × ₹${ratePerMinute.toStringAsFixed(0)}/min",
                "₹${timeCost.toStringAsFixed(2)}"),
            if (!sameHub)
              _row("Drop-off distance",
                  "${distanceKm.toStringAsFixed(2)} km × ₹5/km",
                  "₹${distCost.toStringAsFixed(2)}"),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text("₹${totalPrice.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2563EB))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String subtitle, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}