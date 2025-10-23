import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  String driverID;
  String firstName;
  String lastName;
  String phone;
  GeoPoint location;
  String status; // Available, Busy, Offline

  Driver({
    required this.driverID,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.location,
    required this.status,
  });

  // Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'driverID': driverID,
      'FirstName': firstName,
      'LastName': lastName,
      'phone': phone,
      'location': location, // ✅ Now storing as GeoPoint
      'status': status,
    };
  }

  // Convert from Firestore
  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      driverID: map['driverID'] ?? '',
      firstName: map['FirstName'] ?? '',
      lastName: map['LastName'] ?? '',
      phone: map['PhoneNumber'] ?? '',
      location: map['location'] ?? GeoPoint(0.0, 0.0), // ✅ Ensure default GeoPoint
      status: map['status'] ?? 'Offline',
    );
  }
}
