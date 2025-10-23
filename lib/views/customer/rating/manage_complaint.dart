import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:ezcharge/constants/colors.dart';
import 'package:ezcharge/constants/text_styles.dart';

class ManageComplaintsPage extends StatefulWidget {
  const ManageComplaintsPage({super.key});

  @override
  State<ManageComplaintsPage> createState() => _ManageComplaintsPageState();
}

class _ManageComplaintsPageState extends State<ManageComplaintsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _customerID; // Store fetched CustomerID

  @override
  void initState() {
    super.initState();
    _fetchCustomerID(); // Fetch CustomerID once
  }

  // 🔹 **Fetch CustomerID Once**
  Future<void> _fetchCustomerID() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    var customerQuery = await _firestore
        .collection("customers")
        .where("PhoneNumber", isEqualTo: user.phoneNumber)
        .limit(1)
        .get();

    if (customerQuery.docs.isNotEmpty) {
      setState(() {
        _customerID = customerQuery.docs.first["CustomerID"];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_customerID == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Manage My Complaints"),
          elevation: 4,
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage My Complaints"),
        elevation: 4,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("customers")
            .doc(_customerID)
            .collection("complaints")
            .orderBy("ComplaintDate", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No complaints found.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            );
          }

          var complaints = snapshot.data!.docs;

          return ListView.builder(
            itemCount: complaints.length,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemBuilder: (context, index) {
              var complaint = complaints[index].data() as Map<String, dynamic>;
              String complaintId = complaints[index].id;

              return Hero(
                tag: complaintId,
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.black26,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          _getStatusBackgroundColor(complaint["status"]),
                          Colors.white
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(complaint["status"]),
                        child: Icon(
                          _getStatusIcon(complaint["status"]),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        complaint["Reason"] ?? "No reason provided",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            "Status: ${complaint["status"] ?? "Pending"}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(complaint["status"]),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Date: ${_formatDate(complaint["ComplaintDate"])}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 18, color: Colors.black54),
                      onTap: () {
                        _showComplaintDetails(context, complaint, complaintId);
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Get Status Color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case "resolved":
        return Colors.green;
      case "in progress":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // Get Status Icon
  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case "resolved":
        return Icons.check_circle;
      case "in progress":
        return Icons.sync;
      default:
        return Icons.hourglass_empty;
    }
  }

  // Get Status Background Color
  Color _getStatusBackgroundColor(String? status) {
    switch (status?.toLowerCase()) {
      case "resolved":
        return Colors.green.shade100;
      case "in progress":
        return Colors.blue.shade100;
      default:
        return Colors.yellow.shade100;
    }
  }

  // Format Date
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "No date";
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Show Complaint Details with Hero Animation
  void _showComplaintDetails(BuildContext context,
      Map<String, dynamic> complaint, String complaintId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailScreen(
            complaint: complaint, complaintId: complaintId),
      ),
    );
  }
}

// Complaint Detail Screen (New Page)
class ComplaintDetailScreen extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final String complaintId;

  const ComplaintDetailScreen(
      {super.key, required this.complaint, required this.complaintId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Complaint Details"),
          backgroundColor: Colors.blueAccent),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: complaintId,
              child: Material(
                color: Colors.transparent,
                child: Text(
                  complaint["Reason"] ?? "No reason provided",
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Description: ${complaint["Description"] ?? "No description provided"}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "Status: ${complaint["status"] ?? "Pending"}",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            Text(
              "Date: ${complaint["ComplaintDate"]?.toDate().toString().split(" ")[0] ?? "No date"}",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
