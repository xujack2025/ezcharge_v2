import 'package:ezcharge/views/customer/customercontent/ReloadPINScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  _TopUpScreenState createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  double _walletBalance = 0.0; // Default wallet balance
  String _accountId = "";
  String _cardNumber = "";
  bool isLoading = true;
  bool isCardSelected = false;
  bool isReloadPinSelected = false;
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCustomerID();
    _fetchWalletBalance();
    _amountController.addListener(_updateButtonState);
  }

  // Get Customer ID
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

          _fetchCardNumber(); // Fetch card number after getting account ID
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Fetch the logged-in user's wallet balance from Firestore
  Future<void> _fetchWalletBalance() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) return;

        // 🔹 Search Firestore for matching phone number
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;
          setState(() {
            _accountId = userDoc["CustomerID"];
            _walletBalance = userDoc["WalletBalance"].toDouble();
          });

          // Fetch the card number after getting customer ID
          _fetchCardNumber();
        }
      }
    } catch (e) {
      print("Error fetching wallet balance: $e");
    }
  }

  void _updateButtonState() {
    setState(() {});
  }

  bool _isNextButtonEnabled() {
    return _amountController.text.isNotEmpty &&
        (isCardSelected || isReloadPinSelected);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  //Fetch Card Number from Firestore
  Future<void> _fetchCardNumber() async {
    if (_accountId.isEmpty) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("PaymentMethod")
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _cardNumber = querySnapshot.docs.first["CardNumber"];
        });
      }
    } catch (e) {
      print("Error fetching card number: $e");
    }
  }

  //Build Card Number Display Widget
  Widget _buildCardNumberDisplay(bool isSelected) {
    return _cardNumber.isNotEmpty
        ? GestureDetector(
            onTap: () {
              setState(() {
                isCardSelected = true;
                isReloadPinSelected = false;
                _updateButtonState();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.white, //Highlight when selected
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.credit_card,
                      size: 30,
                      color: isCardSelected ? Colors.blue : Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    _cardNumber,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      resizeToAvoidBottomInset:
          false, //Prevent UI from resizing when keyboard appears
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
        title: const Text("Top Up EZCHARGE Credit",
            style: TextStyle(
                color: Colors.black,
                fontSize: 23,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //EZCharge Credits Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "EZCharge Credits",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "RM ${_walletBalance.toStringAsFixed(2)}",
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              //Top Up Amount Input
              const Text("Enter Top Up Amount",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: "RM ",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Amount Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [50, 100, 150].map((amount) {
                  return ElevatedButton(
                    onPressed: () {
                      _amountController.text = amount.toString();
                      _updateButtonState();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text("RM $amount",
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              // Card Number Display
              GestureDetector(
                onTap: () {
                  setState(() {
                    isCardSelected = true;
                    isReloadPinSelected = false;
                  });
                },
                child: _buildCardNumberDisplay(isCardSelected),
              ),

              //Payment Options
              GestureDetector(
                onTap: () {
                  setState(() {
                    isReloadPinSelected = !isReloadPinSelected;
                    isCardSelected = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isReloadPinSelected ? Colors.blue[100] : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.autorenew,
                          color:
                              isReloadPinSelected ? Colors.blue : Colors.black),
                      const SizedBox(width: 10),
                      const Text(
                        "Reload PIN",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 270), //Prevent bottom overflow

              // Next Button (Always Visible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isNextButtonEnabled()
                      ? () {
                          double enteredAmount =
                              double.tryParse(_amountController.text) ?? 0.0;
                          if (isReloadPinSelected) {
                            // Navigate to ReloadPINScreen with the top-up amount
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReloadPINScreen(topUpAmount: enteredAmount),
                              ),
                            );
                          } else if (isCardSelected) {
                            // Set loading state and simulate processing for 3 seconds
                            setState(() {
                              isLoading = true;
                            });
                            double newWalletBalance =
                                _walletBalance + enteredAmount;
                            Future.delayed(const Duration(seconds: 3), () {
                              FirebaseFirestore.instance
                                  .collection("customers")
                                  .doc(_accountId)
                                  .update({
                                "WalletBalance": newWalletBalance,
                              }).then((value) {
                                setState(() {
                                  _walletBalance = newWalletBalance;
                                  isLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Top-up successful!")),
                                );
                              }).catchError((error) {
                                setState(() {
                                  isLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          "Error updating wallet: $error")),
                                );
                              });
                            });
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isNextButtonEnabled() ? Colors.blue : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text("NEXT",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
