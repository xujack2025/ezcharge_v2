import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/views/EZCHARGE/PaymentSuccessScreen.dart';
import 'package:ezcharge/views/customer/customercontent/TopUpScreen.dart';

class SelectPaymentScreen extends StatefulWidget {
  final double totalAmount;
  final String rewardID;
  final int rewardPoints;

  const SelectPaymentScreen({
    Key? key,
    required this.totalAmount,
    required this.rewardID,
    required this.rewardPoints,
  }) : super(key: key);

  @override
  State<SelectPaymentScreen> createState() => _SelectPaymentScreenState();
}

class _SelectPaymentScreenState extends State<SelectPaymentScreen> {
  bool isLoading = false;
  String _accountId = "";
  double _walletBalance = 0.0;
  String? _cardNumber; // null if no card
  String? _selectedMethod; // "card" or "wallet"
  int _pointBalance = 0;

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
  }

  Future<void> _fetchWalletBalance() async {
    setState(() => isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isNotEmpty) {
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection("customers")
              .where("PhoneNumber", isEqualTo: userPhone)
              .limit(1)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            var userDoc = querySnapshot.docs.first;
            _accountId = userDoc["CustomerID"] ?? "";
            _walletBalance = (userDoc["WalletBalance"] ?? 0).toDouble();
            _pointBalance = userDoc["PointBalance"] ?? 0;
            await _fetchCardNumber();
          }
        }
      }
    } catch (e) {
      print("Error fetching wallet balance: $e");
    }
    setState(() => isLoading = false);
  }

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
        _cardNumber = querySnapshot.docs.first["CardNumber"];
      }
    } catch (e) {
      print("Error fetching card number: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String totalStr = widget.totalAmount.toStringAsFixed(2);
    int newPointBalance = _pointBalance - widget.rewardPoints;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1) Top Row: Back Button + "Payment"
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
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
                        const SizedBox(width: 12),
                        const Text(
                          "Payment",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 2) Centered Content (Total Amount, Payment Methods)
                    // Wrap them in a column with crossAxisAlignment.center
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // a) "Total Amount" label
                        const Text(
                          "Total Amount",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // b) Large total text
                        Text(
                          "RM $totalStr",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // c) "Please choose a payment method"
                        const Text(
                          "Please choose a payment method",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // d) Payment Method Options (Card + Wallet)
                        // If we have a cardNumber, show card radio
                        if (_cardNumber != null && _cardNumber!.isNotEmpty)
                          _buildCardOption(),

                        // Always show wallet option
                        _buildWalletOption(),
                      ],
                    ),

                    // 3) Spacer to push the PAY button to bottom
                    const Spacer(),

                    // 4) PAY button (left alone)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedMethod == null
                              ? Colors.grey
                              : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _selectedMethod == null
                            ? null // Disabled if no selection
                            : () async {
                                if (_selectedMethod == "wallet") {
                                  // 1) Check wallet balance
                                  if (_walletBalance < widget.totalAmount) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Your wallet balance is not enough."),
                                      ),
                                    );
                                  } else {
                                    double newBalance =
                                        _walletBalance - widget.totalAmount;
                                    try {
                                      // 2) Update wallet balance
                                      await FirebaseFirestore.instance
                                          .collection("customers")
                                          .doc(_accountId)
                                          .update(
                                              {"WalletBalance": newBalance});

                                      // 3) If a reward was used, mark it used + deduct points
                                      if (widget.rewardID.isNotEmpty) {
                                        // Mark reward as used
                                        await FirebaseFirestore.instance
                                            .collection("customers")
                                            .doc(_accountId)
                                            .update({
                                          "UsedReward": FieldValue.arrayUnion(
                                              [widget.rewardID])
                                        });

                                        // Deduct reward points from user's PointBalance
                                        if (widget.rewardPoints > 0) {
                                          await FirebaseFirestore.instance
                                              .collection("customers")
                                              .doc(_accountId)
                                              .update({
                                            "PointBalance": newPointBalance
                                          });
                                        }
                                      }

                                      setState(() {
                                        _walletBalance = newBalance;
                                      });

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text("Payment successful!"),
                                        ),
                                      );

                                      // 4) Navigate to PaymentSuccessScreen with wallet payment method
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PaymentSuccessScreen(
                                            paymentMethod: "EZCHARGE Wallet",
                                            totalAmount: widget.totalAmount,
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              "Failed to update wallet balance: $error"),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Payment by card
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("Processing card payment..."),
                                    ),
                                  );

                                  // Simulate 3-second processing
                                  await Future.delayed(
                                      const Duration(seconds: 3));

                                  try {
                                    // If a reward was used, mark it used + deduct points
                                    if (widget.rewardID.isNotEmpty) {
                                      // Mark reward as used
                                      await FirebaseFirestore.instance
                                          .collection("customers")
                                          .doc(_accountId)
                                          .update({
                                        "UsedReward": FieldValue.arrayUnion(
                                            [widget.rewardID])
                                      });

                                      // Deduct reward points
                                      if (widget.rewardPoints > 0) {
                                        await FirebaseFirestore.instance
                                            .collection("customers")
                                            .doc(_accountId)
                                            .update({
                                          "PointBalance": newPointBalance
                                        });
                                      }
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Payment successful!"),
                                      ),
                                    );

                                    // Navigate to PaymentSuccessScreen with card payment method
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PaymentSuccessScreen(
                                          paymentMethod: "Credit Card",
                                          totalAmount: widget.totalAmount,
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Error updating reward usage: $error"),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text(
                          "PAY",
                          style: TextStyle(
                            fontSize: 18,
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

  //Build a radio option for the user's card, centered
  Widget _buildCardOption() {
    final String last4 = _cardNumber!.length >= 4
        ? _cardNumber!.substring(_cardNumber!.length - 4)
        : _cardNumber!;
    final String maskedCard = "**** **** **** $last4";

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = "card";
          });
        },
        child: Row(
          // By default, Row is left-aligned if its parent Column is left-aligned.
          children: [
            Radio<String>(
              value: "card",
              groupValue: _selectedMethod,
              onChanged: (val) {
                setState(() {
                  _selectedMethod = val;
                });
              },
            ),
            const Icon(Icons.credit_card, size: 30),
            const SizedBox(width: 8),
            Text(
              maskedCard,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  //Build a radio option for the user's wallet, centered, with a top-up button
  Widget _buildWalletOption() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = "wallet";
          });
        },
        child: Row(
          children: [
            Radio<String>(
              value: "wallet",
              groupValue: _selectedMethod,
              onChanged: (val) {
                setState(() {
                  _selectedMethod = val;
                });
              },
            ),
            const Icon(Icons.account_balance_wallet_outlined, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Credit Balance: RM${_walletBalance.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TopUpScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
              ),
              child: const Text("+ TOP UP",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
