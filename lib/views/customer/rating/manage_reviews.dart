import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ManageReviewsPage extends StatefulWidget {
  const ManageReviewsPage({super.key});

  @override
  State<ManageReviewsPage> createState() => _ManageReviewsPageState();
}

class _ManageReviewsPageState extends State<ManageReviewsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _customerID; // Store fetched CustomerID

  @override
  void initState() {
    super.initState();
    _fetchCustomerID(); // Fetch CustomerID once
  }

  // 🔹 **Fetch CustomerID Once**
  Future<void> _fetchCustomerID() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    var customerQuery = await _firestore
        .collection("customers")
        .where("PhoneNumber", isEqualTo: user.phoneNumber)
        .limit(1)
        .get();

    if (customerQuery.docs.isNotEmpty) {
      setState(() {
        _customerID = customerQuery.docs.first["CustomerID"];
      });
    }
  }

  // ✏️ Function to Edit Review
  void _editReview(BuildContext context, String reviewId, String currentText,
      dynamic currentRating) {
    TextEditingController reviewController =
        TextEditingController(text: currentText);
    double newRating = (currentRating is int)
        ? currentRating.toDouble()
        : (currentRating ?? 1.0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Review"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: "Update your review"),
                  ),
                  const SizedBox(height: 10),
                  // ⭐ Interactive Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            newRating = index +
                                1.0; // ✅ Updates state inside the dialog
                          });
                        },
                        child: Icon(
                          index < newRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    await _firestore
                        .collection("reviews")
                        .doc(reviewId)
                        .update({
                      "ReviewText": reviewController.text,
                      "Rating": newRating.toInt(),
                      // ✅ Ensure integer rating
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Review updated!")));
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ❌ Function to Delete Review
  void _deleteReview(String reviewId) async {
    await _firestore.collection("reviews").doc(reviewId).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Review deleted!")));
  }

  @override
  Widget build(BuildContext context) {
    if (_customerID == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Manage My Reviews"),
          elevation: 4,
          backgroundColor: Colors.blueAccent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage My Reviews"),
        elevation: 4,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection("reviews")
            .where("CustomerID", isEqualTo: _customerID)
            .orderBy("ReviewDate", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No reviews found.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            );
          }

          var reviews = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reviews.length,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemBuilder: (context, index) {
              var review = reviews[index].data() as Map<String, dynamic>;
              String reviewId = reviews[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: Colors.black26,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.rate_review, color: Colors.blue),
                  ),
                  title: Text(
                    review["ReviewText"] ?? "No review",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      _buildStars((review["Rating"] as num?)?.toInt() ?? 0),
                      const SizedBox(width: 10),
                      Text(
                        review["ReviewDate"]
                                ?.toDate()
                                .toString()
                                .split(" ")[0] ??
                            "No date",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "edit") {
                        _editReview(context, reviewId, review["ReviewText"],
                            review["Rating"]);
                      } else if (value == "delete") {
                        _deleteReview(reviewId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: "edit", child: Text("Edit Review")),
                      const PopupMenuItem(
                          value: "delete", child: Text("Delete Review")),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ⭐ Function to build star rating display with customization
  Widget _buildStars(int? rating, {double size = 18}) {
    int safeRating = (rating ?? 0).clamp(0, 5); // Ensure rating is between 0-5

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            index < safeRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}
