import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  OTPScreen({required this.phoneNumber, required this.verificationId});

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  /// 🔹 Verify OTP
  void _verifyOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _handleUserSignIn(userCredential.user!);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Invalid OTP. Please try again.";
      });
    }
  }

  /// 🔹 Handle User Sign-In or Account Creation
  Future<void> _handleUserSignIn(User user) async {
    print("🔍 Checking Firestore for phone number: ${widget.phoneNumber}");

    // ✅ Query Firestore for the phone number
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("customers")
        .where("PhoneNumber", isEqualTo: widget.phoneNumber)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // ✅ Phone number exists → Allow login
      print("✅ Existing user found in Firestore. Redirecting to AccountScreen...");
    } else {
      // 🚀 New user → Create Firestore record
      print("🚀 New user! Creating Firestore record...");

      // ✅ Generate a unique CustomerID
      String customerId = "CTM${DateTime.now().millisecondsSinceEpoch}";

      await FirebaseFirestore.instance
          .collection("customers")
          .doc(customerId) // 🔥 Use CustomerID as Firestore doc ID
          .set({
        "CustomerID": customerId, // ✅ Store CustomerID inside document
        "PhoneNumber": widget.phoneNumber,
        "EmailAddress": "",
        "FirstName": "",
        "LastName": "",
        "Gender": "",
        "PointBalance": 0,
        "WalletBalance": 0,
        "CreatedAt": FieldValue.serverTimestamp(),
      });

      print("✅ New user record created successfully with CustomerID: $customerId");
    }

    // ✅ Navigate to AccountScreen
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verification")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter the 6-digit code sent to ${widget.phoneNumber}",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 🔹 OTP Input
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                hintText: "Verification Code",
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style:
                    ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT"),
              ),
            ),

            // 🔹 Resend Code
            const SizedBox(height: 10),
            const Center(
              child: Text("Didn't receive it?",
                  style: TextStyle(color: Colors.grey)),
            ),
            Center(
              child: TextButton(
                onPressed: () {}, // Add Resend OTP logic if needed
                child: const Text("Get new code"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
