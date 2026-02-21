import 'package:flutter/material.dart';

/// Shown to the DRIVER — displays seekers who are near their route OR who sent requests.
/// Only the driver can accept. Seekers never see this sheet.
class MatchedSeekersSheet extends StatelessWidget {
  final List<Map<String, dynamic>> seekers;
  final Future<void> Function(String seekerUid) onAccept;

  const MatchedSeekersSheet({
    super.key,
    required this.seekers,
    required this.onAccept,
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
            "${seekers.length} Seeker(s)",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap Accept to confirm a seeker's ride request",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: seekers.length,
              itemBuilder: (context, index) {
                final seeker = seekers[index];
                return _SeekerCard(
                  seeker: seeker,
                  onAccept: () async {
                    Navigator.pop(context);
                    await onAccept(seeker['uid']);
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

class _SeekerCard extends StatefulWidget {
  final Map<String, dynamic> seeker;
  final VoidCallback onAccept;

  const _SeekerCard({required this.seeker, required this.onAccept});

  @override
  State<_SeekerCard> createState() => _SeekerCardState();
}

class _SeekerCardState extends State<_SeekerCard> {
  bool _accepting = false;

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
              backgroundColor: Colors.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.seeker['name'] ?? "Seeker",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "📍 ${(widget.seeker['lat'] as double).toStringAsFixed(4)}, "
                    "${(widget.seeker['lng'] as double).toStringAsFixed(4)}",
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _accepting ? null : () {
                setState(() => _accepting = true);
                widget.onAccept();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: _accepting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("Accept"),
            ),
          ],
        ),
      ),
    );
  }
}