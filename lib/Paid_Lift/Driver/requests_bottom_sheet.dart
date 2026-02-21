import 'package:flutter/material.dart';

class RequestsBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> seekers;
  final Function(String requestId) onAccept;

  const RequestsBottomSheet({
    super.key,
    required this.seekers,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Matched Seekers (Within 500m)",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: seekers.isEmpty
                ? const Center(
                    child: Text("No seekers nearby"),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: seekers.length,
                    itemBuilder: (context, index) {
                      final seeker = seekers[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Seeker ID: ${seeker['uid']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  "Lat: ${seeker['lat']}"),
                              Text(
                                  "Lng: ${seeker['lng']}"),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  onAccept(seeker['uid']);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("Accept"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}