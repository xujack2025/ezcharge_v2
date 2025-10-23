import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReviewScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String stationDescription;
  final String stationImage;

  const ReviewScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.stationDescription,
    required this.stationImage,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  String _comment = "";
  String? _customerId;
  String _username = "";
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  /// 🔹 Fetch current logged-in user's details from Firestore
  Future<void> _fetchUserDetails() async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection("CTM250001")
            .doc(userId)
            .get();

        if (userDoc.exists) {
          setState(() {
            _customerId = userDoc["CustomerID"];
            _username ="${userDoc["FirstName"]} ${userDoc["LastName"]}"; // ✅ Prevents extra spaces
          });
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }


  /// 🔹 Submit the review to Firestore under the current customer
  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a rating!")),
      );
      return;
    }

    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: User not found! Please log in again.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String ratingId = "RTG${DateTime.now().millisecondsSinceEpoch}";
      String dateNow = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());

      // ✅ Save the review inside the customer's Firestore document
      await FirebaseFirestore.instance
          .collection("CTM250001") // ✅ Go to 'customers' collection
          .doc(_customerId) // ✅ Use the current user's CustomerID
          .collection("Rating") // ✅ Store the review inside 'Rating' subcollection
          .doc(ratingId)
          .set({
        "RatingID": "RTG${DateTime.now()}",
        "StationID": widget.stationId,
        "CustomerID": _customerId,
        "Rating": _rating,
        "Comments": _comment,
        "RatingDate": dateNow,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting review: $e")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ✅ Top App Bar
          Padding(
            padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Station Details Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    /*ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.stationImage,
                        width: 10,
                        height: 10,
                        fit: BoxFit.cover,
                      ),
                    ),*/
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.stationName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(widget.stationDescription,
                              style: const TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Row(
                            children: const [
                              Icon(Icons.bolt, color: Colors.green, size: 18),
                              Text(" Available "),
                              Icon(Icons.ev_station, color: Colors.black, size: 18),
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
                  const Text("Kindly tell us the reason you are reporting this bay:",
                      style: TextStyle(fontSize: 16)),

                  // ✅ User Info
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black12,
                        child: Icon(Icons.person, color: Colors.black),
                      ),
                      const SizedBox(width: 10),
                      Text(_username,style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,color: Colors.black)) ,


                    ],
                  ),

                  // ✅ Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Comment Box
                  TextField(
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: "Write your experience here (optional)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
          // ✅ Submit Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SUBMIT", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
