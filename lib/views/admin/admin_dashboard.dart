import 'package:ezcharge/views/admin/admin_analysis.dart';
import 'package:ezcharge/views/admin/admin_charging_station.dart';
import 'package:ezcharge/views/admin/admin_drawer.dart';
import 'package:ezcharge/widgets/bottom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import Admin Pages
import 'admin_assign_driver.dart';
import 'admin_notification.dart';
import 'admin_profile.dart';
import 'admin_complaint.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // Default to Dashboard

  final List<Widget> _pages = [
    const AdminHomeContent(), // Dashboard
    const AdminAnalyticsPage(), // Analytics
    const AdminComplaintPage(), // Complaints
    const AdminChargingStationsPage(), // ✅ Charging Stations Management
    const AdminProfilePage(), // Profile
  ];

  final List<String> _titles = [
    "Admin Dashboard",
    "Admin Analysis",
    "Admin Complaints",
    "Manage Charging Stations",
    "Admin Profile"
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          // 🔔 Notification Bell Icon in AppBar
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdminNotificationPage()),
              );
            },
          ),
        ],
      ),
      drawer: AdminDrawer(
        // ✅ Use the new AdminDrawer widget
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ), // Sidebar Navigation
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        // ✅ Smooth transition effect
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _pages[_selectedIndex], // ✅ Animated Page Switching
      ),
      bottomNavigationBar: CustomBottomAppBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        isAdmin: true, // Indicates Admin Navigation Bar
      ),
    );
  }
}

// ✅ Admin Home Dashboard Content
class AdminHomeContent extends StatelessWidget {
  const AdminHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Real-time Dashboard Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _dashboardStatCard(
                  "Total Customers", Icons.people, "customers", Colors.blue),
              _dashboardStatCard(
                  "Total Complaints", Icons.warning, "complaints", Colors.red),
              _dashboardStatCard(
                  "Total Stations", Icons.ev_station, "stations", Colors.green),
              _dashboardStatCard(
                  "Total Bays", Icons.charging_station, "bays", Colors.orange),
              _dashboardStatCard("All-Time Charges", Icons.flash_on,
                  "total_chargings", Colors.purple),
              _dashboardStatCard(
                  "Today Charges", Icons.bolt, "charging_today", Colors.teal),
            ],
          ),

          const SizedBox(height: 20),
          // ✅ Active Emergency Requests Section
          _activeEmergencyRequestsWidget(context),
        ],
      ),
    );
  }

  // ✅ Real-Time Dashboard Cards
  Widget _dashboardStatCard(
      String title, IconData icon, String type, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),

            // ✅ StreamBuilder for Real-Time Updates
            StreamBuilder<int>(
              stream: _getStatCountStream(type),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                return Text(
                  snapshot.data.toString(),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Widget to Display Active Emergency Requests
  Widget _activeEmergencyRequestsWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            "Active Emergency Requests",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('emergency_requests')
              .where('status',
                  isEqualTo: "Pending") // ✅ Show only unassigned requests
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No active emergency requests."));
            }

            var requests = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                var request = requests[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  elevation: 3,
                  child: ListTile(
                    title: Text("Location: ${request["address"]}"),
                    subtitle: Text("Reason: ${request["bookingReason"]}"),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.blue),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminAssignDriverPage(
                              requestID: requests[index].id),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ✅ Convert Future to Firestore Stream for Real-Time Updates
  Stream<int> _getStatCountStream(String type) {
    final firestore = FirebaseFirestore.instance;
    switch (type) {
      case 'customers':
        return firestore
            .collection('customers')
            .snapshots()
            .map((snapshot) => snapshot.docs.length);
      case 'complaints':
        return firestore
            .collectionGroup('complaints')
            .snapshots()
            .map((snapshot) => snapshot.docs.length);
      case 'stations':
        return firestore
            .collection('station')
            .snapshots()
            .map((snapshot) => snapshot.docs.length);
      case 'bays':
        return firestore.collection('station').snapshots().map((snapshot) {
          int totalBays = 0;
          for (var station in snapshot.docs) {
            totalBays += (station.data()['Capacity'] as num? ?? 0).toInt();
          }
          return totalBays;
        });
      case 'charging_today':
        DateTime now = DateTime.now();
        DateTime startOfDay = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(hours: 8));
        DateTime endOfDay = startOfDay.add(const Duration(days: 1));

        return firestore
            .collection('attendance')
            .where('CheckInTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('CheckOutTime', isLessThan: Timestamp.fromDate(endOfDay))
            .snapshots()
            .map((snapshot) => snapshot.docs.length);

      case 'total_chargings':
        return firestore
            .collection('attendance')
            .snapshots()
            .map((snapshot) => snapshot.docs.length);

      default:
        return const Stream.empty();
    }
  }
}
