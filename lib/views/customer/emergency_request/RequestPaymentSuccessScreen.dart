import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ezcharge/views/EZCHARGE/PaymentHistoryDetail.dart';
import 'package:ezcharge/views/customer/emergency_request/RequestPaymentHistoryDetailScreen.dart';

class RequestPaymentSuccessScreen extends StatefulWidget {
  final String paymentMethod;
  final double totalAmount;

  const RequestPaymentSuccessScreen({
    Key? key,
    required this.paymentMethod,
    required this.totalAmount,
  }) : super(key: key);

  @override
  State<RequestPaymentSuccessScreen> createState() =>
      _RequestPaymentSuccessScreenState();
}

class _RequestPaymentSuccessScreenState
    extends State<RequestPaymentSuccessScreen> {
  bool isLoading = false;
  String _accountId = "";
  String _duration = "";
  String _requestID = "";

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
      _fetchRequestRecord();
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchRequestRecord() async {
    if (_accountId.isEmpty) return;

    try {
      // 🔍 Query the latest request by this customer
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection("emergency_requests")
          .where("CustomerID", isEqualTo: _accountId)
          .limit(1)
          .get();

      print("accountID RPSS: $_accountId");

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _requestID = data["requestID"] ?? query.docs.first.id;
        });
      }

      print("requestID RPSS: $_requestID");

      _fetchLatestRequest(); // continue your flow
    } catch (e) {
      print("Error fetching request record: $e");
    }
  }

  //Fetch the latest attendance record for this user
  Future<void> _fetchLatestRequest() async {
    if (_requestID.isEmpty) return;

    try {
      // Query 'attendance' for docs with this ReservationID,
      // order by CheckOutTime descending, then limit to 1
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("emergency_requests")
          .where("requestID", isEqualTo: _requestID)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final docData = snap.docs.first.data() as Map<String, dynamic>;

        // Extract fields from the attendance doc
        _duration = docData["chargingFormattedTime"] ?? "";
        print("duration RPSS $_duration");
      }
    } catch (e) {
      print("Error fetching attendance: $e");
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
        ""
        "Duration": _duration,
        "TotalCost": double.parse(widget.totalAmount.toStringAsFixed(2)),
        "PaymentMethod": widget.paymentMethod,
        "Paid Time": DateTime.now(),
        "Payment ID": paymentID,
      });

      print("duration RPSS $_duration");

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
                          final paymentID = await _createPaymentHistoryRecord();
                          if (paymentID != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RequestPaymentHistoryDetailScreen(
                                  accountId: _accountId,
                                  paymentDocId: paymentID,
                                  requestId: _requestID,
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
