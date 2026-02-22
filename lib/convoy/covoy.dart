import 'dart:async';
import 'package:flutter/material.dart';


void main() => runApp(const MaterialApp(
    home: ConvoyMapSimulationScreen(), debugShowCheckedModeBanner: false));


// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------
class Commuter {
  final String name;
  final String timeString;
  final double individualCost;
  final String avatarUrl;
  final Alignment initialLocation; // Used to scatter them on the map
  final bool isMatch; // Flags if they belong to the final grouped convoy


  Commuter(this.name, this.timeString, this.individualCost, this.avatarUrl,
      this.initialLocation, this.isMatch);
}


// -----------------------------------------------------------------------------
// SCREEN 1: THE MAP RADAR SIMULATION
// -----------------------------------------------------------------------------
class ConvoyMapSimulationScreen extends StatefulWidget {
  const ConvoyMapSimulationScreen({super.key});


  @override
  State<ConvoyMapSimulationScreen> createState() =>
      _ConvoyMapSimulationScreenState();
}


class _ConvoyMapSimulationScreenState extends State<ConvoyMapSimulationScreen> {
  int daysAnalysed = 0;
  Timer? dayTimer;
  bool patternDetected = false;


  // 10 Scattered Commuters on the map
  final List<Commuter> allCommuters = [
    // --- GROUP 1: The 4 Perfect Matches (Same location, around 8:30 AM) ---
    // isMatch = true -> These will snap to the center
    Commuter(
        "Rahul",
        "8:25 AM",
        55,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.6, -0.4),
        true),
    Commuter(
        "Priya",
        "8:30 AM",
        60,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.3, -0.7),
        true),
    Commuter(
        "Amit",
        "8:25 AM",
        58,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.8, -0.2),
        true),
    Commuter(
        "Sneha",
        "8:35 AM",
        50,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.4, -0.1),
        true),


    // --- GROUP 2: The 2 Latecomers (Same location, but leaving at 10:00 AM) ---
    // Notice their alignment is close to Group 1, but isMatch = false because of time
    Commuter(
        "Vikram",
        "10:15 AM",
        65,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.5, -0.5),
        false),
    Commuter(
        "Neha",
        "10:30 AM",
        60,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(-0.7, -0.3),
        false),


    // --- GROUP 3: The 4 Randoms (Different locations, random times) ---
    // isMatch = false -> These will fade out
    Commuter(
        "Rohan",
        "7:10 AM",
        120,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(0.6, 0.5),
        false),
    Commuter(
        "Kavita",
        "9:45 AM",
        45,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(0.8, -0.6),
        false),
    Commuter(
        "Arjun",
        "6:30 AM",
        40,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(0.7, -0.1),
        false),
    Commuter(
        "Pooja",
        "8:15 AM",
        90,
        "https://static.vecteezy.com/system/resources/previews/037/336/395/original/user-profile-flat-illustration-avatar-person-icon-gender-neutral-silhouette-profile-picture-free-vector.jpg",
        const Alignment(0.1, 0.8),
        false),
  ];


  @override
  void initState() {
    super.initState();
    // Simulate the AI learning over 14 days
    dayTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() => daysAnalysed++);


      if (daysAnalysed == 14) {
        timer.cancel();
        setState(() => patternDetected = true);


        // Filter out only the matched people dynamically
        final matchedConvoy = allCommuters.where((c) => c.isMatch).toList();


        // Wait for the clustering animation to finish (2 seconds), then navigate
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ConvoyAlertScreen(commuters: matchedConvoy),
            ),
          );
        });
      }
    });
  }


  @override
  void dispose() {
    dayTimer?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF6),
      appBar: AppBar(
        title: const Text("Live Area Scanning",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          // Simulated Map Background Overlay (Fake Roads/Grid)
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.network(
                "https://www.transparenttextures.com/patterns/cubes.png",
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),


          // Central Society Hub (Hidden until pattern is found)
          AnimatedOpacity(
            opacity: patternDetected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.location_city,
                        size: 50, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  const Text("Blue Ridge Gate 1",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),


          // The Commuters (Markers)
          ...allCommuters.map((user) {
            final targetAlignment = (patternDetected && user.isMatch)
                ? const Alignment(0, 0) // Snaps to the center hub
                : user.initialLocation;


            // Fade out the non-matches
            final targetOpacity =
                (patternDetected && !user.isMatch) ? 0.2 : 1.0;


            return AnimatedAlign(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOutBack,
              alignment: targetAlignment,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 1),
                opacity: targetOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: user.isMatch ? Colors.green : Colors.grey,
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(user.avatarUrl)),
                    ),
                    if (!patternDetected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(user.timeString,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                  ],
                ),
              ),
            );
          }).toList(),


          // HUD Overlay for AI Status
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(patternDetected ? Icons.check_circle : Icons.radar,
                      color:
                          patternDetected ? Colors.green : Colors.blueAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patternDetected
                              ? "Micro-Convoy Identified!"
                              : "Scanning daily routines...",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text("Days Tracked: $daysAnalysed / 14",
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// SCREEN 2: DYNAMIC ALERT SCREEN
// -----------------------------------------------------------------------------
class ConvoyAlertScreen extends StatelessWidget {
  final List<Commuter> commuters;


  const ConvoyAlertScreen({super.key, required this.commuters});


  @override
  Widget build(BuildContext context) {
    const String society = "Blue Ridge Society";
    const String metro = "Hinjewadi Phase 1 Metro";
    const String convoyTime = "8:30 AM";


    int totalPeople = commuters.length;
    double sharedAutoCost = 70.0;
    double costPerPerson = sharedAutoCost / totalPeople;


    double mySavings = commuters[0].individualCost - costPerPerson;
    double carbonSaved = totalPeople * 0.4;


    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Smart Convoy Match",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.indigo.shade800, Colors.indigo.shade500]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people_alt, size: 50, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      "$totalPeople Neighbours matched!",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("$society ➔ $metro @ $convoyTime",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: _buildStatCard(
                          "Your New Fare",
                          "₹${costPerPerson.toStringAsFixed(0)}",
                          Icons.account_balance_wallet,
                          Colors.green)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildStatCard(
                          "You Save",
                          "₹${mySavings.toStringAsFixed(0)}",
                          Icons.trending_down,
                          Colors.blue)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.eco, color: Colors.green.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Joining this convoy saves ${carbonSaved.toStringAsFixed(1)} kg of CO₂ today!",
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text("Your Convoy Crew",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: commuters.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.indigo, width: 2),
                            ),
                            child: CircleAvatar(
                                radius: 24,
                                backgroundImage:
                                    NetworkImage(commuters[index].avatarUrl)),
                          ),
                          const SizedBox(height: 6),
                          Text(commuters[index].name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConvoyJoinSuccess()));
                },
                child: Text("Accept & Pay ₹${costPerPerson.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// SCREEN 3: SUCCESS SCREEN
// -----------------------------------------------------------------------------
class ConvoyJoinSuccess extends StatelessWidget {
  const ConvoyJoinSuccess({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.green.shade100),
                child: const Icon(Icons.check_circle,
                    size: 80, color: Colors.green),
              ),
              const SizedBox(height: 30),
              const Text("You're in the Convoy! 🎉",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text("Meet your auto at",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text("Blue Ridge Gate 1",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Departure Time",
                            style: TextStyle(color: Colors.grey)),
                        Text("8:30 AM Sharp",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Back to Home",
                    style: TextStyle(fontSize: 16, color: Colors.black)),
              )
            ],
          ),
        ),
      ),
    );
  }
}





