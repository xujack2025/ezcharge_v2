import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PointHistoryScreen extends StatefulWidget {
  @override
  _PointHistoryScreenState createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen>
    with SingleTickerProviderStateMixin {
  String _accountId = "";
  List<Map<String, dynamic>> _expiredRewards = [];
  List<Map<String, dynamic>> _usedRewards = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getCustomerID();
  }

  /// Fetch Customer ID based on logged-in user's phone number
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

          _fetchRewards(); // Fetch rewards after getting CustomerID
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Fetch Redeemed Rewards and Filter Expired Ones
  Future<void> _fetchRewards() async {
    try {
      if (_accountId.isEmpty) return;

      // Fetch customer's doc
      DocumentSnapshot customerSnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .get();

      if (!customerSnapshot.exists) return;

      // Expired rewards come from RedeemedRewards array
      List<dynamic> redeemedRewardIds =
          customerSnapshot["RedeemedRewards"] ?? [];

      // Used rewards come from UsedReward array.
      // If the field doesn't exist, default to an empty list.
      final Map<String, dynamic>? customerData =
          customerSnapshot.data() as Map<String, dynamic>?;
      List<dynamic> usedRewardIds =
          (customerData?.containsKey("UsedReward") ?? false)
              ? customerData!["UsedReward"]
              : [];

      // Prepare local lists to fill
      List<Map<String, dynamic>> expiredRewards = [];
      List<Map<String, dynamic>> usedRewards = [];

      // ---- Fetch & build expired rewards from "RedeemedRewards" ----
      for (String rewardId in redeemedRewardIds) {
        DocumentSnapshot rewardSnapshot = await FirebaseFirestore.instance
            .collection("reward")
            .doc(rewardId)
            .get();

        if (rewardSnapshot.exists) {
          Map<String, dynamic> rewardData =
              rewardSnapshot.data() as Map<String, dynamic>;
          DateTime expirationDate =
              (rewardData["ExpiredDate"] as Timestamp).toDate();

          // If it's expired, add it to expiredRewards
          if (expirationDate.isBefore(DateTime.now())) {
            expiredRewards.add(rewardData);
          }
        }
      }

      // ---- Fetch & build used rewards from "UsedReward" ----
      for (String rewardId in usedRewardIds) {
        DocumentSnapshot rewardSnapshot = await FirebaseFirestore.instance
            .collection("reward")
            .doc(rewardId)
            .get();

        if (rewardSnapshot.exists) {
          Map<String, dynamic> rewardData =
              rewardSnapshot.data() as Map<String, dynamic>;
          usedRewards.add(rewardData);
        }
      }

      setState(() {
        _expiredRewards = expiredRewards;
        _usedRewards = usedRewards; // for the "Used" tab
      });
    } catch (e) {
      print("Error fetching rewards: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Invalid"),
            Tab(text: "Used"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvalidTab(),
          _buildUsedTab(),
        ],
      ),
    );
  }

  //UI for "Invalid" tab (Expired Rewards)
  Widget _buildInvalidTab() {
    return _expiredRewards.isEmpty
        ? Center(child: Text("No expired rewards."))
        : ListView.builder(
            itemCount: _expiredRewards.length,
            itemBuilder: (context, index) {
              var reward = _expiredRewards[index];

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                padding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20), // Increased vertical padding
                decoration: BoxDecoration(
                  color: Colors.grey[300], // Light gray background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip
                      .none, // Allows positioned widget to be outside the container
                  children: [
                    // Expired label
                    Positioned(
                      top: -10, // Moves label slightly above container
                      left: -25, // Aligns label to left
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[900], // Dark blue for label
                          borderRadius: BorderRadius.circular(
                              8), // Uniform radius of 8 for all corners
                        ),
                        child: Text(
                          "Expired",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Reward details
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20), // Space below the label
                        Text(
                          reward["RewardDetails"] ?? "Unknown Reward",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Valid Till: ${reward["ExpiredDate"].toDate()}",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        SizedBox(height: 10), // Extra space for better layout
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }

  //UI for "Used" tab (Active Redeemed Rewards)
  Widget _buildUsedTab() {
    if (_usedRewards.isEmpty) {
      return const Center(child: Text("No used rewards."));
    }

    return ListView.builder(
      itemCount: _usedRewards.length,
      itemBuilder: (context, index) {
        var reward = _usedRewards[index];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300], // Light gray background
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // "Used" label
              Positioned(
                top: -10,
                left: -25,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[900], // A different color for "Used"
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Used",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Reward details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20), // Space for label above
                  Text(
                    reward["RewardDetails"] ?? "Unknown Reward",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Valid Till: ${reward["ExpiredDate"].toDate()}",
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
