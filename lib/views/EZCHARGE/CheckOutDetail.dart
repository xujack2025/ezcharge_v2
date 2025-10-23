import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:ezcharge/views/EZCHARGE/CheckOutSuccessScreen.dart';
import 'package:ezcharge/views/customer/Service/ChatbotScreen.dart';

class CheckOutDetailScreen extends StatefulWidget {
  final Duration totalDuration; // Passed in from Timer/StopCharging screen

  const CheckOutDetailScreen({
    super.key,
    required this.totalDuration,
  });

  @override
  State<CheckOutDetailScreen> createState() => _CheckOutDetailScreenState();
}

class _CheckOutDetailScreenState extends State<CheckOutDetailScreen> {
  String _accountId = "";
  String _chargerId = "";
  String _stationId = "";
  String _reservationId = "";
  String _reservationStatus = "";
  String _stationName = "";
  String _chargerName = "";
  String _chargerType = "";
  String _currentType = "";
  String _chargerVoltage = "0";
  String _pricepervoltage = "0";
  Timestamp _startTime = Timestamp.now();

  bool isLoading = false;

  Timer? _countdownTimer;
  int _remainingSeconds = 10; // 5 minutes = 300 seconds
  int _overTimeMinutes = 0; // Once we go past 5 minutes
  double _penalty = 0; // RM10 per overtime minute

  @override
  void initState() {
    super.initState();
    _getCustomerID();

    // Start the countdown logic for the 5-minute grace period
    _startCountdown();
  }

  @override
  void dispose() {
    // Cancel the countdown timer when leaving the screen
    _countdownTimer?.cancel();
    super.dispose();
  }

  //Start the 5-minute countdown. After it hits 0, we track overtime.
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          // Still within the 5-minute window
          _remainingSeconds--;
        } else {
          // Now in overtime
          final totalOverSeconds = -_remainingSeconds; // negative
          final newOverTimeMinutes = totalOverSeconds ~/ 60;

          // Each time we enter a new full minute of overtime, show a warning
          if (newOverTimeMinutes > _overTimeMinutes) {
            _overTimeMinutes = newOverTimeMinutes;
            _penalty = _overTimeMinutes * 10; // 10 ringgit per minute

            // Show a SnackBar to alert the user about the new penalty
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "You are $_overTimeMinutes minute(s) overdue.\n"
                  "Current penalty: RM$_penalty",
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Keep counting further into negative to track totalOverSeconds
          _remainingSeconds--;
        }
      });
    });
  }

  // Build a widget that shows either the countdown or the overtime status
  Widget _buildCountdownWidget() {
    if (_remainingSeconds >= 0) {
      // Still have time left
      final minutesLeft = _remainingSeconds ~/ 60;
      final secondsLeft = _remainingSeconds % 60;
      final formatted = "${minutesLeft.toString().padLeft(2, '0')}"
          ":${secondsLeft.toString().padLeft(2, '0')}";
      return Text(
        "⚠ You still have $formatted minutes to check out from the slot.",
        style: const TextStyle(color: Colors.orange),
      );
    } else {
      // Overtime
      return Text(
        "Overtime: $_overTimeMinutes minute(s)\n"
        "Current penalty: RM$_penalty",
        style: const TextStyle(color: Colors.red),
      );
    }
  }

  // Get the logged-in user's CustomerID
  Future<void> _getCustomerID() async {
    setState(() {
      isLoading = true;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isNotEmpty) {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection("customers")
              .where("PhoneNumber", isEqualTo: userPhone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            var userDoc = querySnapshot.docs.first;
            _accountId = userDoc["CustomerID"];
            await _fetchReservationRecord();
          }
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
    setState(() {
      isLoading = false;
    });
  }

  //Fetch the reservation record for the user
  Future<void> _fetchReservationRecord() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        _chargerId = doc["ChargerID"] ?? "";
        _stationId = doc["StationID"] ?? "";
        _reservationId = doc["ReservationID"] ?? "";
        _reservationStatus = doc["Status"] ?? "";
        _startTime = doc["StartTime"] ?? Timestamp.now();

        await _fetchStation();
        await _fetchCharger();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  // Fetch station details
  Future<void> _fetchStation() async {
    if (_stationId.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .get();

      if (doc.exists) {
        _stationName = doc["StationName"] ?? "";
      }
    } catch (e) {
      print("Error fetching station: $e");
    }
  }

  //Fetch charger details (including ChargerVoltage)
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
        _chargerName = doc["ChargerName"] ?? "";
        _chargerType = doc["ChargerType"] ?? "";
        _pricepervoltage = doc["PriceperVoltage"]?.toString() ?? "0";
        _chargerVoltage = doc["ChargerVoltage"]?.toString() ?? "0";
        _currentType = doc["CurrentType"] ?? "";
      }
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  //Calculate total amount: (duration in hours) * PriceperVoltage * ChargerVoltage
  double _calculateTotalAmount() {
    double price = double.tryParse(_pricepervoltage) ?? 0.0;
    double voltage = double.tryParse(_chargerVoltage) ?? 0.0;
    double hours = widget.totalDuration.inSeconds / 3600.0;
    return hours * price * voltage;
  }

  double _calculateEnergyUsed() {
    double voltage = double.tryParse(_chargerVoltage) ?? 0.0;
    double hours = widget.totalDuration.inSeconds / 3600.0;
    return hours * voltage;
  }

  //Format the passed Duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  //Handle final check-out, update reservation status and navigate away.
  Future<void> _handleCheckOut(durationString, totalAmount) async {
    // Stop the countdown timer so it doesn't keep running after checkout
    _countdownTimer?.cancel();
    final EnergyUsed = _calculateEnergyUsed();
    // Only proceed if the reservation status is "Ended"
    if (_reservationStatus != 'Ended') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Cannot create attendance record until reservation is Ended."),
        ),
      );
      return;
    }

    try {
      final sessionID = "SSN${DateTime.now().millisecondsSinceEpoch}";
      await FirebaseFirestore.instance
          .collection("attendance")
          .doc(sessionID)
          .set({
        "CheckInTime": _startTime, // Assuming _startTime is already a Timestamp
        "CheckOutTime": Timestamp.fromDate(DateTime.now()),
        "ChargerType": _chargerType,
        "ChargerVoltage": _chargerVoltage,
        "CurrentType": _currentType,
        "Duration": durationString,
        "CustomerID": _accountId,
        "EnergyUsed": double.parse(EnergyUsed.toStringAsFixed(2)),
        "ReservationID": _reservationId,
        "SessionID": sessionID,
        "SlotID": _chargerId,
        "StationID": _stationId,
        "TotalCost": double.parse((totalAmount + _penalty).toStringAsFixed(2))
      });
      await FirebaseFirestore.instance
          .collection("station")
          .doc(_stationId)
          .collection("Charger")
          .doc(_chargerId)
          .update({
        "Status": "Available",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Check-out successful!")),
      );
    } catch (e) {
      print("Error creating attendance record: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Check-out failed. Try again!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationString = _formatDuration(widget.totalDuration);
    final totalAmount = _calculateTotalAmount();

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: back button + "Check In"
                      Row(
                        children: [
                          const SizedBox(width: 5),
                          const Text(
                            "Check Out",
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      // Right side: "Help"
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Chatbotscreen()),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.support_agent,
                                color: Colors.blue,
                                size: 30,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Help",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Display image
                  Center(
                    child: Image.asset(
                      'images/charging.png',
                      fit: BoxFit.contain,
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reservation details
                  _infoRow("Charging Station:", _stationName),
                  _infoRow("Charging Slot:", _chargerName),
                  _infoRow("Charger Type:", _chargerType),
                  _infoRow("Price per KWH:", "RM$_pricepervoltage"),
                  _infoRow(
                    "Reserved Time:",
                    DateFormat('yyyy-MM-dd HH:mm').format(_startTime.toDate()),
                  ),
                  const SizedBox(height: 10),

                  // Session details
                  _infoRow("Total Duration:", durationString),
                  _infoRow(
                    "Total Amount:",
                    "RM ${totalAmount.toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 20),

                  // Check Out button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Check Out"),
                              content: const Text(
                                "Are you sure you want to check out from the slot?\n"
                                "Once check out, you need to reserve a slot for charging.",
                              ),
                              actions: [
                                TextButton(
                                  child: const Text("NO"),
                                  onPressed: () {
                                    Navigator.of(context)
                                        .pop(); // Close the dialog
                                  },
                                ),
                                TextButton(
                                  child: const Text("YES"),
                                  onPressed: () async {
                                    Navigator.of(context)
                                        .pop(); // Close the dialog
                                    try {
                                      // Execute checkout logic
                                      _handleCheckOut(
                                          durationString, totalAmount);

                                      // After successful checkout, navigate to CheckOutSuccessScreen
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CheckOutSuccessScreen(
                                                  chargingCost:
                                                      totalAmount, // Ensure totalAmount is defined and valid
                                                  penaltyCost:
                                                      _penalty, // Ensure _penalty has the correct value
                                                  duration: durationString),
                                        ),
                                      );
                                    } catch (error) {
                                      print("Error during checkout: $error");
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Checkout failed: $error")),
                                      );
                                    }
                                  },
                                )
                              ],
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text(
                        "CHECK OUT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  //Dynamic countdown or overtime display
                  _buildCountdownWidget(),
                ],
              ),
            ),
    );
  }

  //Helper widget to display a row of info
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
