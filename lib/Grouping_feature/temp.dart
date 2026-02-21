import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RidersFetchPage(),
  ));
}

class RidersFetchPage extends StatelessWidget {
  const RidersFetchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("First 10 Riders"),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: firestore.collection('Riders').limit(10).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No Riders Found"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              print(data);

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? "No Name"),
                subtitle: Text(
                  "${data['company'] ?? "No Company"} • ${data['type'] ?? ""}",
                ),
              );
            },
          );
        },
      ),
    );
  }
}