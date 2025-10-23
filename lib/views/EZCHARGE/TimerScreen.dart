import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ezcharge/views/EZCHARGE/StopCharging.dart';
import 'package:ezcharge/views/customer/Service/ChatbotScreen.dart';
import 'package:ezcharge/views/customer/customercontent/ActivityScreen.dart';

// A shared timer service that holds the timer state independently.
class TimerService {
  static DateTime? startTime;
  static Timer? timer;
  static int elapsedSeconds = 0;

  static void startTimer(Function onTimeLimitReached) {
    // Start timer only once.
    if (startTime == null) {
      startTime = DateTime.now();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        elapsedSeconds++;
        if (elapsedSeconds >= 60) {
          onTimeLimitReached();
        }
      });
    }
  }

  static void stopTimer() {
    timer?.cancel();
    timer = null;
  }

  static String get hoursStr =>
      (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
  static String get minutesStr =>
      ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
  static String get secondsStr =>
      (elapsedSeconds % 60).toString().padLeft(2, '0');
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({Key? key}) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // A separate UI timer to trigger setState so that the displayed time updates.
  Timer? _uiTimer;
  String _accountId = "";
  String _chargerId = "";
  String _stationId = "";
  String _chargerName = "";
  String _chargerType = "";
  String _stationName = "";
  String _reservationStatus = "";

  @override
  void initState() {
    super.initState();
    // Start the shared timer if it hasn't been started.
    TimerService.startTimer(_handleTimeLimitReached);
    // Set up a UI update timer.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
    _getCustomerID();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    // Do NOT stop the shared TimerService here so that the timer continues.
    super.dispose();
  }

  Future<void> _handleTimeLimitReached() async {
    try {
      await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .update({"Status": "Ended"});

      final stopTime = DateTime.now();
      final totalDuration = stopTime.difference(
        TimerService.startTime ?? stopTime,
      );

      TimerService.stopTimer();
      TimerService.startTime = null;
      TimerService.elapsedSeconds = 0;


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StopChargingScreen(
            totalDuration: totalDuration,
          ),
        ),
      );
    } catch (e) {
      print("Error updating reservation status: $e");
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
      //Fetch reservation document for the user
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _chargerId = doc["ChargerID"];
          _stationId = doc["StationID"];
          _reservationStatus = doc["Status"];
        });
        _fetchStation();
        _fetchCharger();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  Future<void> _fetchStation() async {
    if (_stationId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .get();

      if (doc.exists) {
        setState(() {
          _stationName = doc["StationName"];
        });
      }
    } catch (e) {
      print("Error fetching station: $e");
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
          _chargerType = doc["ChargerType"];
        });
      }
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  // Show the bottom sheet to stop charging.
  Future<void> _showStopChargingSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              const Text(
                "Stop charging?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Final amount charged will be based on your total duration. "
                    "You can check on the rates first before confirming.",
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Button background color
                        foregroundColor: Colors.white, // Text color
                      ),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection("reservation")
                              .doc(_accountId)
                              .update({"Status": "Ended"});

                          TimerService.stopTimer();

                          final stopTime = DateTime.now();
                          final totalDuration = stopTime.difference(
                            TimerService.startTime ?? stopTime,
                          );

                          TimerService.startTime = null;
                          TimerService.elapsedSeconds = 0;

                          Navigator.pop(context);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StopChargingScreen(
                                totalDuration: totalDuration,
                              ),
                            ),
                          );
                        } catch (e) {
                          print("Error updating reservation status: $e");
                        }
                      },
                      child: const Text("STOP CHARGING"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context); // Just close bottom sheet.
                      },
                      child: const Text("CANCEL"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dark blue background
      backgroundColor: Colors.blue[900],

      // AppBar with same dark blue background
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.white,
          ),
          onPressed: () {
            // Navigate to ActivityScreen's active tab without stopping the timer.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityScreen(initialTabIndex: 1),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      Chatbotscreen(), // Replace with your target page widget
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.support_agent, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "Help",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Use a Stack to layer the circle, the lightning icon, and the white container.
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Large circle
            Container(
              width: 900,
              height: 1000,
              decoration: const BoxDecoration(
                color: Colors.blue, // A lighter/brighter blue for contrast
                shape: BoxShape.circle,
              ),
            ),

            // White lightning icon on top of the circle
            Transform.translate(
              offset: const Offset(
                  -30, 0), // negative X moves it left, adjust as needed
              child: const Icon(
                Icons.bolt,
                size: 480,
                color: Colors.white,
              ),
            ),

            // White container with timer info on top of the lightning icon
            Container(
              width: 260,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _stationName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _chargerName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  // Timer Display
                  Text(
                    "${TimerService.hoursStr} : ${TimerService.minutesStr} : ${TimerService.secondsStr}",
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Connector: $_chargerType"),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom nav bar with "STOP CHARGING"
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: _showStopChargingSheet,
            child: const Text(
              "STOP CHARGING",
              style: TextStyle(
                fontSize: 20,
                color: Colors.lightBlueAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
