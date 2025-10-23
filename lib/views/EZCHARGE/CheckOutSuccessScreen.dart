import 'package:flutter/material.dart';

import 'package:ezcharge/views/EZCHARGE/PaymentScreen.dart';

class CheckOutSuccessScreen extends StatelessWidget {
  final double chargingCost;
  final double penaltyCost;
  final String duration;

  const CheckOutSuccessScreen(
      {super.key,
      required this.chargingCost,
      required this.penaltyCost,
      required this.duration});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set a white background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title / Confirmation message
              const Text(
                "Thanks for choosing us!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Icon or image
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 16),

              // Additional message
              const Text(
                "You have successfully checked out from the slot.\nDrive Safe!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),

              // "FINISH" or "CLOSE" button
              SizedBox(
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to PaymentScreen, passing both costs
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentScreen(
                          chargingCost: chargingCost, // double
                          penaltyCost: penaltyCost, // double or int
                          duration: duration,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 80, // Add horizontal padding
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                  ),
                  child: const Text(
                    "FINISH",
                    style: TextStyle(
                      fontSize: 25,
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
}
