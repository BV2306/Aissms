import 'package:flutter/material.dart';

class SeekerMatchedDriversSheet extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;

  /// Called when seeker taps "Send Request" — passes driverId and rideId
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "${drivers.length} Driver(s) Found Nearby",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "These drivers have an active route near your location.\nSend a request — they will accept or ignore it.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final driver = drivers[index];
                return _DriverCard(
                  driver: driver,
                  onSendRequest: () async {
                    Navigator.pop(context);
                    // ✅ Pass both driverId and rideId — seeker does NOT accept anything
                    await onSendRequest(
                      driver['driverId'],
                      driver['rideId'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatefulWidget {
  final Map<String, dynamic> driver;
  final VoidCallback onSendRequest;

  const _DriverCard({required this.driver, required this.onSendRequest});

  @override
  State<_DriverCard> createState() => _DriverCardState();
}

class _DriverCardState extends State<_DriverCard> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.directions_car, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.driver['sourceName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.driver['destinationName'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _sending ? null : () {
                setState(() => _sending = true);
                widget.onSendRequest();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Send Request"),
            ),
          ],
        ),
      ),
    );
  }
}