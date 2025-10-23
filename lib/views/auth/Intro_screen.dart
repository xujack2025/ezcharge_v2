import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ezcharge/views/auth/Welcome_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), () {
      _requestLocationPermission(); // Delayed to ensure UI loads first
    });
  }

  //Request Location Permission
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // User denied permission
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle case where user permanently denies location
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location access permanently denied. Enable it in settings."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Large Black Oval (Exceeding the Screen)
          Positioned(
            top: 25,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.5,
              height: 550,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.elliptical(300, 150),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 240),
                  // App Logo
                  Container(
                    width: 200,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset('assets/images/ezcharge_logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 20),
                  // Title Text
                  const Text(
                    'EZCHARGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 45,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Section with NEXT Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 75, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'NEXT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
