import 'package:flutter/material.dart';
import 'package:lastmile_transport/Grouping_feature/temp.dart';
import 'package:lastmile_transport/MetroSync/metroSync_test.dart';
import 'package:lastmile_transport/Offline_Booking_hub/Offline_Booking_using_Qa.dart';
import 'package:lastmile_transport/app_drawers_screens/Group_feature_screen.dart';
import 'package:lastmile_transport/app_drawers_screens/Paid_lift_feature.screen.dart';
import 'package:lastmile_transport/chatbot/chatbot_screen.dart';
import 'package:lastmile_transport/convoy/covoy.dart';

// import 'package:manymore/data/insert_locations.dart';
// import 'package:manymore/data/insert_riders.dart';
// import 'package:manymore/data/locations_list.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 54, 30, 233), Colors.purple],
              ),
            ),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.child_friendly, size: 28),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "404 team Not Selected",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "Harshu is Building",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🔹 MENU ITEMS
          _drawerItem(
            context,
            Icons.smart_toy_outlined,
            "Chatbot",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            },
          ),

          _drawerItem(
            context,
            Icons.ev_station,
            "Offline Booking",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EvHubOfflineChatbotScreen(),
                ),
              );
            },
          ),
          _drawerItem(
            context,
            Icons.ev_station,
            "Neighbour Convoy",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConvoyMapSimulationScreen(),
                ),
              );
            },
          ),
          _drawerItem(
            context,
            Icons.ev_station,
            "Metro Sync",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MetroBookingScreen(),
                ),
              );
            },
          ),
          _drawerItem(
            context,
            Icons.groups_rounded,
            "Group & Ride",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RidesPage()),
              );
            },
          ),

          _drawerItem(
            context,
            Icons.pedal_bike_rounded,
            "Paid Lift",
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen()),
              );
            },
          ),

          const Spacer(),
          const Divider(),

          _drawerItem(context, Icons.logout, "Logout", () {
            Navigator.pop(context);
          }, isLogout: true),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isLogout ? Colors.red : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}