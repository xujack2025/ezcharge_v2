import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Files
import 'package:ezcharge/views/customer/customercontent/EditProfileScreen.dart';
import 'admin_dashboard.dart';
import 'admin_authenticate.dart';  // ✅ Import the Authentication Page
import 'package:ezcharge/services/auth_service.dart';
import 'package:ezcharge/views/auth/signin.dart';
import 'admin_profile_edit.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  _AdminProfilePageState createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  String _adminName = "Admin";
  String _adminId = "ADM25XXXX";
  String _email = "admin@gmail.com";

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  /// 🔹 Fetch logged-in admin's details from Firestore
  Future<void> _fetchAdminData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String uid = user.uid;
        String? userPhone =
            user.phoneNumber; // Get phone number from Firebase Auth

        // 1️⃣ Attempt to fetch admin data using UID first
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection("admins")
            .doc(uid)
            .get();

        if (adminDoc.exists) {
          // ✅ Found admin data using UID
          _setAdminData(adminDoc);
          return;
        }

        // 2️⃣ If UID search fails, check if we have a phone number and query by phone number
        if (userPhone != null && userPhone.isNotEmpty) {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection("admins")
              .where("PhoneNumber", isEqualTo: userPhone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            // ✅ Found admin data using Phone Number
            _setAdminData(querySnapshot.docs.first);
            return;
          }
        }

        print("❌ Admin document not found!");
      }
    } catch (e) {
      print("❌ Error fetching admin data: $e");
    }
  }

  /// Helper function to update state
  void _setAdminData(DocumentSnapshot adminDoc) {
    setState(() {
      _adminName = "${adminDoc["FirstName"]} ${adminDoc["LastName"]}";
      _adminId = adminDoc["AdminID"];
      _email = adminDoc["EmailAddress"];
    });
  }

  void _signOut(BuildContext context) async {
    await AuthService().signout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 🔹 Admin Info Section
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Admin ID: $_adminId",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                        Text(
                          "Email: $_email",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  _buildSection("Account Settings", [
                    _buildListItem("Edit Profile", onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditAdminProfileScreen()),
                      );
                    }),
                  ]),

                  _buildSection("Support", [
                    _buildListItem("Help Center"),
                    _buildListItem("Contact Support"),
                    _buildListItem("Terms & Conditions"),
                  ]),

                  _buildSection("Customer Authentication", [
                    _buildListItem("Authenticate Customers", onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => AdminAuthenticatePage()), // ✅ Navigate to Authentication Page
                      );
                    }),
                  ]),

                  _buildCenteredListItem(context, "Log Out", Icons.logout),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 UI Components
  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[300],
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Column(children: items),
      ],
    );
  }

  Widget _buildListItem(String title, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildCenteredListItem(
      BuildContext context, String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[300],
      child: Center(
        child: InkWell(
          onTap: () => _signOut(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
            ],
          ),
        ),
      ),
    );
  }
}
