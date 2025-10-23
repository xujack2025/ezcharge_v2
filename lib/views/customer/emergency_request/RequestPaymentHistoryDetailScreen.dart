import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ezcharge/views/customer/customercontent/PaymentHistoryList.dart';

class RequestPaymentHistoryDetailScreen extends StatefulWidget {
  final String accountId;
  final String paymentDocId;
  final String requestId;

  const RequestPaymentHistoryDetailScreen({
    super.key,
    required this.accountId,
    required this.paymentDocId,
    required this.requestId,
  });

  @override
  State<RequestPaymentHistoryDetailScreen> createState() =>
      _RequestPaymentHistoryDetailScreenState();
}

class _RequestPaymentHistoryDetailScreenState
    extends State<RequestPaymentHistoryDetailScreen> {
  bool isLoading = false;

  // Fields to display
  double _totalCost = 0.0;
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
        final data = querySnap.docs.first.data();

        // Extract fields from the payment history document
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
                        onPressed: () {
                          // TODO: Implement printing logic
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Print not implemented")),
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
