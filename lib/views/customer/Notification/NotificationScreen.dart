import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ezcharge/views/EZCHARGE/HomeScreen.dart';
import 'package:ezcharge/views/customer/Reward/RewardScreen.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasNewNotification = false; // Track if there's a new notification

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  //Fetch Notifications from Firestore

  Future<void> _fetchNotifications() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("notification")
          .orderBy("CreatedTime", descending: true)
          .get();

      setState(() {
        _notifications = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;

          // Convert Firestore Timestamp to DateTime and then format it
          String formattedCreatedTime = "";
          String? formattedReadTime;

          if (data["CreatedTime"] is Timestamp) {
            formattedCreatedTime =
                DateFormat("dd MMM yyyy").format(data["CreatedTime"].toDate());
          }

          if (data["ReadTime"] is Timestamp) {
            formattedReadTime = DateFormat("dd MMM yyyy HH:mm:ss")
                .format(data["ReadTime"].toDate());
          }

          return {
            "id": doc.id,
            "title": data["Title"],
            "description": data["Description"],
            "createdTime": formattedCreatedTime, // ✅ Now a formatted String
            "readTime":
                formattedReadTime, // ✅ Now a formatted String (nullable)
          };
        }).toList();

        _hasNewNotification = _notifications.any((n) => n["readTime"] == null);
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching notifications: $e");
      setState(() => _isLoading = false);
    }
  }

  //Mark notification as read & update Firestore
  void _markAsRead(String notificationId) async {
    String readTime = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());

    await FirebaseFirestore.instance
        .collection("notification")
        .doc(notificationId)
        .update({"ReadTime": readTime});

    setState(() {
      _notifications = _notifications.map((notification) {
        if (notification["id"] == notificationId) {
          notification["readTime"] = readTime;
        }
        return notification;
      }).toList();

      // Check if there are still unread notifications
      _hasNewNotification = _notifications.any((n) => n["readTime"] == null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          "Notifications",
          style: TextStyle(
              color: Colors.black, fontSize: 30, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) //Show loading
          : _notifications.isEmpty
              ? const Center(child: Text("No notifications available."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    var notification = _notifications[index];
                    return _buildNotificationItem(notification);
                  },
                ),
      bottomNavigationBar: _buildBottomNavBar(context), //Updated with red dot
    );
  }

  //Build a Notification Item
  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    bool isRead = notification["readTime"] != null;

    return InkWell(
      onTap: () {
        _markAsRead(notification["id"]); //Mark notification as read
        _showNotificationDetails(notification);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: isRead
            ? Colors.white
            : Colors.blue[50], //Highlight unread notifications
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification["title"],
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(notification["description"],
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Text(
                notification["createdTime"],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //Show Expanded Notification Details
  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(notification["title"],
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Text(notification["description"]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  //Bottom Navigation Bar with Red Dot Indicator
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      currentIndex: 3,
      onTap: (index) {
        if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const AccountScreen()));
        } else if (index == 1) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const RewardScreen()));
        } else if (index == 0) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      },
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.directions_car), label: "EZCharge"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard), label: "Rewards"),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Me"),
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              const Icon(Icons.mail),
              if (_hasNewNotification) //Show red dot if there’s a new notification
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          label: "Inbox",
        ),
      ],
    );
  }
}
