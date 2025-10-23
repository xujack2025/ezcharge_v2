import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:ezcharge/secrets.dart';

const String googleMapsApiKey = Secrets.googleMapsApiKey;

class TrackingViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LatLng? driverLocation;
  LatLng? customerLocation;
  int estimatedTime = 0;

  /// ✅ Stream to Track Driver's Live Location
  Stream<DocumentSnapshot> trackDriverLocation(String driverID) {
    return _firestore.collection('drivers').doc(driverID).snapshots();
  }

  /// ✅ Extracts Driver Location from Firestore (Handles GeoPoint)
  LatLng? parseDriverLocation(DocumentSnapshot snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      final Map<String, dynamic> driverData = snapshot.data() as Map<String, dynamic>;

      if (driverData.containsKey('location')) {
        final location = driverData['location'];
        if (location is GeoPoint) {
          return LatLng(location.latitude, location.longitude);
        }
      }
    }
    return null;
  }

  /// ✅ Stream to Get Tracking Info (Customer Request)
  Stream<DocumentSnapshot> getTrackingInfo(String requestID) {
    return _firestore.collection('emergency_requests').doc(requestID).snapshots();
  }

  /// ✅ Convert Address to LatLng Using Google Geocoding API
  Future<LatLng?> convertAddressToLatLng(String address) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=${Secrets.googleMapsApiKey}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "OK") {
          double lat = data["results"][0]["geometry"]["location"]["lat"];
          double lng = data["results"][0]["geometry"]["location"]["lng"];
          return LatLng(lat, lng);
        } else {
          print("❌ Geocoding API Error: ${data["status"]}");
        }
      }
    } catch (e) {
      print("❌ Error fetching LatLng: $e");
    }
    return null;
  }
}
