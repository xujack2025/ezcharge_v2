import 'package:ezcharge/views/customer/customercontent/AuthenticateAccountScreen.dart';
import 'package:flutter/material.dart';

class FailScreen extends StatelessWidget {
  const FailScreen({super.key});

  void _retryAuthentication(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const AuthenticateAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], //Light Grey Background
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
        title: const Text("Authenticate Account",
            style: TextStyle(
                color: Colors.black,
                fontSize: 25,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60), //Moves content upward

          const Text(
            "Sorry, Please Try Again!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          //Red Cross Icon
          const Icon(
            Icons.cancel,
            color: Colors.red,
            size: 140, // Slightly larger
          ),

          const SizedBox(height: 20),

          // Instruction Message
          const Text(
            "Your selfie is incompatible with your license\n"
            "Please provide a valid license",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 50),

          // "TRY AGAIN" Button (Larger & Centered)
          Center(
            child: SizedBox(
              width: 270, //Increased Width
              height: 55, // Increased Height
              child: ElevatedButton(
                onPressed: () => _retryAuthentication(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8)), // Rounded Corners
                ),
                child: const Text(
                  "TRY AGAIN",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white), //Larger Font
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
