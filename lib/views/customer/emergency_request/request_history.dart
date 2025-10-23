import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({Key? key}) : super(key: key);

  @override
  _RequestHistoryScreenState createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  String? customerID;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomerID();
  }

  /// ✅ Fetch CustomerID from Firestore Using Phone Number
  Future<void> _fetchCustomerID() async {
    String? phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phoneNumber == null) {
      print("❌ Error: No phone number found.");
      setState(() => isLoading = false);
      return;
    }

    QuerySnapshot customerQuery = await FirebaseFirestore.instance
        .collection('customers')
        .where('PhoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();

    if (customerQuery.docs.isNotEmpty) {
      setState(() {
        customerID = customerQuery.docs.first['CustomerID'];
        isLoading = false;
      });
      print("✅ Customer ID is $customerID");
    } else {
      print("❌ No customer found with this phone number.");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Request History")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // 🔄 Loading State
          : customerID == null
              ? const Center(child: Text("❌ Error: No Customer ID found."))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('emergency_requests')
                      .where('CustomerID',
                          isEqualTo: customerID) // ✅ Use `customerID`
                      //.orderBy('preferredTime', descending: true) // ✅ Sort by most recent
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var requests = snapshot.data!.docs;

                    if (requests.isEmpty) {
                      return const Center(
                          child: Text("No past requests found."));
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        var request =
                            requests[index].data() as Map<String, dynamic>;
                        String status = request['status'] ?? "Unknown";

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12), // More padding
                          child: ExpansionTile(
                            key: PageStorageKey('${request['requestID']}'),
                            initiallyExpanded: true,
                            // ✅ Force expand to check if details are there
                            title: Text("Status: $status"),
                            subtitle: Text(
                                "Location: ${request['address'] ?? 'Unknown'}"),
                            trailing:
                                Text(request['preferredTime'] ?? "No Time"),
                            children: [
                              ListTile(
                                title: Text(
                                    "Booking Reason: ${request['bookingReason'] ?? 'N/A'}"),
                              ),
                              if (status == "Completed") ...[
                                ListTile(
                                  title: Text(
                                    "Charging Time: ${request['chargingFormattedTime'] ?? '00:00:00'}",
                                  ),
                                ),
                                ListTile(
                                  title: Text(
                                      "Total Cost: RM ${(request['totalCost'] as num?)?.toDouble().toStringAsFixed(2) ?? 'N/A'}"),
                                ),
                                if (request['imageUrl'] != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.network(
                                      request['imageUrl']!,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Text(
                                            "❌ Image Not Available");
                                      },
                                    ),
                                  ),
                              ] else ...[
                                ListTile(
                                  title: Text(
                                      "Driver Assigned: ${request['driverID'] ?? 'Not Assigned'}"),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
