import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ezcharge/views/EZCHARGE/CheckInScreen.dart';
import 'package:ezcharge/views/EZCHARGE/TimerScreen.dart';

class ActivityScreen extends StatefulWidget {
  final int initialTabIndex;

  const ActivityScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

List<Map<String, dynamic>> _endedAttendances = [];

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  // UI timer to trigger periodic rebuilds so the elapsed time updates.
  Timer? _activityUITimer;
  String _customerId = "";
  String _chargerId = "";
  String _stationId = "";
  String _reservationStatus = "";
  String _stationName = "";
  String _chargerName = "";
  String _chargerType = "";
  String _chargerVoltage = " ";
  String _currentType = " ";
  String _pricepervoltage = " ";
  Timestamp _starttime = Timestamp.now();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _getCustomerID();

    // Set up a periodic timer to update the UI (so that elapsed time is refreshed).
    _activityUITimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activityUITimer?.cancel();
    super.dispose();
  }

  // Fetch current log in user id from Firestore
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
        setState(() {
          _customerId = querySnapshot.docs.first.id;
        });
        _fetchReservationRecord();
        _fetchEndedAttendances();
      }
    } catch (e) {
      print("Error fetching customer ID: $e");
    }
  }

//Fetch Reservation Record based on current sign in user
  Future<void> _fetchReservationRecord() async {
    if (_customerId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_customerId)
          .get();

      if (doc.exists) {
        setState(() {
          _chargerId = doc["ChargerID"];
          _stationId = doc["StationID"];
          _reservationStatus = doc["Status"];
          _starttime = doc["StartTime"];
        });
        _fetchStation();
        _fetchCharger();
      }
    } catch (e) {
      print("Error fetching reservation record: $e");
    }
  }

  Future<void> _fetchEndedAttendances() async {
    if (_customerId.isEmpty) return;

    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("CustomerID", isEqualTo: _customerId)
          .get();

      List<Map<String, dynamic>> attendances = [];

      for (var doc in snap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Retrieve StationID from the attendance document.
        String stationId = data["StationID"] ?? "";
        // Optionally, if you also store ChargerID in attendance:
        String chargerId = data["SlotID"] ?? "";

        // Fetch StationName from the station collection.
        String stationName = "";
        DocumentSnapshot stationDoc = await FirebaseFirestore.instance
            .collection("station")
            .doc(stationId)
            .get();
        if (stationDoc.exists) {
          stationName = stationDoc["StationName"] ?? "";
        }

        // Fetch ChargerName from the station's Charger subcollection (if ChargerID is available).
        String chargerName = "";
        if (chargerId.isNotEmpty) {
          DocumentSnapshot chargerDoc = await FirebaseFirestore.instance
              .collection("station")
              .doc(stationId)
              .collection("Charger")
              .doc(chargerId)
              .get();
          if (chargerDoc.exists) {
            chargerName = chargerDoc["ChargerName"] ?? "";
          }
        }

        // Add the fetched names to the attendance data.
        data["StationName"] = stationName;
        data["ChargerName"] = chargerName;
        attendances.add(data);
      }

      setState(() {
        _endedAttendances = attendances;
      });
    } catch (e) {
      print("Error fetching ended attendances: $e");
    }
  }

//Fetch station information based on the station id
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
        print("Fetched Station Name: $_stationName");
      }
    } catch (e) {
      print("Error fetching station: $e");
    }
  }

//Fetch charger information based on the station id and charger id
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
          _chargerVoltage = doc["ChargerVoltage"].toString();
          _currentType = doc["CurrentType"];
          _pricepervoltage = doc["PriceperVoltage"].toString();
        });
      }
    } catch (e) {
      print("Error fetching charger: $e");
    }
  }

  // Remove Reservation from Firestore
  Future<void> _cancelReservation() async {
    try {
      await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_customerId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reservation Cancelled!")),
      );

      setState(() {}); // Refresh UI.
    } catch (e) {
      print("Error deleting reservation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Charging",
          style: TextStyle(
              color: Colors.black, fontSize: 23, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          //Three tabs
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Active"),
            Tab(text: "Ended"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTab(),
          _buildActiveTab(),
          _buildEndedTab(),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    if (_reservationStatus != "Upcoming") {
      return const Center(child: Text("No upcoming reservations."));
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, spreadRadius: 1),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stationName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _chargerName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _chargerType,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "$_chargerVoltage $_currentType",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      "RM $_pricepervoltage/kW",
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // CHECK IN button.
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CheckInScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Text("CHECK IN",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // CANCEL RESERVE button.
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirm Cancellation'),
                                content: const Text(
                                    'Are you sure you want to cancel the reservation?'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('No'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('Yes'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _cancelReservation();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "CANCEL RESERVE",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_reservationStatus != "Active") {
      return const Center(child: Text("No active reservations."));
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GestureDetector(
            onTap: () {
              // Navigate to TimerScreen when tapped.
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TimerScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Station Name.
                  Text(
                    _stationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _chargerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _chargerType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        "$_chargerVoltage $_currentType",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Display the elapsed time from TimerService.
                      Text(
                        "${TimerService.hoursStr}:${TimerService.minutesStr}:${TimerService.secondsStr}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndedTab() {
    if (_endedAttendances.isEmpty) {
      return const Center(child: Text("No ended reservations."));
    }
    // Optionally, sort the list so the latest (by CheckOutTime) appears first:
    List sortedAttendances = List.from(_endedAttendances);
    sortedAttendances.sort((a, b) {
      DateTime aTime = a["CheckOutTime"] is Timestamp
          ? a["CheckOutTime"].toDate()
          : DateTime.now();
      DateTime bTime = b["CheckOutTime"] is Timestamp
          ? b["CheckOutTime"].toDate()
          : DateTime.now();
      return bTime.compareTo(aTime); // Latest first
    });

    return ListView.builder(
      itemCount: sortedAttendances.length,
      itemBuilder: (context, index) {
        final attendance = sortedAttendances[index];

        // Use fetched station and charger names (or fallback to the ID if empty)
        final stationName =
            attendance["StationName"] ?? attendance["StationID"] ?? "";
        final chargerName =
            attendance["ChargerName"] ?? attendance["ChargerID"] ?? "";

        final totalCost = attendance["TotalCost"]?.toString() ?? "0.00";
        final duration = attendance["Duration"] ?? "";
        final checkInTime = attendance["CheckInTime"];
        final checkOutTime = attendance["CheckOutTime"];

        // Convert Timestamps if present
        DateTime? checkInDateTime;
        if (checkInTime is Timestamp) {
          checkInDateTime = checkInTime.toDate();
        }
        DateTime? checkOutDateTime;
        if (checkOutTime is Timestamp) {
          checkOutDateTime = checkOutTime.toDate();
        }

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, spreadRadius: 1),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display StationName and ChargerName
                Text(
                  "Station: $stationName",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Charger: $chargerName",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text("Duration: $duration",
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      checkInDateTime != null
                          ? "CheckIn: ${checkInDateTime.toString().substring(0, 16)}"
                          : "CheckIn: -",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      checkOutDateTime != null
                          ? "CheckOut: ${checkOutDateTime.toString().substring(0, 16)}"
                          : "CheckOut: -",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "TotalCost: RM$totalCost",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
