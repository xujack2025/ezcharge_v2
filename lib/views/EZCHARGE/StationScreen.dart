import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ezcharge/views/EZCHARGE/ReservationScreen.dart';
import 'package:ezcharge/views/EZCHARGE/ReviewScreen.dart';
import 'package:ezcharge/views/EZCHARGE/map_utlis.dart';
import 'package:ezcharge/views/customer/rating/customer_complaint.dart';
import 'package:ezcharge/views/customer/rating/customer_rating.dart';
import 'package:ezcharge/views/customer/rating/customer_review.dart';

class StationScreen extends StatefulWidget {
  final String stationId;

  const StationScreen({super.key, required this.stationId});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  Map<String, dynamic>? stationData;
  List<Map<String, dynamic>> chargerList = [];
  bool isLoading = true;
  String _accountId = "";
  String _authStatus = "";
  String _reservationStatus = "";
  List<double> busyTimes = List.filled(24, 0.0); // 24 hourly slots
  int currentHour = DateTime.now()
  /*.toUtc()*/
  /*.add(Duration(hours: 8))*/
      .hour; // Get current hour in UTC+8
  String trafficStatus = "Same as usual"; // Default status
  List<Map<String, dynamic>> reviewsList = [];

  String _formatReviewDate(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) {
      return "Unknown Date"; // Handle null & invalid types
    }

    DateTime reviewDate = timestamp.toDate();
    Duration difference = DateTime.now().difference(reviewDate);

    if (difference.inDays < 60) {
      return "${(difference.inDays / 30).floor()} months ago";
    } else {
      return DateFormat("dd/MM/yyyy").format(reviewDate);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchStationDetails();
    _getCustomerID();
    fetchBusyTimes(widget.stationId);
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection("reviews")
        .where("StationID",
        isEqualTo: widget.stationId) // Filter reviews by station
        .orderBy("ReviewDate", descending: true) // Show latest reviews first
        .get();

    setState(() {
      reviewsList = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  void fetchBusyTimes(String stationId) {
    FirebaseFirestore.instance
        .collection('attendance')
        .where('StationID', isEqualTo: stationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        // ✅ If no data, ensure the first hour has a minimum bar
        setState(() {
          busyTimes = List.filled(24, 0.2); // ✅ Set at least 0.2 for all bars
          trafficStatus = "No data available"; // ✅ Display message
        });
        return;
      }

      List<double> hourlyUsage = List.filled(24, 0.0);

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();

        // ✅ Convert Firestore timestamp to UTC+8
        DateTime checkInTime =
        (data['CheckInTime'] as Timestamp).toDate() /*.toUtc()*/;
        /*.add(Duration(hours: 8));*/

        int hour = checkInTime.hour; // Get hour in UTC+8
        hourlyUsage[hour] += 1; // Increase count for that hour
      }

      double maxUsage = hourlyUsage.reduce((a, b) => a > b ? a : b);
      double totalUsage = hourlyUsage.reduce((a, b) => a + b);
      double avgUsage =
      totalUsage > 0 ? totalUsage / 24 : 0; // ✅ Prevent division by zero

      // ✅ Ensure at least 0.2 height for all bars (so they are visible)
      setState(() {
        busyTimes = maxUsage > 0
            ? hourlyUsage.map((val) => (val / maxUsage) * 10).toList()
            : List.filled(24, 0.2); // ✅ Minimum bar height
        trafficStatus = totalUsage == 0
            ? "No data available"
            : (hourlyUsage[currentHour] >= avgUsage * 1.2
            ? "Busy time"
            : (hourlyUsage[currentHour] <= avgUsage * 0.8
            ? "Less people"
            : "Same as usual"));
      });
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
          _fetchAuthenticationStatus();
          _fetchReservationStatus();
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  Future<void> _fetchAuthenticationStatus() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("authenticate")
          .doc("authentication")
          .get();

      if (doc.exists) {
        setState(() {
          _authStatus = doc["Status"];
        });
      }
    } catch (e) {
      print("Error fetching authentication status: $e");
    }
  }

  Future<void> _fetchReservationStatus() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _reservationStatus = doc["Status"] ?? "";
        });
      }
    } catch (e) {
      print("Error fetching reservation status: $e");
    }
  }

  //Fetch station details from Firestore
  Future<void> _fetchStationDetails() async {
    try {
      // Fetch Station Data
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("station")
          .doc(widget.stationId)
          .get();

      if (doc.exists) {
        setState(() {
          stationData = doc.data() as Map<String, dynamic>;
        });
      }

      // Fetch Chargers from Firestore
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("station")
          .doc(widget.stationId)
          .collection("Charger")
          .get();

      int availableChargers = 0; // ✅ Count available chargers

      chargerList = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        bool isAvailable = data["Status"] == "Available";

        if (isAvailable) availableChargers++; // ✅ Count only available chargers

        return {
          "bay": data["ChargerName"] ?? "Unknown Bay",
          "type": data["ChargerType"] ?? "Unknown Type",
          "power":
          "${data["ChargerVoltage"] ?? "0"}kW ${data["CurrentType"] ?? ""}",
          "price": "RM ${data["PriceperVoltage"] ?? "0.00"}/kW",
          "status": data["Status"] ?? "Unknown",
        };
      }).toList();

      // If the Capacity has changed, update Firestore
      if (stationData?["Capacity"] != availableChargers) {
        await FirebaseFirestore.instance
            .collection("station")
            .doc(widget.stationId)
            .update({"Capacity": availableChargers});
      }

      // 🔹 Update UI with the new capacity
      setState(() {
        stationData?["Capacity"] = availableChargers;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching station details: $e");
      setState(() => isLoading = false);
    }
  }

  void _showMoreOptions(BuildContext context, Map<String, dynamic> station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomSheetButton(
                icon: Icons.reviews,
                text: "Review",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReviewPage(
                            stationId: widget.stationId,
                            stationName:
                            stationData?["StationName"] ?? "Unknown Station",
                            stationDescription: stationData?["Description"] ??
                                "No description available",
                            stationImage: stationData?["ImageUrl"] ??
                                "https://via.placeholder.com/150",
                          ),
                    ),
                  );
                },
              ),
              _buildBottomSheetButton(
                icon: Icons.report,
                text: "Report",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CustomerComplaintPage(
                            stationId: widget.stationId,
                            stationName:
                            stationData?["StationName"] ?? "Unknown Station",
                            stationDescription: stationData?["Description"] ??
                                "No description available",
                            stationImage: stationData?["ImageUrl"] ??
                                "https://via.placeholder.com/150",
                          ),
                    ),
                  );
                },
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
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStationDetails(),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildBottomSheetButton({required IconData icon,
    required String text,
    required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //Build Station Details (Matching Image Design)
  Widget _buildStationDetails() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //Station Image
          Stack(
            children: [
              //Background Image
              Image.network(
                stationData?["ImageUrl"] ?? "https://via.placeholder.com/80",
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),

              //Back Button (Top Left)
              Positioned(
                top: 20,
                left: 15,
                child: GestureDetector(
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
              ),

              //More Button (Top Right)
              Positioned(
                top: 20,
                right: 15,
                child: GestureDetector(
                  onTap: () {
                    _showMoreOptions(context, stationData!); //Pass station data
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          // Station Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge + Distance
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text("Coffee Shop",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Station Name
                Text(
                  stationData?["StationName"] ?? "Charging Station",
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),

                // Location Description
                Text(
                  stationData?["Description"] ?? "Location details",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 5),

                // Availability & Icon
                Row(
                  children: [
                    const Text("Available",
                        style: TextStyle(color: Colors.green, fontSize: 16)),
                    const SizedBox(width: 5),
                    const Icon(Icons.bolt, color: Colors.green, size: 18),

                    // Display Capacity from Firestore
                    Text(
                      " ${stationData?["Capacity"] ?? 0} ",
                      //Dynamically updated based on available chargers
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),

                    const Icon(Icons.ev_station, color: Colors.black, size: 18),
                  ],
                ),
              ],
            ),
          ),
          // Provided Chargers List
          _buildChargerList(),
          const SizedBox(height: 10),

          // Busy Times Chart
          _buildBusyTimesChart(),
          const SizedBox(height: 10),

          _buildReviewsSection(),
          const SizedBox(height: 10),

          // Location Info
          _buildLocationInfo(),
          const SizedBox(height: 20),

          _buildOperationInfo(),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Recent Reviews Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Reviews",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to full review page
                },
                child: const Text(
                  "ALL REVIEWS",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔹 Show message if no reviews
          if (reviewsList.isEmpty)
            const Text(
              "No reviews yet.",
              style: TextStyle(color: Colors.grey),
            ),

          // 🔹 Show list of reviews
          ...reviewsList.map((review) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              // Spacing between reviews
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⭐ Star Rating + Review Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Star Ratings
                      Row(
                        children: List.generate(5, (index) {
                          int rating = (review["Rating"] as num?)?.toInt() ??
                              0; // Ensure it's a number
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),

                      // Review Date
                      Text(
                        _formatReviewDate(review["ReviewDate"]),
                        style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // 📝 Review Text
                  Text(
                    review["ReviewText"]?.toString() ?? "No comment",
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 5),

                  // 🚗 Car Model (or User ID if missing)
                  Text(
                    review["CarModel"] ??
                        review["CustomerID"] ??
                        "Unknown User",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Divider Line
                  const Divider(thickness: 0.5, color: Colors.grey),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  //Charger List Section (Matching Image)
  Widget _buildChargerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Provided Charger",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...chargerList.map((charger) => _buildChargerCard(charger)),
        ],
      ),
    );
  }

  //Charger Card UI (Matching Image)
  Widget _buildChargerCard(Map<String, dynamic> charger) {
    bool isAvailable = charger["status"] == "Available";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isAvailable ? Colors.green : Colors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Row: Charger Bay Name, Type & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(charger["bay"],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(charger["type"]),
                Text(
                  charger["status"],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5), // Space between rows

            //Second Row: Charger Voltage & Current Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(charger["power"],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),

            //Third Row: Charger Price
            Text(
              charger["price"],
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  //Busy Times Chart (Mocked)
  Widget _buildBusyTimesChart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Title
            const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "Busy Times",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ✅ Current Time Subtitle (Dynamic)
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "${DateFormat.jm().format(DateTime
                      .now() /*.toUtc()*/ /*.add(const Duration(hours: 8))*/)}: ",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                      fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  trafficStatus,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ✅ Centered Chart inside Scrollable View
            SizedBox(
              width: double.infinity, // ✅ Makes the chart fit the screen
              height: 150, // ✅ Fixed height
              child: BarChart(
                BarChartData(
                  maxY: 15,
                  // Normalize bar height
                  barGroups: _getBarChartData(),
                  titlesData: FlTitlesData(
                    leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          int hour24 =
                          value.toInt(); // Convert to integer hour (0-23)

                          // ✅ Convert 24-hour format to 12-hour format
                          String hourLabel;
                          if (hour24 == 0) {
                            hourLabel = "12 AM";
                          } else if (hour24 == 12) {
                            hourLabel = "12 PM";
                          } else if (hour24 < 12) {
                            hourLabel = "$hour24 AM";
                          } else {
                            hourLabel = "${hour24 - 12} PM";
                          }

                          // ✅ Show labels for every 4 hours + last hour (11 PM)
                          if (hour24 % 4 == 0 || hour24 == 23) {
                            return Column(
                              children: [
                                const SizedBox(height: 2),
                                Container(
                                  width: 2,
                                  height: 6,
                                  color:
                                  Colors.black54, // 🔹 Tick mark under bar
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hourLabel,
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          } else {
                            return const SizedBox
                                .shrink(); // Hide unnecessary labels
                          }
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                          color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Generate Bar Chart Data
  List<BarChartGroupData> _getBarChartData() {
    return List.generate(busyTimes.length, (index) {
      double barHeight = busyTimes[index] > 0
          ? busyTimes[index]
          : 0.2; // ✅ Ensure visible bars

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: barHeight, // ✅ Prevent zero-height bars
            width: 13,
            borderRadius: BorderRadius.circular(3),
            color: index == currentHour
                ? Colors.purple.shade300
                : Colors.lightBlue,
          ),
        ],
        barsSpace: 0,
      );
    });
  }

  Widget _buildLocationInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start, // ✅ Ensures left alignment
        children: [
          const Text(
            "Location Info",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.left, // ✅ Explicitly aligns text left
          ),
          const SizedBox(height: 10),
          Text(
            stationData?["Location"] ??
                "Location not available", // ✅ Fixes data fetch
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.left, // ✅ Ensures text aligns left
          ),
        ],
      ),
    );
  }

  Widget _buildOperationInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ✅ Left Align
        children: [
          const Text(
            "Operation",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // ✅ Space Between Boxes
            children: [
              // 🔹 Operation Hours Box
              _buildInfoBox("Operation Hour", "24 Hours"),

              // 🔹 24-hour Hotline Box (Tap to Call)
              GestureDetector(
                onTap: () => launch('tel: +03-123456789'), // ✅ Call when tapped
                child: _buildInfoBox("24-hours Hotline", "03-123456789"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //Helper Widget to Create Box UI
  Widget _buildInfoBox(String title, String value) {
    return Container(
      width: 170, // Set Width
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey), // Grey Border
        borderRadius: BorderRadius.circular(10), // Rounded Corners
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Left Align Text
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  bool _isReserveButtonEnabled() {
    // Must pass authentication
    if (_authStatus != "Pass") return false;
    // Must not have upcoming or active reservation
    if (_reservationStatus == "Upcoming" || _reservationStatus == "Active") {
      return false;
    }

    return true;
  }

  void _showReservationReminder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Existing Reservation"),
            content: const Text(
              "You already have an upcoming or active reservation.\n"
                  "Please complete or cancel it before making a new one.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  void _showAuthReminder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Authentication Required"),
            content: const Text(
                "Please authenticate your account before making a reservation."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Close dialog
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  //Bottom Action Buttons (Matching Image)
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 4) Bring Me There button (unchanged)
          ElevatedButton(
            onPressed: () {
              // Safely read and parse the latitude/longitude strings
              final latString = stationData?["Latitude"]?.toString() ?? '';
              final lngString = stationData?["Longitude"]?.toString() ?? '';

              // Attempt to parse them as double
              final lat = double.tryParse(latString);
              final lng = double.tryParse(lngString);

              if (lat != null && lng != null) {
                // If parsing succeeded, open the map
                MapUtlis.openMap(lat, lng);
              } else {
                // Handle the error case if lat or lng couldn't be parsed
                print("Error: Could not parse latitude/longitude");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              "BRING ME THERE",
              style: TextStyle(color: Colors.white),
            ),
          ),

          //Reserve button with checks
          ElevatedButton(
            onPressed: () {
              // a) If user is not authenticated
              if (_authStatus != "Pass") {
                _showAuthReminder(context);
                return;
              }
              // b) If user already has an upcoming or active reservation
              if (_reservationStatus == "Upcoming" ||
                  _reservationStatus == "Active") {
                _showReservationReminder(context);
                return;
              }

              // Otherwise, proceed to ReservationScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReservationScreen(stationId: widget.stationId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isReserveButtonEnabled()
                  ? Colors.blue
                  : Colors.grey, // Grey if disabled
            ),
            child: const Text("RESERVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
