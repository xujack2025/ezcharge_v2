import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ezcharge/views/EZCHARGE/CheckDetail.dart';
import 'package:ezcharge/views/EZCHARGE/HomeScreen.dart';
import 'package:ezcharge/views/EZCHARGE/book_a_charge_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  _CheckInScreenState createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  File? _selectedImage; // Store the picked image
  String _accountId = "";
  String _reservationStatus = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  //Detect QR Code from the Camera Scanner
  void _onDetect(BarcodeCapture? capture) {
    if (capture != null && capture.barcodes.isNotEmpty) {
      final String scannedData = capture.barcodes.first.rawValue ?? "";
      _showScannedData(scannedData);
    }
  }

  Future<void> _getCustomerID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
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
          });

          //Fetch Reservation after getting CustomerID
          _fetchReservationRecord();
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Fetch the Latest Reservation for the User
  Future<void> _fetchReservationRecord() async {
    if (_accountId.isEmpty) return; // Ensure _accountId is available

    try {
      // Fetch reservation document for the user
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _reservationStatus = doc["Status"];
        });
      } else {
        // If no reservation found, update the status to trigger the error dialog
        setState(() {
          _reservationStatus = "Ended";
        });
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
      // Set a default status to handle the error
      setState(() {
        _reservationStatus = "Ended";
      });
    }
  }

  //Pick Image from Gallery and Scan for QR Code
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      //Scan the selected image for QR Code
      final barcodeScanner = MobileScannerController();
      barcodeScanner.analyzeImage(_selectedImage!.path).then((capture) {
        if (capture != null && capture.barcodes.isNotEmpty) {
          final String scannedData = capture.barcodes.first.rawValue ?? "";
          _showScannedData(scannedData);
        }
      }).catchError((error) {
        print("Error scanning image: $error");
      });
    }
  }

  ///Show Scanned QR Code Data in a Dialog
  void _showScannedData(String data) {
    if (data.isNotEmpty) {
      if (_reservationStatus == "Upcoming") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CheckDetailScreen(),
          ),
        );
      } else if (_reservationStatus == "Active") {
        // Show error message if the reservation is active.
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: const Text("You are charging your EV now"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else if (_reservationStatus == "Ended") {
        // Show error message if the reservation has ended.
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: const Text("Can't find your reservation"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mobile Scanner for QR Code
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          //EZCHARGE Title
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
                ),
              ),
            ),
          ),

          //Top Navigation Buttons
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavButton(Icons.qr_code, isSelected: true),
                  _buildNavButton(Icons.electric_bolt, isSelected: false,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HomeScreen()),
                        );
                      }),
                  _buildNavButton(Icons.local_gas_station, isSelected: false,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => BookAChargeScreen()));
                      }),
                ],
              ),
            ),
          ),

          //QR Code Frame Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          //Instruction Text
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                "Position the QR code within the frame",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          //Display Selected Image (If available)
          if (_selectedImage != null)
            Positioned(
              bottom: 250,
              left: 20,
              right: 20,
              child: Image.file(
                _selectedImage!,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),

          //Upload Button
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(Icons.image, color: Colors.white),
                label: const Text(
                  "Choose from Gallery",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Navigation Button Builder
  Widget _buildNavButton(IconData icon,
      {bool isSelected = false, VoidCallback? onTap}) {
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
}
