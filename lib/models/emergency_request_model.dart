import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyRequest {
  String requestID;
  String customerID;
  GeoPoint location; // ✅ Store as GeoPoint in Firestore
  String address; // ✅ Separate field to store the human-readable address
  String bookingReason;
  String? imageUrl;
  String preferredTime;
  String status; // Pending, Upcoming, Charging, Payment, Processing, Completed
  String? driverID;
  int eta;
  double kWhUsed;
  String? chatID;

  EmergencyRequest({
    required this.requestID,
    required this.customerID,
    required this.location, // ✅ GeoPoint for Firestore
    required this.address, // ✅ String for UI display
    required this.bookingReason,
    this.imageUrl,
    required this.preferredTime,
    required this.status,
    this.driverID,
    this.eta = 0,
    this.kWhUsed = 0,
    this.chatID,
  });

  /// 🔹 Convert to Firestore
  Map<String, dynamic> toMap() {
    return {
      'requestID': requestID,
      'CustomerID': customerID,
      'location': location, // ✅ Store as GeoPoint
      'address': address, // ✅ Store human-readable address
      'bookingReason': bookingReason,
      'imageUrl': imageUrl,
      'preferredTime': preferredTime,
      'status': status,
      'driverID': driverID,
      'eta': eta,
      'kWhUsed': kWhUsed,
      'chatID': chatID,
    };
  }

  /// 🔹 Convert from Firestore
  factory EmergencyRequest.fromMap(Map<String, dynamic> map) {
    return EmergencyRequest(
      requestID: map['requestID'] ?? '',
      customerID: map['CustomerID'] ?? '',
      location: map['location'] is GeoPoint ? map['location'] as GeoPoint : GeoPoint(0, 0), // ✅ Handle GeoPoint
      address: map['address'] ?? '', // ✅ Readable address for UI
      bookingReason: map['bookingReason'] ?? '',
      imageUrl: map['imageUrl'],
      preferredTime: map['preferredTime'] ?? '',
      status: map['status'] ?? 'Pending',
      driverID: map['driverID'] ?? '',
      eta: (map['eta'] as num?)?.toInt() ?? 0,
      kWhUsed: (map['kWhUsed'] as num?)?.toDouble() ?? 0.0,
      chatID: map['chatID'] ?? '',
    );
  }
}
