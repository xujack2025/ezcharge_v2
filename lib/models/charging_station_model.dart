import 'package:cloud_firestore/cloud_firestore.dart';

class ChargingStation {
  String stationID;
  String stationName;
  String description;
  String nearby;
  String location;
  String latitude;
  String longitude;
  int capacity;
  String imageUrl; // ✅ New field for image

  ChargingStation({
    required this.stationID,
    required this.stationName,
    required this.description,
    required this.nearby,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.imageUrl,
  });

  // Convert Firestore DocumentSnapshot to ChargingStation object
  factory ChargingStation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChargingStation(
      stationID: data['StationID'] ?? '',
      stationName: data['StationName'] ?? '',
      description: data['Description'] ?? '',
      nearby: data['Nearby']??'',
      location: data['Location'] ?? '',
      latitude: data['Latitude'] ?? '',
      longitude: data['Longitude'] ?? '',
      capacity: data['Capacity'] ?? 0,
      imageUrl: data['ImageUrl'] ?? '', // ✅ Load image URL from Firestore
    );
  }

  // Convert ChargingStation object to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'StationID': stationID,
      'StationName': stationName,
      'Description': description,
      'Nearby': nearby,
      'Location': location,
      'Latitude': latitude,
      'Longitude': longitude,
      'Capacity': capacity,
      'ImageUrl': imageUrl, // ✅ Store image URL in Firestore
    };
  }
}
