import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ezcharge/views/EZCHARGE/TimerScreen.dart';

class StartChargingScreen extends StatefulWidget {
  const StartChargingScreen({super.key});

  @override
  _StartChargingScreenState createState() => _StartChargingScreenState();
}

class _StartChargingScreenState extends State<StartChargingScreen> {
  String _accountId = "";
  String _chargerId = "";
  String _stationId = "";
  String _chargerName = "";

  @override
  void initState() {
    super.initState();
    _getCustomerID();

    //Navigate to the next page after 5 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TimerScreen()),
        );
      }
    });
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

          // Fetch Reservation after getting CustomerID
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
      //Fetch reservation document for the user
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _chargerId = doc["ChargerID"];
          _stationId = doc["StationID"];
        });
        _fetchCharger();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

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
        elevation: 0, // Remove shadow
        leading: Container(), // Hide default back icon
      ),

      // Use a Column so content starts near the top
      body: Padding(
        padding: const EdgeInsets.only(left: 35, top: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Add some space below the AppBar
            const SizedBox(height: 40),

            // The charging image
            Image.asset(
              'images/startcharging.png',
              fit: BoxFit.contain,
              height: 180, // Adjust as needed
            ),
            const SizedBox(height: 20),

            // Bay name
            Text(
              _chargerName,
              style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 10),

            // Title
            const Text(
              "Start charging now",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),

            // Subtitle / instructions
            const Text(
              "Plug in the connector to start charging session",
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
