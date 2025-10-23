import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationID;
  final String title;
  final String description;
  final DateTime createdTime;
  final String? readTime; // Nullable because it might be unread

  NotificationModel({
    required this.notificationID,
    required this.title,
    required this.description,
    required this.createdTime,
    this.readTime,
  });

  // ✅ Convert Firestore document to `NotificationModel` object
  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return NotificationModel(
      notificationID: documentId,
      title: data['Title'] ?? '',
      description: data['Description'] ?? '',
      createdTime: (data['CreatedTime'] as Timestamp).toDate(),
      readTime: data['ReadTime'],
    );
  }

  // ✅ Convert `NotificationModel` object to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'NotificationID': notificationID,
      'Title': title,
      'Description': description,
      'CreatedTime': createdTime,
      'ReadTime': readTime,
    };
  }
}
