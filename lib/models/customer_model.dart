import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String customerID;
  final String firstName;
  final String lastName;
  final String gender;
  final String emailAddress;
  final String phoneNumber;
  final double walletBalance;
  final int pointBalance;
  final DateTime dateOfBirth;
  final Timestamp createdAt;

  CustomerModel({
    required this.customerID,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.emailAddress,
    required this.phoneNumber,
    required this.walletBalance,
    required this.pointBalance,
    required this.dateOfBirth,
    required this.createdAt,
  });

  // ✅ Convert Firestore document to CustomerModel
  factory CustomerModel.fromFirestore(Map<String, dynamic> data) {
    return CustomerModel(
      customerID: data['CustomerID'] ?? '',
      firstName: data['FirstName'] ?? '',
      lastName: data['LastName'] ?? '',
      gender: data['Gender'] ?? '',
      emailAddress: data['EmailAddress'] ?? '',
      phoneNumber: data['PhoneNumber'] ?? '',
      walletBalance: (data['WalletBalance'] ?? 0.0).toDouble(),
      pointBalance: data['PointBalance'] ?? 0,
      dateOfBirth: (data['DateOfBirth'] as Timestamp).toDate(),
      createdAt: data['CreatedAt'] ?? Timestamp.now(),
    );
  }

  // ✅ Convert CustomerModel to Firestore document format
  Map<String, dynamic> toFirestore() {
    return {
      'CustomerID': customerID,
      'FirstName': firstName,
      'LastName': lastName,
      'Gender': gender,
      'EmailAddress': emailAddress,
      'PhoneNumber': phoneNumber,
      'WalletBalance': walletBalance,
      'PointBalance': pointBalance,
      'DateOfBirth': Timestamp.fromDate(dateOfBirth),
      'CreatedAt': createdAt,
    };
  }
}
