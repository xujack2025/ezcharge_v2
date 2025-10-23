import 'package:ezcharge/views/admin/admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPAdminScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationID;

  OTPAdminScreen({required this.phoneNumber, required this.verificationID});

  @override
  _OTPAdminScreenState createState() => _OTPAdminScreenState();
}

class _OTPAdminScreenState extends State<OTPAdminScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  //Verify OTP
  void _verifyOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationID,
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

  //Handle Sign-In or Account Creation
  Future<void> _handleUserSignIn(User user) async {
    print("Checking Firestore for phone number: ${widget.phoneNumber}");

    //Query Firestore for the phone number
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("admins")
        .where("PhoneNumber", isEqualTo: widget.phoneNumber)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Phone number exists → Allow login
      print(
          "Existing user found in Firestore. Redirecting to AccountScreen...");
    } else {
      // Phone number not found → Show error
      print("Admin phone number not found!");
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin phone number not found!")),
      );
    }

    //Navigate to AccountScreen
    setState(() => _isLoading = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], //Light Grey Background
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //White Header (Back Button + Title)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: Colors.white,
            child: Row(
              children: [
                // Back Button (Blue Circle)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                // Title
                const Text(
                  "Verification",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          //OTP Prompt Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Enter the 6-digit code sent to ${widget.phoneNumber}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 20),

          // OTP Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: "Verification Code",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    counterText: "", // Hide character counter
                  ),
                ),

                //Error Message (if any)
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Submit Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SUBMIT",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          //Resend Code Section
          const Center(
            child: Text("Didn't receive it?",
                style: TextStyle(color: Colors.black54)),
          ),
          Center(
            child: TextButton(
              onPressed: () {}, // TODO: Implement Resend OTP
              child: const Text(
                "Get new code",
                style:
                    TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
