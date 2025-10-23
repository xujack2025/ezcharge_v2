import 'package:ezcharge/views/admin/admin_assign_driver.dart';
import 'package:ezcharge/views/admin/admin_emergency_requests.dart';
import 'package:ezcharge/views/auth/signin.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_notification.dart';
import 'package:ezcharge/constants/colors.dart';
import '../reports/admin_report.dart';
import 'admin_rewards.dart';
import 'admin_authenticate.dart'; // ✅ Import Authentication Page

class AdminDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminDrawer(
      {super.key, required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              "Admin Panel",
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
          _drawerItem(context, Icons.dashboard, "Dashboard", 0),
          _drawerItem(context, Icons.bar_chart, "Analytics", 1),
          _drawerItem(context, Icons.report, "Complaints", 2),
          _drawerItem(context, Icons.ev_station, "Charging Stations", 3),
          _drawerItem(context, Icons.person, "Profile", 4),

          const Divider(),

          /// Manage Notifications
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Manage Notifications"),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox(); // No unread notifications
                    }
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        snapshot.data!.docs.length.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  },
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdminNotificationPage()),
              );
            },
          ),

          /// 🔹 Add Authenticate Customers Option
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.blue),
            title: const Text(
              "Authenticate Customers",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminAuthenticatePage(),
                ),
              );
            },
          ),

          /// Rewards Page
          ListTile(
            leading: const Icon(
              Icons.local_offer,
              color: AppColors.primaryLight,
            ),
            title: const Text("Rewards",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminRewardsScreen(),
                ),
              );
            },
          ),

          /// Emergency Request Assign Page
          ListTile(
            leading: const Icon(
              Icons.warning,
              color: AppColors.danger,
            ),
            title: const Text("Assign Drivers",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminEmergencyRequestsPage(),
                ),
              );
            },
          ),

          /// Print Report Screen
          ListTile(
            leading: const Icon(
              Icons.print,
              color: Colors.blue,
            ),
            title: const Text(
              "Print Report",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrintReportScreen(),
                ),
              );
            },
          ),

          /// Logout Button
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  // 🔹 Drawer Item Builder
  Widget _drawerItem(
      BuildContext context, IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selectedIndex == index,
      onTap: () {
        onItemTapped(index);
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // ✅ Close drawer if open
        }
      },
    );
  }

  // 🔹 Logout Confirmation Dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignInScreen()),
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
