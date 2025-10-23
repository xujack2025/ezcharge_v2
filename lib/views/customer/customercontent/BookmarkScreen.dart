import 'package:ezcharge/views/EZCHARGE/StationScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  _BookmarkScreenState createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  List<Map<String, dynamic>> _bookmarkedStations = [];
  String _accountId = "";
  bool _isLoading = true;

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
          setState(() {
            _accountId = querySnapshot.docs.first["CustomerID"];
          });

          // Fetch bookmarks after getting CustomerID
          _fetchBookmarkedStations();
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
      setState(() => _isLoading = false);
    }
  }

  //Fetch Bookmarked Stations
  Future<void> _fetchBookmarkedStations() async {
    if (_accountId.isEmpty) return;

    try {
      QuerySnapshot bookmarkSnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("bookmark")
          .get();

      List<Map<String, dynamic>> bookmarks = [];

      for (var bookmarkDoc in bookmarkSnapshot.docs) {
        String stationId = bookmarkDoc["StationID"];

        DocumentSnapshot stationSnapshot = await FirebaseFirestore.instance
            .collection("station")
            .doc(stationId)
            .get();

        if (stationSnapshot.exists) {
          Map<String, dynamic> stationData =
              stationSnapshot.data() as Map<String, dynamic>;
          stationData["BookmarkID"] =
              bookmarkDoc.id; // Store BookmarkID for removal
          bookmarks.add(stationData);
        }
      }

      setState(() {
        _bookmarkedStations = bookmarks;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching bookmarked stations: $e");
      setState(() => _isLoading = false);
    }
  }

  //Remove Bookmark
  Future<void> _removeBookmark(String bookmarkId) async {
    try {
      await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("bookmark")
          .doc(bookmarkId)
          .delete();

      setState(() {
        _bookmarkedStations
            .removeWhere((station) => station["BookmarkID"] == bookmarkId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bookmark removed!")),
      );
    } catch (e) {
      print("Error removing bookmark: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
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
        title: const Text("Bookmark",
            style: TextStyle(
                color: Colors.black,
                fontSize: 25,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarkedStations.isEmpty
              ? const Center(child: Text("No bookmarked stations found!"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarkedStations.length,
                  itemBuilder: (context, index) {
                    final station = _bookmarkedStations[index];
                    return _buildStationCard(station);
                  },
                ),
    );
  }

  /// 🔹 Build Station Card (with Remove Bookmark Option)
  Widget _buildStationCard(Map<String, dynamic> station) {
    return GestureDetector(
      onTap: () {
        //Redirect to StationScreen with StationID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StationScreen(stationId: station["StationID"]),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 1),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  //Station Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      station["ImageUrl"] ?? "https://via.placeholder.com/80",
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 15),
                  //Station Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station["StationName"],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          station["Description"] ?? "",
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Bookmark Icon (Remove)
                  IconButton(
                    icon: const Icon(Icons.bookmark,
                        color: Colors.black), // Default Black
                    onPressed: () => _removeBookmark(station["BookmarkID"]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
