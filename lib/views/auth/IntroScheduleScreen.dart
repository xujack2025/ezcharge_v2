import 'package:flutter/material.dart';
import 'signin_screen.dart';

class IntroScheduleScreen extends StatefulWidget {
  const IntroScheduleScreen({super.key});

  @override
  State<IntroScheduleScreen> createState() => _IntroScheduleScreenState();
}

class _IntroScheduleScreenState extends State<IntroScheduleScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Widget> _pages = [
    OnboardingPage(
      title: 'Schedule your charging',
      subtitle: 'Check, Reserve and charge your EV',
      imagePath: 'assets/images/schedule_charging1.png',
    ),
    OnboardingPage(
      title: 'Pay for your charging',
      subtitle: 'Pay with any method you prefer',
      imagePath: 'assets/images/schedule_charging2.png',
    ),
    OnboardingPage(
      title: 'Earn for your charging',
      subtitle: 'Earn points for every sustainable action',
      imagePath: 'assets/images/schedule_charging3.png',
    ),
  ];

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          FocusScope.of(context).unfocus(), // Hide keyboard on tap anywhere
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: _pages,
              ),
            ),
            // Page Indicator and Button
            Padding(
              padding: const EdgeInsets.only(bottom: 24.6),
              child: Column(
                children: [
                  // Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: _currentIndex == index ? 20 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? Colors.black
                              : Colors.black38,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 130),
                  // Button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _currentIndex == _pages.length - 1 ? 'START NOW' : 'NEXT',
                      style: const TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
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

// Onboarding Page Widget
class OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // unititled Title Positioned to Left
          const Align(
            alignment: Alignment.topLeft,
            child: Text(
              'EZCHARGE',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 50),

          // Align Text Content to the Left
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Image Centered
          Center(
            child: Image.asset(
              imagePath,
              width: 320,
              height: 250,
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}
