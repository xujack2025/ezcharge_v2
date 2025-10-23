import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/views/EZCHARGE/RewardSelectScreen.dart';
import 'package:ezcharge/views/EZCHARGE/SelectPaymentScreen.dart';

class PaymentScreen extends StatefulWidget {
  final double chargingCost;
  final double penaltyCost;
  final String duration;

  const PaymentScreen({
    Key? key,
    required this.chargingCost,
    required this.penaltyCost,
    required this.duration,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Loading indicator
  bool isLoading = false;

  // Firestore fields
  String _accountId = "";
  String _stationId = "";
  String _chargerId = "";
  String _stationName = "";
  String _chargerName = "";
  String _chargerType = "";
  String _reservationStatus = "";
  String _stationImageUrl = "";
  double _rewardDiscount = 0.0;
  String _selectedRewardID = "";
  int _rewardPoints = 0;

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  //Get the logged-in user's CustomerID from Firestore
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

            // Once we have _accountId, fetch the reservation record
            await _fetchReservationRecord();
          }
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    setState(() => isLoading = false);
  }

  //Fetch the reservation record for this user
  Future<void> _fetchReservationRecord() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        _chargerId = doc["ChargerID"] ?? "";
        _stationId = doc["StationID"] ?? "";
        _reservationStatus = doc["Status"] ?? "";

        // Only fetch station & charger if reservation status is "Ended"
        if (_reservationStatus == "Ended") {
          await _fetchStation();
          await _fetchCharger();
        }
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  //Fetch station details
  Future<void> _fetchStation() async {
    if (_stationId.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .get();

      if (doc.exists) {
        _stationName = doc["StationName"] ?? "";
        _stationImageUrl = doc["ImageUrl"] ?? "";
        setState(() {});
      }
    } catch (e) {
      print("Error fetching station: $e");
    }
  }

  //Fetch charger details
  Future<void> _fetchCharger() async {
    if (_stationId.isEmpty || _chargerId.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .collection("Charger")
          .doc(_chargerId)
          .get();

      if (doc.exists) {
        _chargerName = doc["ChargerName"] ?? "";
        _chargerType = doc["ChargerType"] ?? "";
      }
      // Trigger a rebuild to show the updated fields
      setState(() {});
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    //Calculate subtotal
    final double subtotal = widget.chargingCost + widget.penaltyCost;
    //Calculate final total after discount
    final double totalAmount = subtotal - _rewardDiscount;

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
                    //Title "Payment" at the top
                    const Text(
                      "Payment",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    //Station image
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_stationImageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    //Station info rows
                    _infoRow("Charging Station:", _stationName),
                    _infoRow("Charging Slot:", _chargerName),
                    _infoRow("Charger Type:", _chargerType),
                    _infoRow("Total Duration:", widget.duration),

                    const SizedBox(height: 16),

                    //Reward discount label
                    const Text(
                      "Reward Discount",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Instead of Dropdown, use a button/tappable widget
                    InkWell(
                      onTap: () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RewardSelectScreen(),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _rewardDiscount = result["discount"];
                            _selectedRewardID = result["rewardID"];
                            _rewardPoints =
                                result["points"]; // save the points value
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Select Reward"),
                            // If discount is zero, show "-", else show the discount
                            Text(
                              _rewardDiscount == 0
                                  ? "-"
                                  : "-RM${_rewardDiscount.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 16,
                                color: _rewardDiscount == 0
                                    ? Colors.black
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _infoRow("Charging total:",
                        "RM ${widget.chargingCost.toStringAsFixed(2)}"),
                    _infoRow("Penalty total:",
                        "RM ${widget.penaltyCost.toStringAsFixed(2)}"),
                    // Subtotal row
                    _infoRow("Subtotal:", "RM ${subtotal.toStringAsFixed(2)}"),
                    // Reward discount row
                    _infoRow(
                      "Reward Discount:",
                      _rewardDiscount == 0
                          ? "-"
                          : "-RM${_rewardDiscount.toStringAsFixed(2)}",
                    ),

                    const Divider(height: 32),

                    //Total row
                    _infoRow(
                      "Total Amount:",
                      "RM ${(totalAmount < 0 ? 0.0 : totalAmount).toStringAsFixed(2)}",
                      isBold: true,
                    ),

                    const SizedBox(height: 24),

                    //CONTINUE button
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
                          // 1) Calculate final total
                          final double subtotal =
                              widget.chargingCost + widget.penaltyCost;
                          final double finalTotal = subtotal - _rewardDiscount;
                          // Ensure it never goes below 0
                          final double safeTotal =
                              finalTotal < 0 ? 0 : finalTotal;

                          //Navigate to SelectPaymentScreen with the final total, rewardID, and rewardPoints
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SelectPaymentScreen(
                                totalAmount: safeTotal,
                                rewardID: _selectedRewardID,
                                rewardPoints: _rewardPoints,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          "CONTINUE",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Helper widget for row label + value
  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
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
