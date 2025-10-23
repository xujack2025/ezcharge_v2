import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ezcharge/views/EZCHARGE/CheckOutDetail.dart';

class StopChargingScreen extends StatefulWidget {
  final Duration totalDuration;

  const StopChargingScreen({
    super.key,
    required this.totalDuration,
  });


  @override
  _StopChargingScreenState createState() => _StopChargingScreenState();
}

class _StopChargingScreenState extends State<StopChargingScreen> {
  String _accountId = "";
  String _chargerId = "";
  String _stationId = "";
  String _chargerName = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();

    // Automatically navigate to the next page after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CheckOutDetailScreen(
              totalDuration: widget.totalDuration,
            ),
          ),
        );
      }
    });
  }

  //Fetch current user from FirebaseAuth, then query Firestore for customer info
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

          // Fetch reservation record after getting CustomerID
          _fetchReservationRecord();
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Fetch the latest reservation for the user
  Future<void> _fetchReservationRecord() async {
    if (_accountId.isEmpty) return; // Ensure _accountId is available

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _chargerId = doc["ChargerID"];
          _stationId = doc["StationID"];
        });

        // Now fetch charger details
        _fetchCharger();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  //Fetch charger details to display charger name
  Future<void> _fetchCharger() async {
    if (_stationId.isEmpty || _chargerId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .collection("Charger")
          .doc(_chargerId)
          .get();

      if (doc.exists) {
        setState(() {
          _chargerName = doc["ChargerName"];
        });
      }
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: Colors.white, // White background
        elevation: 0,                 // Remove shadow
        leading: Container(),         // Hide default back icon
      ),

      body: Padding(
        padding: const EdgeInsets.only(left: 35, top: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // If you have a specific image for stopping charging, use it here
            Image.asset(
              'images/startcharging.png',
              fit: BoxFit.contain,
              height: 180, // Adjust as needed
            ),
            const SizedBox(height: 20),

            // Display the charger name
            Text(
              _chargerName,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),

            // Title
            const Text(
              "Unplug charger",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),

            // Subtitle / instructions
            const Text(
              "Unplug the connector and place back to the dock",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
