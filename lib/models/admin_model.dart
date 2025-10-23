import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String adminID;
  final String firstName;
  final String lastName;
  final String gender;
  final String emailAddress;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final Timestamp createdAt;

  AdminModel({
    required this.adminID,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.emailAddress,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.createdAt,
  });

  // ✅ Convert Firestore document to AdminModel
  factory AdminModel.fromFirestore(Map<String, dynamic> data) {
    return AdminModel(
      adminID: data['AdminID'] ?? '',
      firstName: data['FirstName'] ?? '',
      lastName: data['LastName'] ?? '',
      gender: data['Gender'] ?? '',
      emailAddress: data['EmailAddress'] ?? '',
      phoneNumber: data['PhoneNumber'] ?? '',
      dateOfBirth: (data['DateOfBirth'] as Timestamp).toDate(),
      createdAt: data['CreatedAt'] ?? Timestamp.now(),
    );
  }

  // ✅ Convert AdminModel to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'AdminID': adminID,
      'FirstName': firstName,
      'LastName': lastName,
      'Gender': gender,
      'EmailAddress': emailAddress,
      'PhoneNumber': phoneNumber,
      'DateOfBirth': Timestamp.fromDate(dateOfBirth),
      'CreatedAt': createdAt,
    };
  }
}
