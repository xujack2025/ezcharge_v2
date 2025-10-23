import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ezcharge/views/EZCHARGE/HomeScreen.dart';
import 'package:ezcharge/views/EZCHARGE/PaymentHistoryDetail.dart';

class PaymentHistoryListScreen extends StatefulWidget {
  const PaymentHistoryListScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryListScreen> createState() =>
      _PaymentHistoryListScreenState();
}

class _PaymentHistoryListScreenState extends State<PaymentHistoryListScreen> {
  bool isLoading = false;
  String _accountId = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  Future<void> _getCustomerID() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userPhone = user.phoneNumber ?? "";
        if (userPhone.isNotEmpty) {
          final querySnapshot = await FirebaseFirestore.instance
              .collection("customers")
              .where("PhoneNumber", isEqualTo: userPhone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            _accountId = querySnapshot.docs.first["CustomerID"] ?? "";
          }
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(),
                ),
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: const Text(
          "Payment History",
          style: TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accountId.isEmpty
              ? const Center(child: Text("No account ID found."))
              : _buildPaymentHistoryStream(),
    );
  }

  Widget _buildPaymentHistoryStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("PaymentHistory")
          .orderBy("Paid Time", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading payment history."));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No payment history found."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final stationName = data["StationName"] ?? "-";
            final chargerName = data["ChargerName"] ?? "-";
            final chargerType = data["ChargerType"] ?? "-";
            final duration = data["Duration"] ?? "";
            final paymentMethod = data["PaymentMethod"] ?? "";
            final totalCost = (data["TotalCost"] ?? 0).toString();
            final paidTime = data["Paid Time"];
            final payID = data["Payment ID"]; // Firestore doc ID
            // Convert timestamp
            DateTime? paidDateTime;
            if (paidTime is Timestamp) {
              paidDateTime = paidTime.toDate();
            }
            final dateStr = paidDateTime != null
                ? DateFormat('EEE MMM d, h:mma').format(paidDateTime)
                : "";
            final costStr = "-RM$totalCost";

            return InkWell(
              onTap: () {
                // Navigate to detail screen, passing docId & accountId
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentHistoryDetailScreen(
                      accountId: _accountId,
                      paymentDocId: payID,
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          costStr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          stationName,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$chargerName | $chargerType",
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Duration: $duration • $paymentMethod",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
