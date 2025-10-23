import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/views/EZCHARGE/HomeScreen.dart';
import 'package:ezcharge/views/customer/Notification/NotificationScreen.dart';
import 'package:ezcharge/views/customer/Reward/PointHistoryScreen.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';

class RewardScreen extends StatefulWidget {
  const RewardScreen({super.key});

  @override
  _RewardScreenState createState() => _RewardScreenState();
}

class _RewardScreenState extends State<RewardScreen> {
  int _customerPoints = 0;
  String _customerId = "";
  List<Map<String, dynamic>> _rewards = [];
  List<String> _redeemedRewards = []; // Stores redeemed reward IDs

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchRewards();
  }

  //Fetch user data (points & redeemed rewards)
  Future<void> _fetchUserData() async {
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
            _customerPoints = userDoc["PointBalance"];
            _customerId = userDoc["CustomerID"]; // Use Firestore Document ID
            _redeemedRewards =
                List<String>.from(userDoc["RedeemedRewards"] ?? []);
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // Fetch rewards from Firestore
  Future<void> _fetchRewards() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection("reward").get();
      DateTime now = DateTime.now();

      setState(() {
        _rewards = querySnapshot.docs
            .map((doc) {
              var reward = doc.data() as Map<String, dynamic>;
              Timestamp? expiryTimestamp = reward["ExpiredDate"];

              if (expiryTimestamp != null) {
                DateTime expiryDate =
                    expiryTimestamp.toDate(); //Convert Firestore Timestamp
                if (expiryDate.isAfter(now)) {
                  return {
                    "RewardID": reward["RewardID"],
                    "RewardDetails": reward["RewardDetails"],
                    "Points": reward["Points"],
                    "ExpiredDate": expiryDate,
                  };
                }
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (e) {
      print("Error fetching rewards: $e");
    }
  }

  // Redeem reward and accumulate points (if not already redeemed)
  void _redeemReward(BuildContext context, String rewardId,
      String rewardDetails, int rewardPoints) async {
    if (_redeemedRewards.contains(rewardId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have already redeemed this reward.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Redeem Points"),
          content: Text("Are you sure you want to redeem:\n$rewardDetails?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  // 🔹 Add points and mark reward as redeemed
                  int updatedPoints = _customerPoints + rewardPoints;
                  _redeemedRewards.add(rewardId); // Update local redeemed list

                  await FirebaseFirestore.instance
                      .collection("customers")
                      .doc(_customerId)
                      .update({
                    "PointBalance": updatedPoints,
                    "RedeemedRewards":
                        _redeemedRewards, // Store redeemed rewards
                  });

                  setState(() {
                    _customerPoints = updatedPoints;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Successfully redeemed: $rewardDetails")),
                  );
                } catch (e) {
                  print("Error redeeming reward: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Failed to redeem reward. Try again.")),
                  );
                }
              },
              child: const Text("Confirm", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text("Rewards",
            style: TextStyle(
                color: Colors.black,
                fontSize: 30,
                fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPointsCard(),
            const SizedBox(height: 20),

            //View Points History Button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PointHistoryScreen()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "View my points history",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  Container(
                    width: 30, // Set size of the circle
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.blue, // Blue background
                      shape: BoxShape.circle, // Circular shape
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white, // White arrow
                      size: 20, // Adjust arrow size
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(
              color: Colors.grey, // Light gray color
              thickness: 1, // Line thickness
            ),
            const SizedBox(height: 10),
            const Text("EZCHARGE Promotions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            ..._rewards
                .map((reward) => _buildPromotionItem(context, reward))
                .toList(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  //Display User Points
  Widget _buildPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blue, Colors.indigo]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("You have",
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 5),
          Text("$_customerPoints pts",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  //Build a Redeemable Promotion Item
  Widget _buildPromotionItem(
      BuildContext context, Map<String, dynamic> reward) {
    bool isRedeemed = _redeemedRewards.contains(reward["RewardID"]);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                height: 80,
                color: Colors.grey[300],
                child: const Icon(Icons.card_giftcard,
                    color: Colors.blue, size: 40),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward["RewardDetails"],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text("${reward["Points"]} pts",
                          style: const TextStyle(
                              color: Colors.blue, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isRedeemed
                  ? null
                  : () => _redeemReward(context, reward["RewardID"],
                      reward["RewardDetails"], reward["Points"]),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRedeemed ? Colors.grey : Colors.blue,
              ),
              child: Text(
                isRedeemed ? "REDEEMED" : "REDEEM",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Bottom Navigation Bar
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      currentIndex: 1,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomeScreen()));
        } else if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const AccountScreen()));
        } else if (index == 3) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationScreen()));
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.directions_car), label: "EZCharge"),
        BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard), label: "Rewards"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Me"),
        BottomNavigationBarItem(icon: Icon(Icons.mail), label: "Inbox"),
      ],
    );
  }
}
