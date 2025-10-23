import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_assign_driver.dart';

class AdminEmergencyRequestsPage extends StatefulWidget {
  const AdminEmergencyRequestsPage({super.key});

  @override
  _AdminEmergencyRequestsPageState createState() =>
      _AdminEmergencyRequestsPageState();
}

class _AdminEmergencyRequestsPageState
    extends State<AdminEmergencyRequestsPage> {
  String selectedStatus = "All"; // Default filter

  /// ✅ Fetch Emergency Requests from Firestore
  Stream<QuerySnapshot> _fetchRequests() {
    print("🔄 Listening for real-time updates on emergency requests...");

    // Fetch all requests if "All" is selected
    if (selectedStatus == "All") {
      return FirebaseFirestore.instance
          .collection('emergency_requests')
          .snapshots()
          .map((snapshot) {
        print("✅ Firestore Update: Found ${snapshot.docs.length} requests");
        return snapshot;
      });
    } else {
      return FirebaseFirestore.instance
          .collection('emergency_requests')
          .where('status', isEqualTo: selectedStatus)
          .snapshots()
          .map((snapshot) {
        print("✅ Firestore Update: Found ${snapshot.docs.length} requests");
        return snapshot;
      });
    }
  }

  /// ✅ Dropdown to Filter Requests by Status
  Widget _statusFilterDropdown() {
    return DropdownButton<String>(
      value: selectedStatus,
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            selectedStatus = newValue;
          });
        }
      },
      items: [
        "All",
        "Pending",
        "Upcoming",
        "Arrived",
        "Charging",
        "Payment",
        "Completed"
      ].map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Requests")),
      body: Column(
        children: [
          // ✅ Filter Card for better UI
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter by Status:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _statusFilterDropdown(), // ✅ Dropdown Filter
                ],
              ),
            ),
          ),

          // ✅ Request List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100], // ✅ Subtle background color
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _fetchRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No requests found.",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)));
                  }

                  var requests = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: requests.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemBuilder: (context, index) {
                      var request =
                          requests[index].data() as Map<String, dynamic>;
                      String requestID = requests[index].id;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Icon(Icons.location_on, color: Colors.blue),
                          title: Text("Location: ${request["address"]}",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Reason: ${request["bookingReason"]}",
                                  style: TextStyle(color: Colors.black87)),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                      request["preferredTime"] ??
                                          "Unknown Time",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(request["status"],
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: _getStatusColor(request["status"]),
                          ),
                          onTap: () {
                            if (selectedStatus == "Pending" ||
                                selectedStatus == "Upcoming" ||
                                selectedStatus == "Charging" ||
                                selectedStatus == "Arrived") {
                              // ✅ Navigate to Assign Driver Page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminAssignDriverPage(
                                      requestID: requestID),
                                ),
                              );
                            } else {
                              // ✅ Show Progress if Already Assigned
                              _showRequestProgress(context, request);
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Get Color for Request Status
  Color _getStatusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Upcoming":
        return Colors.grey;
      case "Arrived":
        return Colors.brown;
      case "Charging":
        return Colors.blue;
      case "Payment":
        return Colors.purple;
      case "Completed":
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  /// ✅ Improved Request Progress UI
  void _showRequestProgress(
      BuildContext context, Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Request Progress", textAlign: TextAlign.center),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statusProgress(request["status"]),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text("Got it!",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Enhanced Progress Tracker with Step Indicator
  Widget _statusProgress(String status) {
    List<String> statuses = [
      "Pending",
      "Upcoming",
      "Arrived",
      "Charging",
      "Payment",
      "Completed"
    ];
    int currentIndex = statuses.indexOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: statuses.map((stage) {
        int index = statuses.indexOf(stage);
        bool isActive = index <= currentIndex;

        return Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isActive ? Colors.green : Colors.grey[300],
                  child: Icon(isActive ? Icons.check : Icons.circle,
                      color: isActive ? Colors.white : Colors.grey),
                ),
                const SizedBox(width: 12),
                Text(
                  stage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (index < statuses.length - 1) ...[
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(left: 16),
                height: 20,
                width: 2,
                color: isActive ? Colors.green : Colors.grey[300],
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}
