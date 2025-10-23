import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/views/EZCHARGE/PaymentHistoryDetail.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String paymentMethod;
  final double totalAmount;

  const PaymentSuccessScreen({
    Key? key,
    required this.paymentMethod,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool isLoading = false;
  String _accountId = "";
  String _duration = "";
  String _chargerId = "";
  String _stationId = "";
  String _stationName = "";
  String _chargerName = "";
  String _chargerType = "";
  String _reservationID = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  //Get the logged-in user's CustomerID
  Future<void> _getCustomerID() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isNotEmpty) {
          // Find the customer's document
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
      // Once we have the _accountId, fetch the latest attendance record
      await _fetchReservationRecord();
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchReservationRecord() async {
    if (_accountId.isEmpty) return; // Ensure _accountId is available

    try {
      //Fetch reservation document for the user
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _reservationID = doc["ReservationID"];
        });
        await _fetchLatestAttendance();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  //Fetch the latest attendance record for this user
  Future<void> _fetchLatestAttendance() async {
    if (_reservationID.isEmpty) return;

    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("ReservationID", isEqualTo: _reservationID)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final docData = snap.docs.first.data() as Map<String, dynamic>;

        // Extract fields
        _duration = docData["Duration"] ?? "";
        _stationId = docData["StationID"] ?? "";
        _chargerId = docData["SlotID"] ?? "";

        // ✅ Wait for both fetches to complete before proceeding
        await _fetchStation();
        await _fetchCharger();
      }
    } catch (e) {
      print("Error fetching attendance: $e");
    }
  }


  Future<void> _fetchStation() async {
    if (_stationId.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .get();

      if (doc.exists) {
        _stationName = doc["StationName"] ?? "";
      }
    } catch (e) {
      print(" Error fetching station: $e");
    }
  }

  //Fetch charger details (including ChargerVoltage)
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
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  Future<String?> _createPaymentHistoryRecord() async {
    if (_accountId.isEmpty) return null;

    try {
      final String paymentID = "PAY${DateTime.now().millisecondsSinceEpoch}";
      // Use custom doc ID equal to paymentID
      await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("PaymentHistory")
          .doc(paymentID)
          .set({
        "StationName": _stationName,
        "ChargerName": _chargerName,
        "ChargerType": _chargerType,
        "Duration": _duration,
        "TotalCost": double.parse(widget.totalAmount.toStringAsFixed(2)),
        "PaymentMethod": widget.paymentMethod,
        "Paid Time": DateTime.now(),
        "Payment ID": paymentID,
      });

      print("Payment history record created successfully with ID $paymentID.");
      return paymentID;
    } catch (e) {
      print("Error creating payment history record: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Text(
                "Payment Successful!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Green check icon
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 20),

              // Thank-you message
              const Text(
                "Thank you for your payment\n"
                    "Kindly check your receipt in the payment history",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 80),

              // DONE button
              SizedBox(
                width: 200,
                height: 45,
                child: ElevatedButton(
                  onPressed: () async {
                    print("Station: $_stationName, Charger: $_chargerName, Type: $_chargerType, Duration: $_duration");
                    final paymentID = await _createPaymentHistoryRecord();
                    if (paymentID != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PaymentHistoryDetailScreen(
                                accountId: _accountId,
                                paymentDocId: paymentID,
                              ),
                        ),
                      );
                    } else {
                      // Optionally show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                            Text("Failed to create payment record.")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
