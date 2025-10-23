import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import 'package:ezcharge/views/customer/customercontent/PaymentHistoryList.dart';

class PaymentHistoryDetailScreen extends StatefulWidget {
  final String accountId;
  final String paymentDocId;

  const PaymentHistoryDetailScreen({
    Key? key,
    required this.accountId,
    required this.paymentDocId,
  }) : super(key: key);

  @override
  State<PaymentHistoryDetailScreen> createState() =>
      _PaymentHistoryDetailScreenState();
}

class _PaymentHistoryDetailScreenState
    extends State<PaymentHistoryDetailScreen> {
  bool isLoading = false;

  // Fields to display
  double _totalCost = 0.0;
  String _stationName = "";
  String _chargerName = "";
  String _chargerType = "";
  String _duration = "";
  String _paymentMethod = "";
  String _paymentID = "";
  DateTime? _paidTime;

  @override
  void initState() {
    super.initState();
    _fetchPaymentDetail();
  }

  Future<void> _fetchPaymentDetail() async {
    setState(() => isLoading = true);

    try {
      final querySnap = await FirebaseFirestore.instance
          .collection("customers")
          .doc(widget.accountId)
          .collection("PaymentHistory")
          .where("Payment ID", isEqualTo: widget.paymentDocId)
          .get();

      if (querySnap.docs.isNotEmpty) {
        final data = querySnap.docs.first.data() as Map<String, dynamic>;

        // Extract fields from the payment history document
        _stationName = data["StationName"] ?? "";
        _chargerName = data["ChargerName"] ?? "";
        _chargerType = data["ChargerType"] ?? "";
        _duration = data["Duration"] ?? "";
        _paymentMethod = data["PaymentMethod"] ?? "";
        _paymentID = data["Payment ID"] ?? "";
        final costVal = data["TotalCost"];
        if (costVal is num) {
          _totalCost = costVal.toDouble();
        }
        final paidTimeVal = data["Paid Time"];
        if (paidTimeVal is Timestamp) {
          _paidTime = paidTimeVal.toDate();
        }
      }
    } catch (e) {
      print("Error fetching payment detail: $e");
    }

    setState(() => isLoading = false);
  }

  // Function to create section titles with better styling
  pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black),
      ),
    );
  }

// Function to create rows of information with consistent styling
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final costStr = "-RM${_totalCost.toStringAsFixed(2)}";
    String dateStr = "";
    if (_paidTime != null) {
      dateStr = DateFormat('EEE MMM d, h:mma').format(_paidTime!);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentHistoryListScreen(),
                ),
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: const Text(
          "Payment History",
          style: TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      backgroundColor: Colors.grey[200],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cost
                    Text(
                      costStr,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fields
                    _infoRow("Charging Station:", _stationName),
                    _infoRow("Charging Slot:", _chargerName),
                    _infoRow("Charger Type:", _chargerType),
                    _infoRow("Total Duration:", _duration),
                    const SizedBox(height: 8),
                    _infoRow("Paid By:", _paymentMethod),
                    _infoRow("Paid Time:", dateStr),
                    _infoRow("Payment ID:", _paymentID),

                    const SizedBox(height: 20),
                    // PRINT button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final pdf = pw.Document();

                          // Create a simple layout for the receipt
                          pdf.addPage(pw.Page(
                            build: (pw.Context context) {
                              return pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                // Align items to the left
                                children: [
                                  pw.Center(
                                    child: pw.Text(
                                      'Payment Receipt',
                                      style: pw.TextStyle(
                                          fontSize: 24,
                                          fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                                  pw.SizedBox(height: 20),

                                  // Charging Station and Slot
                                  _buildSectionTitle('Charging Details'),
                                  _buildInfoRow(
                                      'Charging Station:', _stationName),
                                  _buildInfoRow('Charging Slot:', _chargerName),
                                  _buildInfoRow('Charger Type:', _chargerType),
                                  _buildInfoRow('Total Duration:', _duration),
                                  pw.SizedBox(height: 16),

                                  // Payment Information
                                  _buildSectionTitle('Payment Details'),
                                  _buildInfoRow('Paid By:', _paymentMethod),
                                  _buildInfoRow('Paid Time:', dateStr),
                                  _buildInfoRow('Payment ID:', _paymentID),
                                  pw.SizedBox(height: 16),

                                  // Total Cost
                                  _buildSectionTitle('Total Cost'),
                                  pw.Text(
                                    'RM${_totalCost.toStringAsFixed(2)}',
                                    style: pw.TextStyle(
                                        fontSize: 20,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.red),
                                  ),
                                  pw.SizedBox(height: 30),

                                  // Footer (Optional)
                                  pw.Divider(),
                                  pw.Center(
                                    child: pw.Text(
                                        'Thank you for using our service!',
                                        style: pw.TextStyle(fontSize: 12)),
                                  ),
                                ],
                              );
                            },
                          ));

                          // Printing the document
                          await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async =>
                                pdf.save(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "PRINT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
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
