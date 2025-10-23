import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminComplaintPage extends StatefulWidget {
  const AdminComplaintPage({super.key});

  @override
  State<AdminComplaintPage> createState() => _AdminComplaintPageState();
}

class _AdminComplaintPageState extends State<AdminComplaintPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedStaffId; // Stores selected staff for assignment
  TabController? _tabController; // ✅ Nullable TabController

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✅ Three tabs
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ✅ Fetch complaints based on status
  Stream<QuerySnapshot> fetchComplaintsByStatus(String status) {
    return _firestore
        .collectionGroup('complaints')
        .where('status', isEqualTo: status)
        .orderBy('ComplaintDate',
            descending: true) // ✅ Order by date (newest first)
        .snapshots();
  }

  // ✅ Fetch all complaints from customer documents
  Future<List<QueryDocumentSnapshot>> fetchAllComplaints() async {
    List<QueryDocumentSnapshot> allComplaints = [];

    try {
      // ✅ Fetch all customers
      QuerySnapshot customersSnapshot =
          await _firestore.collection('customers').get();

      for (var customerDoc in customersSnapshot.docs) {
        // ✅ Fetch complaints from each customer's subcollection
        QuerySnapshot complaintSnapshot =
            await customerDoc.reference.collection('complaints').get();

        allComplaints.addAll(complaintSnapshot.docs);
      }
    } catch (e) {
      debugPrint("Error fetching complaints: $e");
    }

    return allComplaints;
  }

  // ✅ Fetch all available staff for assignment
  Future<List<QueryDocumentSnapshot>> fetchAllStaff() async {
    try {
      QuerySnapshot staffSnapshot = await _firestore
          .collection('staff')
          .where('status', isEqualTo: 'Available')  // Filter by 'status' field
          .get();
      return staffSnapshot.docs;
    } catch (e) {
      debugPrint("Error fetching staff: $e");
      return [];
    }
  }


  // ✅ Assign staff and update complaint status
  Future<void> assignStaffToComplaint(String customerId, String complaintId, String adminId, String staffId) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Admin must be logged in to assign staff.")),
      );
      return;
    }

    try {
      // ✅ Fetch logged-in admin details
      var adminQuery = await _firestore
          .collection("admins")
          .where("PhoneNumber", isEqualTo: user.phoneNumber)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin profile not found.")),
        );
        return;
      }

      String adminID = adminQuery.docs.first.id; // ✅ Get logged-in Admin ID

      // ✅ Update complaint with assigned staff
      await _firestore
          .collection('customers')
          .doc(customerId)
          .collection('complaints')
          .doc(complaintId)
          .update({
        'status': 'In Progress',
        'AdminID': adminID,
        'AssignedStaffID': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Update staff status to "Busy"
      await _firestore.collection('staff').doc(staffId).update({
        'status': 'Busy',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Complaint assigned to staff. Staff is now Busy.")),
      );

      setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error assigning staff: $e")),
      );
    }
  }

  // ✅ Mark complaint as resolved
  Future<void> resolveComplaint(String customerId, String complaintId) async {
    try {
      // ✅ Get complaint details to find assigned staff
      DocumentSnapshot complaintSnapshot = await _firestore
          .collection('customers')
          .doc(customerId)
          .collection('complaints')
          .doc(complaintId)
          .get();

      if (!complaintSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Complaint not found.")),
        );
        return;
      }

      String? staffId = complaintSnapshot['AssignedStaffID'];

      // ✅ Mark complaint as resolved
      await _firestore
          .collection('customers')
          .doc(customerId)
          .collection('complaints')
          .doc(complaintId)
          .update({
        'status': 'Resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Update staff status back to "Available"
      if (staffId != null) {
        await _firestore.collection('staff').doc(staffId).update({
          'status': 'Available',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Complaint resolved. Staff is now Available.")),
      );

      setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error resolving complaint: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // ✅ 3 tabs
      child: Scaffold(
        appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(18.0), // ✅ Set proper height
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(icon: Icon(Icons.pending), text: "Pending"),
                Tab(icon: Icon(Icons.timelapse), text: "In Progress"),
                Tab(icon: Icon(Icons.check_circle), text: "Resolved"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildComplaintList(fetchComplaintsByStatus("Pending")),
            _buildComplaintList(fetchComplaintsByStatus("In Progress")),
            _buildComplaintList(fetchComplaintsByStatus("Resolved")),
          ],
        ),
      ),
    );
  }

  // ✅ Build Complaint List UI
  Widget _buildComplaintList(Stream<QuerySnapshot> complaintsStream) {
    return StreamBuilder<QuerySnapshot>(
      stream: complaintsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading complaints"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No complaints available"));
        }

        var complaints = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            var complaint = complaints[index];
            var data = complaint.data() as Map<String, dynamic>;
            String customerId = complaint.reference.parent.parent!.id;

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Complaint ID & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Complaint ID: ${data['ComplaintID'] ?? 'N/A'}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(data['status']),
                      ],
                    ),
                    const Divider(height: 20),

                    // ✅ Complaint Details
                    _buildDetailRow(Icons.person, "Customer ID", customerId),
                    _buildDetailRow(
                        Icons.location_on, "Station ID", data['StationID']),
                    _buildDetailRow(Icons.warning, "Reason", data['Reason']),
                    _buildDetailRow(
                        Icons.description, "Description", data['Description']),
                    _buildDetailRow(
                        Icons.date_range,
                        "Date",
                        data['ComplaintDate'] != null
                            ? (data['ComplaintDate'] as Timestamp)
                                .toDate()
                                .toString()
                            : 'Unknown'),
                    if (data['AdminID'] != null)
                      _buildDetailRow(
                          Icons.admin_panel_settings, "Admin", data['AdminID']),
                    if (data['AssignedStaffID'] != null)
                      _buildDetailRow(Icons.assignment_ind, "Staff",
                          data['AssignedStaffID']),

                    const SizedBox(height: 10),

                    // ✅ Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (data['status'] == 'Pending')
                          FutureBuilder<List<QueryDocumentSnapshot>>(
                            future: fetchAllStaff(),
                            builder: (context, staffSnapshot) {
                              if (staffSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }
                              if (staffSnapshot.hasError ||
                                  staffSnapshot.data == null) {
                                return const Text("Error loading staff.");
                              }
                              if (staffSnapshot.data!.isEmpty) {
                                return const Text("No available staff.");
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAssignStaffDropdown(staffSnapshot.data!,
                                      customerId, complaint.id),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_selectedStaffId == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  "Please select a staff member.")),
                                        );
                                        return;
                                      }

                                      assignStaffToComplaint(
                                          customerId,
                                          complaint.id,
                                          FirebaseAuth
                                              .instance.currentUser!.uid,
                                          _selectedStaffId!);
                                    },
                                    child: const Text("Assign Staff"),
                                  ),
                                ],
                              );
                            },
                          ),
                        if (data['status'] == 'In Progress')
                          ElevatedButton(
                            onPressed: () =>
                                resolveComplaint(customerId, complaint.id),
                            child: const Text("Resolve"),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ✅ Builds a styled status badge with colors/icons
  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    IconData icon;
    switch (status) {
      case "Resolved":
        bgColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case "In Progress":
        bgColor = Colors.orange;
        icon = Icons.timelapse;
        break;
      default:
        bgColor = Colors.red;
        icon = Icons.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 5),
          Text(status ?? 'Pending',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// ✅ Reusable Detail Row with Icons
  Widget _buildDetailRow(IconData icon, String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$title: ${value ?? 'N/A'}",
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Dropdown for assigning staff
  Widget _buildAssignStaffDropdown(List<QueryDocumentSnapshot> staffDocs,
      String customerId, String complaintId) {
    return DropdownButton<String>(
      hint: const Text("Select Staff"),
      value: _selectedStaffId,
      items: staffDocs.map((staffDoc) {
        var staffData = staffDoc.data() as Map<String, dynamic>;
        return DropdownMenuItem(
          value: staffDoc.id,
          child: Text(staffData['FirstName'] ?? 'Unknown'),
        );
      }).toList(),
      onChanged: (selectedStaff) {
        setState(() {
          _selectedStaffId = selectedStaff;
        });
      },
    );
  }
}
