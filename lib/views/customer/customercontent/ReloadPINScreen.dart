import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReloadPINScreen extends StatefulWidget {
  final double topUpAmount;
  const ReloadPINScreen({required this.topUpAmount, super.key});

  @override
  _ReloadPINScreenState createState() => _ReloadPINScreenState();
}

class _ReloadPINScreenState extends State<ReloadPINScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();
  String _accountId = "";
  String _userPhone = "";
  bool _isLoading = true;
  bool _isOtpValid = true;
  String _verificationId = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  // Fetch Customer ID and Phone Number
  Future<void> _getCustomerID() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) return;

        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;
          setState(() {
            _accountId = userDoc["CustomerID"];
            _userPhone = userDoc["PhoneNumber"];
            _isLoading = false;
          });

          _sendFirebaseOTP(); // Send OTP to user
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
      setState(() => _isLoading = false);
    }
  }

  // Send OTP using Firebase Authentication
  Future<void> _sendFirebaseOTP() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _userPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("Auto verification completed");
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Verification Failed: ${e.message}");
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId; // Store verification ID
            _isLoading = false;
          });
          print("OTP Sent to $_userPhone");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("Auto retrieval timeout");
        },
      );
    } catch (e) {
      print("Error sending OTP: $e");
    }
  }

  // Verify OTP and Add Credit
  Future<void> _verifyOTPAndTopUp() async {
    setState(() => _isLoading = true);

    try {
      //Create Firebase Credential from entered OTP
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      //Sign in with this credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      //Update Wallet Balance
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .get();
      double currentBalance = (userSnapshot["WalletBalance"] ?? 0.0).toDouble();
      double newBalance = currentBalance + widget.topUpAmount;

      await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .update({"WalletBalance": newBalance});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Top-up successful!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Invalid Reload OTP: $e");
      setState(() => _isOtpValid = false); // Show invalid code message
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Reload with Reload PIN",
            style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OTP Verification Display
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.wallet,
                              size: 50, color: Colors.white),
                          const SizedBox(height: 10),
                          const Text(
                            "RELOAD PIN\n"
                            "   ******",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Please enter the Reload PIN :",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Reload PIN",
                      errorText: _isOtpValid ? null : "Invalid Reload OTP",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // TOP UP Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifyOTPAndTopUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        "TOP UP",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
