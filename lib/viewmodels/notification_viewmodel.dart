import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ezcharge/models/notification_model.dart';

class NotificationViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<NotificationModel> _notifications = [];

  List<NotificationModel> get notifications => _notifications;

  // ✅ Fetch All Notifications (Real-time Updates)
  Future<void> fetchNotifications() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notification') // ✅ Ensure collection name is correct
          .orderBy('CreatedTime', descending: true) // ✅ Ensure correct field name
          .get();

      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      notifyListeners(); // ✅ Notify UI to update
    } catch (e) {
      print("Error fetching notifications: $e");
    }
  }

  // ✅ Create a New Notification
  Future<void> createNotification(String title, String message) async {
    try {
      int epochTime = DateTime.now().millisecondsSinceEpoch;
      String notificationID = "NTF$epochTime";

      DocumentReference notificationRef = _firestore.collection('notification').doc(notificationID);

      NotificationModel newNotification = NotificationModel(
        notificationID: notificationID,
        title: title,
        description: message,
        createdTime: DateTime.now(),
        readTime: null,
      );

      await notificationRef.set(newNotification.toFirestore());
      notifyListeners();
    } catch (e) {
      throw Exception("Error creating notification: $e");
    }
  }


  // ✅ Update a Notification
  Future<void> updateNotification(String notificationId, String title, String message) async {
    try {
      await _firestore.collection('notification').doc(notificationId).update({
        'Title': title,
        'Description': message,
        'UpdatedAt': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      throw Exception("Error updating notification: $e");
    }
  }

  // ✅ Delete a Notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notification').doc(notificationId).delete();
      notifyListeners();
    } catch (e) {
      throw Exception("Error deleting notification: $e");
    }
  }

  // ✅ Send Notification to All Users
  Future<void> sendNotificationToAll(String title, String message) async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        await _firestore.collection('users').doc(userDoc.id).collection('notification').add({
          'Title': title,
          'Description': message,
          'CreatedAt': FieldValue.serverTimestamp(),
          'IsRead': false,
        });
      }
      notifyListeners();
    } catch (e) {
      throw Exception("Error sending notification: $e");
    }
  }

  // ✅ Mark Notification as Read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notification').doc(notificationId).update({'ReadTime': DateTime.now().toString()});
      notifyListeners();
    } catch (e) {
      throw Exception("Error marking notification as read: $e");
    }
  }
}
