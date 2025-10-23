import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ComplaintResolutionReport extends StatefulWidget {
  const ComplaintResolutionReport({super.key});

  @override
  State<ComplaintResolutionReport> createState() =>
      _ComplaintResolutionReportState();
}

class _ComplaintResolutionReportState extends State<ComplaintResolutionReport> {
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
      final data = await _fetchComplaintData();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildReportHeader(),
            _buildComplaintTable(data),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      print("❌ Report generation failed: $e");
    }

    setState(() => isLoading = false);
  }

  Future<String> _fetchCustomerName(String customerID) async {
    try {
      final customerSnapshot = await FirebaseFirestore.instance
          .collection('customers') // ✅ Query the `customers` collection
          .doc(customerID)
          .get();

      if (customerSnapshot.exists) {
        return customerSnapshot.data()?['FirstName'] ??
            "Unknown User"; // ✅ Get correct userName
      } else {
        return "Unknown User";
      }
    } catch (e) {
      print("❌ Error fetching userName for Customer ID $customerID: $e");
      return "Unknown User";
    }
  }

  Future<List<Map<String, dynamic>>> _fetchComplaintData() async {
    DateTime adjustedEndDate = selectedDateRange!.end.add(Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('complaints')
        .where("status", whereIn: [
          "Resolved",
          "Pending",
          "In Progress"
        ]) // ✅ Include 'status' to match the index
        .where("ComplaintDate",
            isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange!
                .start /*.subtract(const Duration(hours: 8))*/))
        .where("ComplaintDate",
            isLessThanOrEqualTo: Timestamp.fromDate(
                adjustedEndDate /*.subtract(const Duration(hours: 8))*/))
        .orderBy("ComplaintDate", descending: true) // ✅ Must match index order
        .get();

    List<Map<String, dynamic>> complaints = [];

    for (var doc in snapshot.docs) {
      var data = doc.data();
      String customerID =
          doc.reference.parent.parent!.id; // ✅ Get customer ID from Firestore

      DateTime submittedAt = (data['ComplaintDate'] as Timestamp).toDate();
      /*.add(const Duration(hours: 8));*/
      DateTime? resolvedAt = data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          /*.add(const Duration(hours: 8))*/
          : null;
      Duration? resolutionTime =
          resolvedAt != null ? resolvedAt.difference(submittedAt) : null;

      // ✅ Fetch userName from the corresponding `customers` document
      String userName = await _fetchCustomerName(customerID);

      complaints.add({
        "complaintID": doc.id, // ✅ Complaint ID
        "customerID": customerID, // ✅ Store Customer ID
        "userName": userName, // ✅ Now retrieved from `customers` collection
        "issueType": data['Reason'] ?? "N/A",
        "status": data['status'] ?? "Pending",
        "submittedAt": submittedAt,
        "resolvedAt": resolvedAt,
        "resolutionTime": resolutionTime != null
            ? "${resolutionTime.inHours}h ${resolutionTime.inMinutes % 60}m"
            : "Not Resolved",
      });
    }

    return complaints;
  }

  pw.Widget _buildReportHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.blue900,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Complaint Resolution Report",
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

  pw.Widget _buildComplaintTable(List<Map<String, dynamic>> complaints) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Table.fromTextArray(
        headerDecoration: pw.BoxDecoration(color: PdfColors.blue200),
        headers: [
          "Complaint ID",
          "User",
          "Issue Type",
          "Status",
          "Submitted At",
          "Resolved At",
          "Resolution Time"
        ],
        data: complaints
            .map((complaint) => [
                  complaint['complaintID'],
                  complaint['userName'],
                  complaint['issueType'],
                  complaint['status'],
                  complaint['submittedAt'].toString(),
                  complaint['resolvedAt']?.toString() ?? "Not Resolved",
                  complaint['resolutionTime'],
                ])
            .toList(),
        cellStyle: pw.TextStyle(fontSize: 10),
        headerStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(3),
          5: const pw.FlexColumnWidth(3),
          6: const pw.FlexColumnWidth(2),
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
        title: const Text("Complaint Resolution Report"),
        centerTitle: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}
