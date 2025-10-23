import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:ezcharge/views/EZCHARGE/HomeScreen.dart';
import 'package:ezcharge/models/emergency_request_model.dart';
import 'package:ezcharge/views/customer/emergency_request/emergency_request_view.dart';
import 'package:ezcharge/views/customer/emergency_request/request_history.dart';
import 'package:ezcharge/views/customer/emergency_request/tracking_view.dart';
import 'package:ezcharge/views/customer/Reward/RewardScreen.dart';
import 'package:ezcharge/views/customer/Notification/NotificationScreen.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';
import 'package:ezcharge/views/EZCHARGE/CheckInScreen.dart';

class BookAChargeScreen extends StatefulWidget {
  const BookAChargeScreen({super.key});

  @override
  _BookAChargeScreenState createState() => _BookAChargeScreenState();
}

class _BookAChargeScreenState extends State<BookAChargeScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true, activeRequestExists = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  String? imageUrl;
  String? requestID;
  String? driverID;
  StreamSubscription<List<EmergencyRequest>>? _requestSubscription;

  @override
  void initState() {
    super.initState();

    // 🔹 Initialize animation for breathing effect
    _controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    String? customerID = FirebaseAuth.instance.currentUser?.uid;
    if (customerID != null) {
      _checkActiveRequest(); // ✅ Use the real customerID dynamically
    }

    _loadImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
    _requestSubscription
        ?.cancel(); // ✅ Prevent memory leaks when widget is disposed
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      String url = await FirebaseStorage.instance
          .ref("images/power_bank.png") // Ensure this is the correct path
          .getDownloadURL();

      print("✅ New Image URL: $url"); // Print the URL for debugging

      setState(() {
        imageUrl = url;
      });
    } catch (e) {
      print("❌ Error loading image: $e");
    }
  }

  void _checkActiveRequest() {
    String? phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (phoneNumber == null) {
      print("❌ No phone number found for user.");
      return;
    }

    FirebaseFirestore.instance
        .collection('customers')
        .where('PhoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .snapshots() // 🔹 Listen for real-time changes
        .listen((customerQuery) {
      if (customerQuery.docs.isEmpty) {
        print("❌ No customer found with this phone number.");
        return;
      }

      // ✅ Extract CustomerID
      String customerID = customerQuery.docs.first['CustomerID'];
      print("✅ Found CustomerID: $customerID");

      // ✅ Listen for active requests in real-time
      FirebaseFirestore.instance
          .collection('emergency_requests')
          .where('CustomerID', isEqualTo: customerID)
          .where('status', whereIn: [
            "Pending",
            "Upcoming",
            "Arrived",
            "Charging",
            "Payment"
          ])
          .limit(1)
          .snapshots() // 🔹 Real-time listener for request updates
          .listen((activeRequests) {
            if (activeRequests.docs.isNotEmpty) {
              // ✅ Extract active request ID
              String fetchedRequestID = activeRequests.docs.first.id;
              print("🔄 Request Updated! New requestID: $fetchedRequestID");

              // ✅ Update state with the new request in real-time
              if (mounted) {
                setState(() {
                  activeRequestExists = true;
                  requestID = fetchedRequestID;
                  isLoading = false;
                });
              }
            } else {
              print("✅ No active request found.");
              if (mounted) {
                setState(() {
                  activeRequestExists = false;
                  requestID = null;
                  isLoading = false;
                });
              }
            }
          });
    });
  }

  Future<void> navigateToTrackingView(String requestID) async {
    print("🔍 Fetching driverID for request: $requestID");

    try {
      // ✅ Fetch the request document from Firestore
      DocumentSnapshot requestSnapshot = await FirebaseFirestore.instance
          .collection('emergency_requests')
          .doc(requestID)
          .get();

      if (!requestSnapshot.exists) {
        print("❌ Error: Request not found in Firestore.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request not found. Please try again.")),
        );
        return;
      }

      // ✅ Extract request data
      Map<String, dynamic> requestData =
          requestSnapshot.data() as Map<String, dynamic>;

      // ✅ Ensure `driverID` exists in Firestore
      String driverID = requestData.containsKey('driverID')
          ? requestData['driverID'] ?? "Unknown"
          : "Unknown";

      print("✅ Retrieved driverID: $driverID");

      // 🔹 If `driverID` is still unknown, listen for updates
      if (driverID == "Unknown" || driverID.isEmpty) {
        print("⏳ Waiting for driver assignment...");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Waiting for driver assignment...")),
        );

        // ✅ Listen for real-time updates
        FirebaseFirestore.instance
            .collection('emergency_requests')
            .doc(requestID)
            .snapshots()
            .listen((updatedSnapshot) {
          if (!updatedSnapshot.exists) return;

          Map<String, dynamic>? updatedData =
              updatedSnapshot.data();

          if (updatedData != null && updatedData.containsKey('driverID')) {
            String updatedDriverID = updatedData['driverID'] ?? "Unknown";

            if (updatedDriverID != "Unknown" && updatedDriverID.isNotEmpty) {
              print("✅ Driver assigned: $updatedDriverID");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrackingView(
                    driverID: updatedDriverID,
                    requestID: requestID,
                  ),
                ),
              );
            }
          }
        });

        return; // ✅ Prevents immediate navigation when driver is missing
      }

      // ✅ Navigate immediately if driver is already assigned
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackingView(
            driverID: driverID,
            requestID: requestID,
          ),
        ),
      );
    } catch (e) {
      print("❌ Error fetching request details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching request details.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// ✅ Background Image Instead of Google Maps
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? "",
              // ✅ Avoids null error
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              // ✅ Loading indicator
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error, color: Colors.red, size: 50),
              ), // ✅ Shows error icon if image fails to load
            ),
          ),

          /// ✅ Dark Overlay for Better Contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          /// ✅ EZCHARGE Title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: const Text(
                "EZCHARGE",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                        blurRadius: 4,
                        color: Colors.black45,
                        offset: Offset(1, 1))
                  ],
                ),
              ),
            ),
          ),

          // ✅ Top Navigation Buttons
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavButton(Icons.qr_code, isSelected: false, onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CheckInScreen()));
                  }),
                  _buildNavButton(Icons.electric_bolt, isSelected: false,
                      onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()));
                  }),
                  _buildNavButton(Icons.local_gas_station, isSelected: true),
                ],
              ),
            ),
          ),

          /// ✅ Track Request Icon Button (Top-Right)
          Positioned(
            top: 240,
            right: 20,
            child: ScaleTransition(
              scale: activeRequestExists
                  ? _animation
                  : AlwaysStoppedAnimation(1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    shape: const CircleBorder(),
                    elevation: 6,
                    color: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.electric_car,
                        size: 35,
                        color: Color(0xFF4A90E2),
                      ),
                      tooltip: "Track Request",
                      onPressed: () async {
                        if (!activeRequestExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("You have no active request.")),
                          );
                          return;
                        }

                        if (requestID == null || requestID!.isEmpty) {
                          print("❌ Error: Request ID is missing.");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Request ID is missing.")),
                          );
                          return;
                        }

                        await navigateToTrackingView(requestID!);
                      },
                    ),
                  ),

                  /// 🔴 Badge
                  if (activeRequestExists)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          /// ✅ Request History Button (Below "Track Request")
          Positioned(
            top: 300,
            right: 20,
            child: ScaleTransition(
              scale: AlwaysStoppedAnimation(1.0), // No animation needed
              child: Material(
                shape: const CircleBorder(),
                elevation: 6,
                color: Colors.white,
                child: IconButton(
                  icon: const Icon(
                    Icons.history,
                    size: 35, // Matches Track Request icon size
                    color: Color(0xFF4A90E2),
                  ),
                  tooltip: "Request History",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RequestHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          /// ✅ Informative Text for Users
          const Positioned(
            bottom: 180, // Position above the "BOOK A CHARGE" button
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Need an EV charge? Book a mobile charging service now!",
                  // Main message
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10), // Space before the button
                Text(
                  "Our power bank trucks will come to your location and recharge your vehicle anytime, anywhere.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          /// ✅ Book a Charge Button
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EmergencyRequestView()),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 6,
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Center(
                child: Text(
                  "BOOK A CHARGE",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),

          /// ✅ Bottom Navigation Bar
          _buildBottomNavBar(context),
        ],
      ),
    );
  }

  /// 🔹 Build Navigation Button (QR / Charging / Gas)
  Widget _buildNavButton(IconData icon, {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.black,
          size: 30,
        ),
      ),
    );
  }

  /// 🔹 Bottom Navigation Bar (Same as HomeScreen)
  Widget _buildBottomNavBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => RewardScreen()));
          } else if (index == 3) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => NotificationScreen()));
          } else if (index == 2) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => AccountScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_car), label: "EZCharge"),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_giftcard), label: "Rewards"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Me"),
          BottomNavigationBarItem(icon: Icon(Icons.mail), label: "Inbox"),
        ],
      ),
    );
  }
}
