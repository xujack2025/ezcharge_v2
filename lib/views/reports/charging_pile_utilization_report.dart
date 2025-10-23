import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ChargingPileUtilizationReport extends StatefulWidget {
  const ChargingPileUtilizationReport({super.key});

  @override
  State<ChargingPileUtilizationReport> createState() =>
      _ChargingPileUtilizationReportState();
}

class _ChargingPileUtilizationReportState
    extends State<ChargingPileUtilizationReport> {
  bool isLoading = false;
  DateTimeRange? selectedDateRange;
  String? adminNameAndID;

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

  Future<void> _generateAndPrintReport() async {
    if (selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date range.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final pdf = pw.Document();
      final data = await _fetchChargingPileData();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildReportHeader(),
            _buildChargingPileTable(data),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print("❌ Report generation failed: $e");
    }

    setState(() => isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _fetchChargingPileData() async {
    DateTime adjustedEndDate = selectedDateRange!.end.add(Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where("CheckInTime",
            isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange!
                .start /*.subtract(const Duration(hours: 8))*/))
        .where("CheckInTime",
            isLessThanOrEqualTo: Timestamp.fromDate(
                adjustedEndDate /*.subtract(const Duration(hours: 8))*/))
        .orderBy("CheckInTime", descending: true)
        .get();

    List<Map<String, dynamic>> pileData = [];
    Map<String, Map<String, dynamic>> pileUsage = {};

    for (var doc in snapshot.docs) {
      var data = doc.data();
      String stationID = data['StationID'] ?? "Unknown";
      String pileID = data['SlotID'] ?? "Unknown";

      DateTime startTime = (data['CheckInTime'] as Timestamp)
          .toDate() /*.add(const Duration(hours: 8))*/;
      DateTime endTime = (data['CheckOutTime'] as Timestamp?)
              ?.toDate() /*.add(const Duration(hours: 8))*/ ??
          startTime; // If missing, use start time

      double energyUsed = (data['EnergyUsed'] ?? 0).toDouble();
      Duration sessionDuration =
          endTime.difference(startTime); // ✅ Calculate session duration
      double sessionHours =
          sessionDuration.inMinutes / 60.0; // Convert to hours

      // Key format: "StationID - PileID"
      String pileKey = "$stationID - $pileID";

      if (!pileUsage.containsKey(pileKey)) {
        pileUsage[pileKey] = {
          "stationID": stationID,
          "pileID": pileID,
          "totalSessions": 0,
          "totalEnergy": 0.0,
          "totalHoursUsed": 0.0, // ✅ Add total hours used
          "usageByHour": {}, // Track usage by hour
        };
      }

      // Increment session count
      pileUsage[pileKey]!["totalSessions"] += 1;
      // Add energy used
      pileUsage[pileKey]!["totalEnergy"] += energyUsed;
      // Add total hours used
      pileUsage[pileKey]!["totalHoursUsed"] += sessionHours;
      // Track peak hour usage
      int hour = startTime.hour;
      pileUsage[pileKey]!["usageByHour"][hour] =
          (pileUsage[pileKey]!["usageByHour"][hour] ?? 0) + 1;
    }

    // Convert map to list
    pileUsage.forEach((key, value) {
      pileData.add(value);
    });

    return pileData;
  }

  pw.Widget _buildReportHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.blue900,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Charging Pile Utilization Report",
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

  pw.Widget _buildChargingPileTable(List<Map<String, dynamic>> pileData) {
    pileData.sort((a, b) {
      Map<int, int> usageA = (a['usageByHour'] as Map).map(
        (key, value) =>
            MapEntry(int.parse(key.toString()), int.parse(value.toString())),
      );
      Map<int, int> usageB = (b['usageByHour'] as Map).map(
        (key, value) =>
            MapEntry(int.parse(key.toString()), int.parse(value.toString())),
      );

      int maxSessionsA = usageA.values.isEmpty
          ? 0
          : usageA.values.reduce((a, b) => a > b ? a : b);
      int maxSessionsB = usageB.values.isEmpty
          ? 0
          : usageB.values.reduce((a, b) => a > b ? a : b);

      if (a['stationID'].compareTo(b['stationID']) == 0) {
        return maxSessionsB.compareTo(maxSessionsA);
      }

      return a['stationID'].compareTo(b['stationID']);
    });

    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Table.fromTextArray(
        headerDecoration: pw.BoxDecoration(color: PdfColors.blue200),
        headers: [
          "Station ID",
          "Slot ID",
          "Total Sessions",
          "Total Energy Used",
          "Total Hours Used", // ✅ New column
          "Peak Usage Hour"
        ],
        data: pileData.map((pile) {
          Map<int, int> usageByHour = (pile['usageByHour'] as Map).map(
            (key, value) => MapEntry(
                int.parse(key.toString()), int.parse(value.toString())),
          );

          int peakHour = 0;
          int maxSessions = 0;
          usageByHour.forEach((hour, count) {
            if (count > maxSessions) {
              peakHour = hour;
              maxSessions = count;
            }
          });

          return [
            pile['stationID'],
            pile['pileID'],
            pile['totalSessions'].toString(),
            "${pile['totalEnergy'].toStringAsFixed(2)} kWh",
            "${pile['totalHoursUsed'].toStringAsFixed(2)} h",
            // ✅ Display total hours
            "$peakHour:00 (${maxSessions} sessions)"
          ];
        }).toList(),
        cellStyle: pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(3),
          4: const pw.FlexColumnWidth(3),
          5: const pw.FlexColumnWidth(3),
        },
      ),
    );
  }

  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Charging Pile Utilization Report"),
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
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
