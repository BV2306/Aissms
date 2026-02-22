import 'package:flutter/material.dart';

/// Bottom sheet displayed when [SeekerDashboard] finds matching driver rides.
///
/// Each card shows:
///   • Driver's route (source → destination)
///   • Calculated meeting point (where seeker boards)
///   • Calculated drop point (where seeker exits)
///   • "Send Request" button → notifies the driver
///
/// The sheet does NOT accept anything on behalf of the seeker.
/// Acceptance is always done by the driver in [DriverRouteScreen].
class SeekerMatchedDriversSheet extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;

  /// Called with (driverId, rideId) when seeker taps "Send Request".
  final Future<void> Function(String driverId, String rideId) onSendRequest;

  const SeekerMatchedDriversSheet({
    super.key,
    required this.drivers,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle bar ─────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue.shade800),
              const SizedBox(width: 10),
              Text(
                "${drivers.length} Driver${drivers.length == 1 ? '' : 's'} Found",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "These drivers have active routes that match your journey.\n"
            "Send a request — the driver will accept or decline.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // ── Driver list ─────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: drivers.length,
              itemBuilder: (ctx, i) => _DriverCard(
                driver: drivers[i],
                onSendRequest: () async {
                  Navigator.pop(context);
                  await onSendRequest(
                    drivers[i]['driverId'] as String,
                    drivers[i]['rideId'] as String,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Driver card ───────────────────────────────────────────────────────────────

class _DriverCard extends StatefulWidget {
  final Map<String, dynamic> driver;
  final Future<void> Function() onSendRequest;

  const _DriverCard({required this.driver, required this.onSendRequest});

  @override
  State<_DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<_DriverCard> {
  bool _sending = false;

  String _fmtCoord(String key) {
    final v = widget.driver[key];
    if (v == null) return '?';
    return (v as num).toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Driver route row ──────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.shade800,
                  child: const Icon(Icons.directions_car,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RouteLabel(
                        icon: Icons.trip_origin,
                        color: Colors.green,
                        text: widget.driver['sourceName'] ?? 'Unknown',
                      ),
                      const SizedBox(height: 4),
                      _RouteLabel(
                        icon: Icons.location_on,
                        color: Colors.red,
                        text: widget.driver['destinationName'] ?? 'Unknown',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // ── Meeting & drop points ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _PointChip(
                    icon: Icons.handshake,
                    label: "Board here",
                    color: Colors.orange,
                    value:
                        "${_fmtCoord('meetingPointLat')}, ${_fmtCoord('meetingPointLng')}",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PointChip(
                    icon: Icons.flag,
                    label: "Exit here",
                    color: Colors.purple,
                    value:
                        "${_fmtCoord('dropPointLat')}, ${_fmtCoord('dropPointLng')}",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Send request button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        await widget.onSendRequest();
                        // No need to reset — Navigator.pop closes this sheet
                      },
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_sending ? "Sending..." : "Send Request"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _RouteLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _RouteLabel(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PointChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String value;

  const _PointChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}