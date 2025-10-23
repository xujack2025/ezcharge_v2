import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ezcharge/views/customer/rating/manage_reviews.dart';

class ReviewPage extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String stationDescription;
  final String stationImage;

  const ReviewPage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.stationDescription,
    required this.stationImage,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 0; // Default rating
  String _username = "Guest";
  bool _isSubmitting = false;
  String? _comment;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var customerQuery = await _firestore
          .collection("customers")
          .where("PhoneNumber", isEqualTo: user.phoneNumber)
          .limit(1)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        setState(() {
          _username = customerQuery.docs.first["FirstName"] ?? "Guest";
        });
      }
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You must be logged in to submit a review.")),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating.")),
      );
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    try {
      // ✅ Retrieve customer ID
      var customerQuery = await _firestore
          .collection("customers")
          .where("PhoneNumber", isEqualTo: user.phoneNumber)
          .limit(1)
          .get();

      if (customerQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Customer profile not found. Please contact support.")),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      String customerID = customerQuery.docs.first["CustomerID"];

      // ✅ Generate Custom Review ID
      CollectionReference reviewsRef = _firestore.collection("reviews");
      QuerySnapshot lastReviewSnapshot =
          await reviewsRef.orderBy("ReviewID", descending: true).limit(1).get();

      String newReviewID;
      if (lastReviewSnapshot.docs.isEmpty) {
        newReviewID = "RVW0001"; // First review ID
      } else {
        // Extract last ReviewID and increment
        String lastReviewID = lastReviewSnapshot.docs.first["ReviewID"];
        RegExp regex = RegExp(r'RVW(\d{4})$');

        if (!regex.hasMatch(lastReviewID)) {
          newReviewID = "RVW0001"; // Fallback in case of incorrect format
        } else {
          int lastNumber = int.parse(regex.firstMatch(lastReviewID)!.group(1)!);
          newReviewID =
              "RVW${(lastNumber + 1).toString().padLeft(4, '0')}"; // Increment & format
        }
      }

      // ✅ Store the Review with the Custom ID
      await reviewsRef.doc(newReviewID).set({
        'ReviewID': newReviewID, // Custom review ID
        'StationID': widget.stationId,
        'CustomerID': customerID,
        'CustomerName': _username,
        'Rating': _rating,
        'ReviewText': _comment ?? "",
        'ReviewDate': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted successfully!")),
      );

      setState(() {
        _isSubmitting = false;
        _rating = 0;
        _reviewController.clear();
        _comment = "";
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting review: $e")),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Review",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.close, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Station Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          widget.stationImage,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.stationName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(widget.stationDescription,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                Icon(Icons.bolt, color: Colors.green, size: 18),
                                Text(" Available ",
                                    style: TextStyle(fontSize: 14)),
                                Icon(Icons.ev_station,
                                    color: Colors.black, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ Review Input Fields
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Share your experience:",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // ✅ User Info
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black12,
                          child: Icon(Icons.person, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _username,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ✅ Star Rating with Gesture Animation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    // ✅ Comment Box
                    TextField(
                      maxLines: 4,
                      maxLength: 500,
                      controller: _reviewController,
                      decoration: InputDecoration(
                        hintText: "Write your experience here (optional)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _comment = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Submit & Manage Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SUBMIT",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ Manage My Reviews Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ManageReviewsPage()),
                      );
                    },
                    icon: const Icon(Icons.settings, color: Colors.blue),
                    label: const Text(
                      "Manage My Reviews",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
