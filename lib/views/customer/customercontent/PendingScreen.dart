import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  String _customerId = "";
  String? _licenseImageUrl;
  String? _selfieImageUrl;

  @override
  void initState() {
    super.initState();
    _getCustomerID(); //Fetch Customer ID
    _navigateToAccountScreen(); // Auto Navigate after 10 sec
  }

  // Fetch Logged-in Customer ID
  Future<void> _getCustomerID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .where("PhoneNumber", isEqualTo: user.phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var userDoc = querySnapshot.docs.first;
        _customerId = userDoc["CustomerID"];

        await _fetchImagesAndStoreInFirestore(); // Fetch Images & Store
      }
    } catch (e) {
      print("Error fetching customer ID: $e");
    }
  }

  // Fetch License & Selfie Image URLs, Store in Firestore
  Future<void> _fetchImagesAndStoreInFirestore() async {
    try {
      // Fetch images from Firebase Storage
      _licenseImageUrl =
          await _fetchImageFromStorage("license/$_customerId.jpg");
      _selfieImageUrl = await _fetchImageFromStorage("selfie/$_customerId.jpg");

      // Create 'authenticate' collection in Firestore
      if (_licenseImageUrl != null && _selfieImageUrl != null) {
        await FirebaseFirestore.instance
            .collection("customers")
            .doc(_customerId)
            .collection("authenticate")
            .doc("authentication") // Document name
            .set({
          "LicenseImage": _licenseImageUrl,
          "SelfieImage": _selfieImageUrl,
          "Status": "Pending",
          "Timestamp": FieldValue.serverTimestamp(),
        });

        print("Authentication data stored successfully!");
      }
    } catch (e) {
      print("Error fetching images & storing in Firestore: $e");
    }
  }

  // Fetch Image from Firebase Storage
  Future<String?> _fetchImageFromStorage(String path) async {
    try {
      Reference ref = FirebaseStorage.instance.ref().child(path);
      return await ref.getDownloadURL(); //Get download URL
    } catch (e) {
      print("Error fetching image from Storage: $e");
      return null;
    }
  }

  // Auto-Navigate to AccountScreen after 10 seconds
  void _navigateToAccountScreen() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty,
                size: 100, color: Colors.blue), // ⏳ Pending Icon
            const SizedBox(height: 20),
            const Text(
              "Your authentication request is pending approval.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 10),
            const Text(
              "This process may take some time. Please wait...",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
