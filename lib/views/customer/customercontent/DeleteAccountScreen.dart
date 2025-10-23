import 'package:flutter/material.dart';
import 'package:ezcharge/views/customer/customercontent/ConfirmDeleteScreen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String? _selectedReason;

  final List<String> _reasons = [
    "Hard to use",
    "Always out of service",
    "I have duplicate account",
    "Other application offer greater promotion",
    "Others"
  ];

  //Function to Show Bottom Sheet for Selecting a Reason
  void _showReasonPicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Reason",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._reasons.map((reason) => ListTile(
                    title: Text(reason),
                    onTap: () {
                      setState(() {
                        _selectedReason = reason;
                      });
                      Navigator.pop(context); // Close the bottom sheet
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
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
        title: const Text("Delete Account",
            style: TextStyle(
                color: Colors.black,
                fontSize: 30,
                fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            const Text(
              "You are about deleting your account",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            const Text(
              "Your feedback is important for us to improve our services",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Row(
              children: const [
                Text("Reason",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                Text(" *",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showReasonPicker,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300], // Disabled look
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedReason ?? "Select Reason",
                      style: TextStyle(
                          color: _selectedReason == null
                              ? Colors.black54
                              : Colors.black,
                          fontSize: 16),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 438),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ConfirmDeleteScreen()),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedReason == null ? Colors.grey : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: const Text("CONTINUE",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
