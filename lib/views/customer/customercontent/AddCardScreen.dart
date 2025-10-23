import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  _AddCardScreenState createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  bool isLoading = false;
  String _accountId = "00000000"; // Store logged-in user's customer ID

  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  // Fetch current log in user id from Firestore
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
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Function to Add Payment Method to Firestore
  Future<void> _addCardToFirestore() async {
    if (_cardNumberController.text.isEmpty ||
        _expiryDateController.text.isEmpty ||
        _cvvController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields!")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Reference to the customer's payment method collection
      CollectionReference paymentRef = FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("PaymentMethod");

      // Check if the card number already exists
      QuerySnapshot existingCards = await paymentRef
          .where("CardNumber", isEqualTo: _cardNumberController.text)
          .get();

      if (existingCards.docs.isNotEmpty) {
        // Card Already Exists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This card is already registered!")),
        );
      } else {
        // Create a new card if none exists
        String newCardId = "PMM${DateTime.now().millisecondsSinceEpoch}";

        await paymentRef.doc(newCardId).set({
          "CardNumber": _cardNumberController.text,
          "ExpiredDate": _expiryDateController.text,
          "CVV": _cvvController.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Card added successfully!")),
        );

        //Close the modal and refresh PaymentMethodScreen
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      print("Error adding card: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add card. Try again!")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Add debit / credit card",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Card Number Input
            const Text("Card Number"),
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "XXXX-XXXX-XXXX-XXXX",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Expiry Date Input
            const Text("Expired Date"),
            TextField(
              controller: _expiryDateController,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                hintText: "MM / YY",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // CVV Input
            const Text("CVV"),
            TextField(
              controller: _cvvController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "XXX",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.help_outline),
              ),
            ),
            const SizedBox(height: 20),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _addCardToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("PROCEED",
                        style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
