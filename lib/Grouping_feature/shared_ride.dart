import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './real_time_sharing.dart';


class SharedRideSelectionPage extends StatefulWidget {
  const SharedRideSelectionPage({super.key});


  @override
  State<SharedRideSelectionPage> createState() =>
      _SharedRideSelectionPageState();
}


class _SharedRideSelectionPageState
    extends State<SharedRideSelectionPage> {


  final FirebaseFirestore firestore =
      FirebaseFirestore.instance;


  final TextEditingController pickupController =
      TextEditingController();
  final TextEditingController dropController =
      TextEditingController();


  String activeField = "pickup";
  String priorityGender = "No Preference";


  double? pickupLat;
  double? pickupLong;
  double? dropLat;
  double? dropLong;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shared Ride"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [


          // 🔹 Top Input Section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [


                TextField(
                  controller: pickupController,
                  decoration: const InputDecoration(
                    hintText: "Enter Source",
                    prefixIcon: Icon(Icons.my_location,
                        color: Colors.green),
                  ),
                  onTap: () {
                    activeField = "pickup";
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),


                const SizedBox(height: 10),


                TextField(
                  controller: dropController,
                  decoration: const InputDecoration(
                    hintText: "Enter Destination",
                    prefixIcon: Icon(Icons.location_on,
                        color: Colors.red),
                  ),
                  onTap: () {
                    activeField = "drop";
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),


                const SizedBox(height: 12),


                DropdownButtonFormField<String>(
                  value: priorityGender,
                  decoration: const InputDecoration(
                    labelText: "Priority Gender",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: "No Preference",
                        child: Text("No Preference")),
                    DropdownMenuItem(
                        value: "Male",
                        child: Text("Male Only")),
                    DropdownMenuItem(
                        value: "Female",
                        child: Text("Female Only")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      priorityGender = value!;
                    });
                  },
                ),
              ],
            ),
          ),


          const Divider(),


          // 🔹 Location Suggestions
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  firestore.collection('Locations').snapshots(),
              builder: (context, snapshot) {


                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }


                final docs = snapshot.data!.docs;


                String searchText =
                    activeField == "pickup"
                        ? pickupController.text.toLowerCase()
                        : dropController.text.toLowerCase();


                final filteredDocs = docs.where((doc) {
                  final name =
                      doc['name'].toString().toLowerCase();
                  return name.contains(searchText);
                }).toList();


                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                        filteredDocs[index].data()
                            as Map<String, dynamic>;


                    return ListTile(
                      leading:
                          const Icon(Icons.location_on),
                      title: Text(data['name']),
                      subtitle: Text(data['type']),
                      onTap: () {
                        if (activeField == "pickup") {
                          pickupController.text =
                              data['name'];
                          pickupLat = data['lat'];
                          pickupLong = data['long'];
                        } else {
                          dropController.text =
                              data['name'];
                          dropLat = data['lat'];
                          dropLong = data['long'];
                        }
                        setState(() {});
                      },
                    );
                  },
                );
              },
            ),
          ),


          // 🔹 Find Sharing Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize:
                    const Size(double.infinity, 50),
              ),
              onPressed: () {


               
              Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SimpleLocationPage()),
            );
              },
              child: const Text(
                "Find Sharing",
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}





