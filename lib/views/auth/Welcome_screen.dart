import 'package:flutter/material.dart';
import 'package:ezcharge/views/auth/IntroScheduleScreen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isChecked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Stack(
          children: [
            // EZCHARGE Positioned at Top-Left
            const Positioned(
              top: 40,
              left: 10,
              child: Text(
                'EZCHARGE',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                  color: Colors.black,
                ),
              ),
            ),

            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      height: 180), // Distance between unititled and welcome
                  const Text(
                    'Welcome to Malaysia',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                      height: 30), // Distance between map icon and welcome

                  // Map with Marker
                  SizedBox(
                    width: 280,
                    height: 350,
                    child: const Image(
                      image: AssetImage(
                          'assets/images/welcome_map_icon.png'), // Replace with actual map image
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(
                      height: 50), // Distance between checkbox and map icon

                  // Terms and Privacy Checkbox
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setState(() {
                            isChecked = value!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'By continuing, you agree to the ',
                            children: [
                              TextSpan(
                                text: 'Terms of Use',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ', including cookie use.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Continue Button
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: isChecked
                        ? () {
                            // Navigate to ScheduleScreen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const IntroScheduleScreen(),
                              ),
                            );
                          }
                        : null, // Disable button if not checked
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 35, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
