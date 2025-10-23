import 'dart:async';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';
import 'package:flutter/material.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  @override
  void initState() {
    super.initState();

    //Auto Navigate to AccountScreen after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _navigateToAccountScreen();
      }
    });
  }

  //Navigate Back to AccountScreen
  void _navigateToAccountScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AccountScreen()),
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
          onPressed: _navigateToAccountScreen,
        ),
        title: const Text(
          "Authenticate Account",
          style: TextStyle(
              color: Colors.black, fontSize: 25, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60), // Moves content upward

          //"Congratulations!" Text
          const Text(
            "Congratulations!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          // Green Check Icon
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 140, //Larger icon
          ),

          const SizedBox(height: 20),

          //Success Message
          const Text(
            "Your Face is successfully verified\nNow you can start your journey in EZCHARGE",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18), //Slightly larger text
          ),

          const SizedBox(height: 50),

          //"FINISH" Button (Larger & Centered)
          Center(
            child: SizedBox(
              width: 270, //Increased Width
              height: 55, //Increased Height
              child: ElevatedButton(
                onPressed: _navigateToAccountScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8)), //Rounded Corners
                ),
                child: const Text(
                  "FINISH",
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
