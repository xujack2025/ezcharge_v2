import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RewardSelectScreen extends StatefulWidget {
  const RewardSelectScreen({Key? key}) : super(key: key);

  @override
  State<RewardSelectScreen> createState() => _RewardSelectScreenState();
}

class _RewardSelectScreenState extends State<RewardSelectScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> _rewards = [];
  int? _selectedIndex; // Track which reward is selected

  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  //Fetch rewards for the current user from Firestore.
  //If the customer's "UsedReward" field doesn't exist or is empty, then display
  //all rewards from "RedeemedRewards" (that are not expired).
  //Otherwise, filter out any reward that appears in "UsedReward."
  Future<void> _fetchRewards() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) {
          setState(() => isLoading = false);
          return;
        }

        //Get the customer document by phone number
        final customerSnap = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (customerSnap.docs.isNotEmpty) {
          final userDoc = customerSnap.docs.first;

          // Extract the list of redeemed reward IDs from the user doc
          final List<String> redeemedRewardIds = List<String>.from(
              userDoc["RedeemedRewards"] ?? []);

          // Check if the "UsedReward" field exists; if not, default to an empty list.
          final List<String> usedRewardIds = userDoc.data().containsKey("UsedReward")
              ? List<String>.from(userDoc["UsedReward"])
              : [];

          final List<Map<String, dynamic>> loadedRewards = [];

          // For each reward ID, fetch its details from the 'reward' collection
          for (String rewardId in redeemedRewardIds) {
            // If the reward is marked as used, skip it
            if (usedRewardIds.contains(rewardId)) continue;

            final DocumentSnapshot rewardDoc = await FirebaseFirestore.instance
                .collection("reward")
                .doc(rewardId)
                .get();

            if (rewardDoc.exists) {
              final data = rewardDoc.data() as Map<String, dynamic>;
              // Parse the ExpiredDate field into a DateTime
              final Timestamp expTS = data["ExpiredDate"];
              final DateTime expDate = expTS.toDate();

              // Skip the reward if it is expired
              if (expDate.isBefore(DateTime.now())) continue;

              loadedRewards.add({
                "RewardID": rewardId,
                "Points": data["Points"] ?? 0,
                "RewardDetails": data["RewardDetails"] ?? "",
                "ExpiredDate": expDate,
              });
            }
          }
          // Assign the loaded rewards list to your _rewards variable
          _rewards = loadedRewards;
        }
      }
    } catch (e) {
      print("Error fetching rewards: $e");
    }

    setState(() => isLoading = false);
  }

  String _formatDate(DateTime date) {
    return DateFormat('d/M/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _selectedIndex == null
              ? null // Disable if no reward is selected
              : () {
            final selectedReward = _rewards[_selectedIndex!];
            final String rewardId = selectedReward["RewardID"];
            final int points = selectedReward["Points"] ?? 0;
            final double discount = points / 10; // e.g. 300 pts => RM30

            // Return the discount and rewardID to PaymentScreen
            Navigator.pop(context, {
              "rewardID": rewardId,
              "discount": discount,
              "points": points,  // passing the points value
            });
          },
          child: const Text(
            "CONFIRM",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with the back button and "Reward Discount" text
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              // Circular back button
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
                "Reward Discount",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Body content: list of rewards or a "No rewards found" message.
        Expanded(
          child: _rewards.isEmpty
              ? const Center(child: Text("No rewards found."))
              : ListView.builder(
            itemCount: _rewards.length,
            itemBuilder: (context, index) {
              final reward = _rewards[index];
              final points = reward["Points"] as int;
              final details = reward["RewardDetails"] as String;
              final dateText = "Valid Till: ${_formatDate(reward["ExpiredDate"])}";

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedIndex == index ? Colors.blue : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Radio icon to indicate selection
                      Icon(
                        _selectedIndex == index
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      // Points circle + icon (simulate the “-300 pts” design)
                      Container(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "-$points",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.bolt,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Reward info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
