import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ChargingUsageReport extends StatefulWidget {
  const ChargingUsageReport({super.key});

  @override
  State<ChargingUsageReport> createState() => _ChargingUsageReportState();
}

class _ChargingUsageReportState extends State<ChargingUsageReport> {
  bool isLoading = false; // Loading indicator

  String? selectedStationId;
  String? selectedStationLocation;
  String? adminNameAndID;
  DateTimeRange? selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchAdminDetails();
  }

  /// **Fetch the Current Admin's Name & ID using Phone Number**
  Future<void> _fetchAdminDetails() async {
    try {
      // ✅ Get the currently logged-in user from Firebase Auth
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.phoneNumber == null) {
        print("❌ No admin is logged in or phone number is not available.");
        return;
      }

      String phoneNumber = user.phoneNumber!; // ✅ Get phone number

      // ✅ Fetch admin details from Firestore using the phone number
      final adminQuery = await FirebaseFirestore.instance
          .collection('admins') // ✅ Ensure correct collection name
          .where('PhoneNumber',
              isEqualTo: phoneNumber) // ✅ Search by phone number
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        final adminData = adminQuery.docs.first.data();

        print("✅ Admin Data Retrieved: $adminData"); // 🔹 Debugging output

        if (mounted) {
          setState(() {
            adminNameAndID =
                "${adminData['FirstName']} (#${adminData['AdminID']})"; // ✅ Corrected format
          });
        }
      } else {
        print("❌ Admin data not found for phone number: $phoneNumber");
      }
    } catch (e) {
      print("❌ Error fetching admin details: $e");
    }
  }

  /// **Fetch Charging Station Details (ID & Location)**
  Future<void> _fetchStationDetails(String stationId) async {
    try {
      final stationSnapshot = await FirebaseFirestore.instance
          .collection('station') // ✅ Ensure correct collection name
          .doc(stationId)
          .get();

      if (stationSnapshot.exists) {
        setState(() {
          selectedStationLocation = stationSnapshot.data()?['Location'] ??
              'Not Found'; // ✅ Check correct field name
        });
      } else {
        setState(() {
          selectedStationLocation = 'Not Found';
        });
      }
    } catch (e) {
      print("❌ Error fetching station details: $e");
      setState(() {
        selectedStationLocation = 'Error loading location';
      });
    }
  }

  /// **Fetch & Generate the PDF Report**
  Future<void> _generateAndPrintReport() async {
    if (selectedStationId == null || selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select a station and date range.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final pdf = pw.Document();
      final data = await _fetchAnalyticsData(); // Fetch Firestore data

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildReportHeader(), // Title & Header
            _buildStationDetails(), // Station Info
            _buildSummarySection(data), // Summary Data
            _buildPeakHourChart(data), // Peak Hour Chart
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print("❌ Report generation failed: $e");
    }

    setState(() => isLoading = false);
  }

  /// **Fetch Charging Sessions for the Selected Station & Date Range**
  Future<Map<String, dynamic>> _fetchAnalyticsData() async {
    DateTime adjustedEndDate = selectedDateRange!.end.add(Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where("StationID", isEqualTo: selectedStationId)
        .where("CheckInTime",
            isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange!
                .start /*.subtract(Duration(hours: 8))*/) // ✅ Adjusted
            )
        .where("CheckOutTime",
            isLessThanOrEqualTo: Timestamp.fromDate(
                adjustedEndDate /*.subtract(Duration(hours: 8))*/) // ✅ Adjusted
            )
        .get();

    int totalSessions = snapshot.docs.length;
    double totalRevenue = 0.0;
    double totalEnergy = 0.0;
    Map<int, int> peakHourUsage = {}; // {hour: count}

    print(
        "\n🔹 Retrieved ${snapshot.docs.length} Charging Sessions from Firestore 🔹");

    for (var doc in snapshot.docs) {
      var data = doc.data();

      // ✅ Add 8 hours to the original Firestore timestamps
      DateTime checkIn = (data['CheckInTime'] as Timestamp)
          .toDate() /*.add(Duration(hours: 8))*/;
      DateTime checkOut = (data['CheckOutTime'] as Timestamp)
          .toDate() /*.add(Duration(hours: 8))*/;

      // ✅ Calculate peak hour correctly
      int hour = checkIn.hour;
      peakHourUsage[hour] = (peakHourUsage[hour] ?? 0) + 1;

      totalRevenue += (data['TotalCost'] ?? 0).toDouble();
      totalEnergy += (data['EnergyUsed'] ?? 0).toDouble();

      // ✅ Print each session details
      print("""
    📍 Session Data:
    - Station ID: ${data['StationID']}
    - Check-In Time (Adjusted): $checkIn
    - Check-Out Time (Adjusted): $checkOut
    - Total Cost: RM ${data['TotalCost']}
    - Energy Used: ${data['EnergyUsed']} kWh
    - Peak Hour: $hour
    """);
    }

    // ✅ Print summary of retrieved data
    print("""
  📊 Summary:
  - Total Sessions: $totalSessions
  - Total Revenue: RM ${totalRevenue.toStringAsFixed(2)}
  - Total Energy Consumption: ${totalEnergy.toStringAsFixed(2)} kWh
  - Peak Hour Usage: $peakHourUsage
  """);

    return {
      "totalSessions": totalSessions,
      "totalRevenue": totalRevenue,
      "totalEnergy": totalEnergy,
      "peakHourUsage": peakHourUsage,
    };
  }

  /// **📌 3️⃣ Report Title & Header**
  pw.Widget _buildReportHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.blue900,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Charging Station Usage Report",
            style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            "Generated On: ${DateTime.now()}",
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey300),
          ),
          pw.Text(
            "Generated By: $adminNameAndID",
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey300),
          ),
        ],
      ),
    );
  }

  /// **📍 4️⃣ Station Info & Date Range**
  pw.Widget _buildStationDetails() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Station ID: $selectedStationId",
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text("Station Location: $selectedStationLocation",
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(
              "Date Range: ${selectedDateRange?.start.toLocal()} to ${selectedDateRange?.end.toLocal()}",
              style: pw.TextStyle(fontSize: 14)),
          pw.Divider(),
        ],
      ),
    );
  }

  /// **Date Picker**
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  /// **📊 5️⃣ Summary Section (Formatted)**
  pw.Widget _buildSummarySection(Map<String, dynamic> data) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Summary Section",
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          _buildKeyValueRow(
              "Total Charges Made:", data['totalSessions'].toString()),
          _buildKeyValueRow(
              "Total Revenue (RM):", data['totalRevenue'].toStringAsFixed(2)),
          _buildKeyValueRow("Energy Consumption (kWh):",
              data['totalEnergy'].toStringAsFixed(2)),
        ],
      ),
    );
  }

  /// **📌 Helper: Creates Aligned Key-Value Pairs**
  pw.Widget _buildKeyValueRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 14)),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// **📈 6️⃣ Peak Hour Analysis Graph**
  pw.Widget _buildPeakHourChart(Map<String, dynamic> data) {
    // ✅ Ensure all 24 hours exist (fill missing hours with 0)
    final Map<int, int> peakHourData = {for (int i = 0; i < 24; i++) i: 0};
    data['peakHourUsage'].forEach((key, value) {
      peakHourData[key] = value; // ✅ Assign actual session counts
    });

    final List<int> peakHours = peakHourData.keys.toList(); // ✅ All 24 hours
    final int maxSessions = peakHourData.values.isEmpty
        ? 1
        : peakHourData.values.fold(1, (a, b) => a > b ? a : b);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("Peak Hour Analysis",
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Container(
            height: 200,
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis.fromStrings(
                  peakHours.map((h) => h.toString()).toList(),
                  // ✅ Show all 24 hours
                  textStyle: pw.TextStyle(fontSize: 10),
                ),
                yAxis: pw.FixedAxis(
                  List.generate(maxSessions + 1, (i) => i.toDouble()),
                  textStyle: pw.TextStyle(fontSize: 10),
                ),
              ),
              datasets: [
                pw.LineDataSet(
                  drawPoints: true,
                  drawLine: true,
                  isCurved: true,
                  data: peakHours
                      .map((hour) => pw.PointChartValue(
                              hour.toDouble(),
                              peakHourData[hour]!
                                  .toDouble()) // ✅ Show session counts
                          )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Print Report"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Charging Station",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('station')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        var stations = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          // Ensures it takes full width
                          initialValue: selectedStationId,
                          hint: const Text("Select Charging Station"),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: stations.map((station) {
                            return DropdownMenuItem<String>(
                              value: station.id,
                              child: Text(
                                station['StationName'],
                                overflow: TextOverflow
                                    .ellipsis, // Prevent text from overflowing
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStationId = value;
                              _fetchStationDetails(value!);
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Date Range",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range),
                      label: const Text("Select Date Range"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedDateRange != null)
                      Text(
                        "${selectedDateRange!.start.toLocal().toString().split(' ')[0]} → ${selectedDateRange!.end.toLocal().toString().split(' ')[0]}",
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateAndPrintReport,
              icon: const Icon(Icons.print),
              label: const Text("Generate & Print Report"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
