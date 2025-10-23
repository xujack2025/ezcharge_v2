import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthenticatePage extends StatefulWidget {
  const AdminAuthenticatePage({super.key});

  @override
  _AdminAuthenticatePageState createState() => _AdminAuthenticatePageState();
}

class _AdminAuthenticatePageState extends State<AdminAuthenticatePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TabController? _tabController; // ✅ Declare as nullable

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose(); // ✅ Dispose only if not null
    super.dispose();
  }

  // Fetch all customers' authentication requests
  Stream<List<Map<String, dynamic>>> fetchCustomerAuthData() {
    return _firestore
        .collection('customers')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Future<Map<String, dynamic>>> futureList =
          snapshot.docs.map<Future<Map<String, dynamic>>>((doc) async {
        var authDoc = await doc.reference
            .collection('authenticate')
            .doc('authentication')
            .get();
        final authData = authDoc.data() ?? {}; // Ensure no null errors

        return {
          "customerId": doc.id,
          "licenseImage": authData['LicenseImage'] ?? '',
          "selfieImage": authData['SelfieImage'] ?? '',
          "Status": authData['Status'] ?? 'Pending',
        };
      }).toList();

      return await Future.wait(futureList);
    });
  }

  // Approve customer authentication
  Future<void> approveCustomer(String customerId) async {
    await _firestore
        .collection('customers')
        .doc(customerId)
        .collection('authenticate')
        .doc('authentication')
        .update({
      "Status": "Pass",
    });
  }

  // Reject customer authentication
  Future<void> rejectCustomer(String customerId) async {
    await _firestore
        .collection('customers')
        .doc(customerId)
        .collection('authenticate')
        .doc('authentication')
        .update({
      "Status": "Failed",
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Customer Authentication"),
          bottom: _tabController == null // ✅ Null-check before using controller
              ? null
              : TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: "Pending"),
                    Tab(text: "Approved"),
                    Tab(text: "Rejected"),
                  ],
                ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: fetchCustomerAuthData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            var customers = snapshot.data!;
            if (customers.isEmpty) {
              return Center(child: Text("No authentication requests."));
            }

            return _tabController == null // ✅ Handle null case
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController!,
                    children: [
                      _buildCustomerList(customers, "Pending"),
                      _buildCustomerList(customers, "Pass"),
                      _buildCustomerList(customers, "Failed"),
                    ],
                  );
          },
        ),
      ),
    );
  }

  // 🔹 Build the customer list based on status
  Widget _buildCustomerList(
      List<Map<String, dynamic>> customers, String status) {
    var filteredCustomers =
        customers.where((c) => c['Status'] == status).toList();

    if (filteredCustomers.isEmpty) {
      return Center(child: Text("No $status customers."));
    }

    return ListView.builder(
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        var customer = filteredCustomers[index];

        return Card(
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Customer ID: ${customer['customerId']}",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: customer['licenseImage'].isNotEmpty
                          ? Image.network(customer['licenseImage'],
                              height: 120, fit: BoxFit.cover)
                          : Image.asset('assets/images/placeholder.png',
                              height: 120, fit: BoxFit.cover),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: customer['selfieImage'].isNotEmpty
                          ? Image.network(customer['selfieImage'],
                              height: 120, fit: BoxFit.cover)
                          : Image.asset('assets/images/placeholder.png',
                              height: 120, fit: BoxFit.cover),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text("Status: ${customer['Status']}",
                    style: TextStyle(color: Colors.blue)),
                SizedBox(height: 10),
                if (status == "Pending") ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            approveCustomer(customer['customerId']),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: Text("Approve"),
                      ),
                      ElevatedButton(
                        onPressed: () => rejectCustomer(customer['customerId']),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: Text("Reject"),
                      ),
                    ],
                  ),
                ] else if (status == "Pass") ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 5),
                      Text("Approved", style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ] else if (status == "Failed") ...[
                  Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 5),
                      Text("Rejected", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
