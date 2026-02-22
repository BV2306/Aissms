import 'package:flutter/material.dart';
import 'package:lastmile_transport/Grouping_feature/temp.dart';
import 'package:lastmile_transport/Offline_Booking_hub/Offline_Booking_using_Qa.dart';
import 'package:lastmile_transport/app_drawers_screens/Group_feature_screen.dart';
import 'package:lastmile_transport/app_drawers_screens/Paid_lift_feature.screen.dart';
import 'package:lastmile_transport/chatbot/chatbot_screen.dart';
// import 'package:manymore/data/insert_locations.dart';
// import 'package:manymore/data/insert_riders.dart';
// import 'package:manymore/data/locations_list.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 🔥 PREMIUM HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF361EE9),
                  Color(0xFF8E2DE2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.only(bottomRight: Radius.circular(24)),
            ),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.ev_station, size: 26),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Last Mile Transport",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Smart EV Mobility",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

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
          const Divider(height: 1),

          // 🔴 LOGOUT
          _drawerItem(
            context,
            Icons.logout_rounded,
            "Logout",
            () {
              Navigator.pop(context);
            },
            isLogout: true,
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ⭐ PREMIUM TILE
  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isLogout = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isLogout ? Colors.red : Colors.black87,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: isLogout ? Colors.red : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}