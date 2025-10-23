import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/views/customer/emergency_request/RequestSelectPaymentScreen.dart';
import 'package:ezcharge/views/EZCHARGE/RewardSelectScreen.dart';

class RequestPaymentScreen extends StatefulWidget {
  final String requestID;
  final double chargingCost;
  final String duration;

  const RequestPaymentScreen({
    Key? key,
    required this.requestID,
    required this.chargingCost,
    required this.duration,
  }) : super(key: key);

  @override
  State<RequestPaymentScreen> createState() => _RequestPaymentScreenState();
}

class _RequestPaymentScreenState extends State<RequestPaymentScreen> {
  bool isLoading = false;
  String _accountId = "";
  String _stationImageUrl = "";
  double _rewardDiscount = 0.0;
  String _selectedRewardID = "";
  int _rewardPoints = 0;

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
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isNotEmpty) {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection("customers")
              .where("PhoneNumber", isEqualTo: userPhone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            var userDoc = querySnapshot.docs.first;
            _accountId = userDoc["CustomerID"] ?? "";
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
    // **Calculate total amount**
    final double totalAmount = widget.chargingCost - _rewardDiscount;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // **Charging Details**
              _infoRow("Total Duration:", widget.duration),
              _infoRow("Charging Cost:", "RM ${widget.chargingCost.toStringAsFixed(2)}"),

              const SizedBox(height: 16),

              // **Reward Discount Selection**
              const Text(
                "Reward Discount",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RewardSelectScreen(),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      _rewardDiscount = result["discount"];
                      _selectedRewardID = result["rewardID"];
                      _rewardPoints = result["points"];
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Reward"),
                      Text(
                        _rewardDiscount == 0
                            ? "-"
                            : "-RM${_rewardDiscount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          color: _rewardDiscount == 0 ? Colors.black : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _infoRow("Subtotal:", "RM ${widget.chargingCost.toStringAsFixed(2)}"),
              _infoRow(
                "Reward Discount:",
                _rewardDiscount == 0 ? "-" : "-RM${_rewardDiscount.toStringAsFixed(2)}",
              ),

              const Divider(height: 32),

              // **Final Total**
              _infoRow(
                "Total Amount:",
                "RM ${(totalAmount < 0 ? 0.0 : totalAmount).toStringAsFixed(2)}",
                isBold: true,
              ),

              const SizedBox(height: 24),

              // **Continue to Payment**
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RequestSelectPaymentScreen(
                          totalAmount: totalAmount < 0 ? 0.0 : totalAmount,
                          rewardID: _selectedRewardID,
                          rewardPoints: _rewardPoints,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "CONTINUE",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // **Helper for displaying key-value information rows**
  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value.isNotEmpty ? value : "-",
              style: TextStyle(
                fontSize: 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
