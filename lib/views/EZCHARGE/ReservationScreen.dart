import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ezcharge/views/customer/customercontent/ActivityScreen.dart';

class ReservationScreen extends StatefulWidget {
  final String stationId;


  const ReservationScreen({super.key, required this.stationId});

  @override
  _ReservationScreenState createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  List<Map<String, dynamic>> chargers = [];
  String? selectedCharger;
  String? selectedChargerDocId;
  Timestamp selectedTime = Timestamp.now();
  bool isLoading = true;
  bool isTermsAccepted = false;
  String _accountId = "";

  @override
  void initState() {
    super.initState();
    _fetchChargers();
    _getCustomerID();
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
        }
      }
      _submitReservation();
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  /// 🔹 Fetch Chargers from Firestore
  Future<void> _fetchChargers() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("station")
          .doc(widget.stationId)
          .collection("Charger")
          .get();

      setState(() {
        chargers = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            "bay": data["ChargerName"] ?? "Unknown Bay",
            "type": data["ChargerType"] ?? "Unknown Type",
            "power": "${data["ChargerVoltage"] ?? "0"}kW ${data["CurrentType"] ?? ""}",
            "price": "RM ${data["PriceperVoltage"] ?? "0.00"}/kW",
            "status": data["Status"] ?? "Unknown",
            "docId": doc.id, // Store Firestore document ID
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching chargers: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final initialTime = TimeOfDay.fromDateTime(selectedTime.toDate());
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final now = DateTime.now();
      final DateTime pickedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      // Convert DateTime to Firestore Timestamp
      final Timestamp pickedTimestamp = Timestamp.fromDate(pickedDateTime);

      // 🔹 Ensure a charger is selected before checking Firestore
      if (selectedCharger == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a charger first!")),
        );
        return;
      }

      // Debugging Log
      print("Checking reservations for Charger: $selectedCharger at $pickedDateTime");

      // Check Firestore for existing reservations
      bool isSlotTaken = await _checkExistingReservation(selectedCharger!, pickedTimestamp);

      if (isSlotTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The slot has been selected by others!")),
        );
      } else {
        setState(() {
          selectedTime = pickedTimestamp;
        });
      }
    }
  }

  //Function to Check Firestore for Existing Reservations
  Future<bool> _checkExistingReservation(String chargerId, Timestamp selectedTimestamp) async {
    try {
      //Query Firestore for the same charger and start time
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("reservation")
          .where("ChargerID", isEqualTo: chargerId)
          .get();  // Fetch all reservations for this charger

      for (var doc in querySnapshot.docs) {
        var reservationData = doc.data() as Map<String, dynamic>;
        Timestamp storedTimestamp = reservationData["StartTime"];

        //Debugging Log
        print("Found reservation: ${reservationData["StartTime"]}");

        // Compare timestamps properly
        if (storedTimestamp.seconds == selectedTimestamp.seconds) {
          return true;  // Slot is taken
        }
      }

      return false; // Slot is available
    } catch (e) {
      print("Error checking reservations: $e");
      return false;
    }
  }

  //Submit Reservation to Firestore
  Future<void> _submitReservation() async {
    if (selectedCharger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a charger!")),
      );
      return;
    }

    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please accept the terms and conditions!")),
      );
      return;
    }

    try {
      String reservationId = "RSV${DateTime.now().millisecondsSinceEpoch}";
      // Add Reservation Record to Firestore with the new StartTime.
      await FirebaseFirestore.instance.collection("reservation").doc(_accountId).set({
        "ReservationID": reservationId,
        "ChargerID": selectedCharger,
        "StationID": widget.stationId,
        "StartTime": selectedTime,
        "ReservedTime": DateTime.now(),
        "Status": "Upcoming",
        "CustomerID": _accountId, // Replace with actual user ID if available.
      });

      //Navigate to Success Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => _buildSuccessScreen(context)),
      );
    } catch (e) {
      print("Error submitting reservation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to reserve the charger. Try again!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // 🔹 App Bar
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue, // Blue background
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Reservation",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),


            const SizedBox(height: 20),

            // 🔹 Provided Charger List
            const Text("Provided Charger",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...chargers.map((charger) => _buildChargerCard(charger)),

            const SizedBox(height: 20),

            // 🔹 Time Picker
            const Text("Select Time",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _selectTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat.jm().format(selectedTime.toDate()),
                    ),

                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.blue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Terms & Conditions
            Row(
              children: [
                Checkbox(
                  value: isTermsAccepted,
                  onChanged: (value) {
                    setState(() {
                      isTermsAccepted = value!;
                    });
                  },
                ),
                const Text("I accept the Terms & Conditions"),
              ],
            ),

            const SizedBox(height: 20),

            // 🔹 Reserve Button (Disabled Until Conditions Met)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (selectedCharger != null && isTermsAccepted)
                    ? _submitReservation
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  (selectedCharger != null && isTermsAccepted) ? Colors.blue : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text("RESERVE", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Build Charger Card UI
  Widget _buildChargerCard(Map<String, dynamic> charger) {
    bool isAvailable = charger["status"] == "Available";
    return GestureDetector(
      onTap: isAvailable
          ? () {
        setState(() {
          selectedCharger = charger["docId"];
        });
      }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selectedCharger == charger["docId"] ? Colors.blue : Colors.grey),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: charger["docId"],
              groupValue: selectedCharger,
              onChanged: isAvailable
                  ? (value) {
                setState(() {
                  selectedCharger = value;
                });
              }
                  : null,
            ),
            Text(charger["bay"]),
            const Spacer(),
            Text(charger["power"]),
            const SizedBox(width: 10),
            Text(charger["status"],
                style: TextStyle(color: isAvailable ? Colors.green : Colors.orange)),
          ],
        ),
      ),
    );
  }

  /// 🔹 Success Screen
  Widget _buildSuccessScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White Background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // "The slot is booked" Title
            const Text(
              "The slot is booked",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Green Check Icon
            const Icon(Icons.check_circle, color: Colors.green, size: 100),

            const SizedBox(height: 20),

            // Success Message
            const Text(
              "The slot is successfully reserved\nPlease ensure you arrive on time!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 40),

            // "FINISH" Button (Larger & Styled)
            SizedBox(
              width: 200, //Adjusted Width
              height: 45, //Adjusted Height
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const ActivityScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  "FINISH",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}