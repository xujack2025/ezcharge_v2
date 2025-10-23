import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ezcharge/models/charging_bay_model.dart';

class ChargingStationViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final List<Map<String, dynamic>> _stations = [];

  List<Map<String, dynamic>> get stations => _stations;

  Stream<List<Map<String, dynamic>>> fetchChargingStationsStream() {
    return _firestore.collection('station').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return {
          "stationID": doc.id,
          "stationName": data["StationName"] ?? '',
          "description": data["Description"] ?? '',
          "nearby": data["Nearby"] ?? '',
          "location": data["Location"] ?? '',
          "latitude": data["Latitude"] ?? '',
          "longitude": data["Longitude"] ?? '',
          "capacity": data["Capacity"] ?? 0,
          "occupied_bays": data["OccupiedBays"] ?? 0,
          "capacity_status": data["CapacityStatus"] ?? "Optimal",
          "imageUrl": data["ImageUrl"] ?? '',
        };
      }).toList();
    });
  }

  // ✅ Real-time Fetch Charging Bays (Uses Stream)
  Stream<List<ChargingBay>> fetchChargingBaysStream(String stationID) {
    return _firestore
        .collection('station')
        .doc(stationID)
        .collection('Charger')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChargingBay.fromFirestore(doc))
            .toList());
  }

  // ✅ Create Charging Station (Capacity Initially 0, Occupied Bays 0)
  Future<void> createChargingStation({
    required String stationName,
    required String description,
    required String nearby,
    required String location,
    required String latitude,
    required String longitude,
    File? imageFile,
  }) async {
    try {
      String newStationID = await generateNewStationID();
      String imageUrl = "";

      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile, newStationID) ?? '';
      }

      await _firestore.collection('station').doc(newStationID).set({
        "StationID": newStationID,
        "StationName": stationName,
        "Description": description,
        "Nearby": nearby,
        "Location": location,
        "Latitude": latitude,
        "Longitude": longitude,
        "Capacity": 0, // Initially 0 until bays are added
        "OccupiedBays": 0, // No bays in use initially
        "CapacityStatus": "Optimal", // Default Status
        "ImageUrl": imageUrl,
      });
    } catch (e) {
      print("Error adding charging station: $e");
    }
  }

  Future<String> generateNewStationID() async {
    try {
      // ✅ Query Firestore to get the latest station ID
      QuerySnapshot snapshot = await _firestore
          .collection('station')
          .orderBy('StationID', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return "STT100001"; // ✅ First station ID if no records exist
      }

      // ✅ Extract the latest ID
      String lastID = snapshot.docs.first['StationID']; // Example: "STT100010"
      int lastNumber = int.parse(lastID.substring(3)); // Extracts "100010"
      int newNumber = lastNumber + 1; // Increment by 1

      // ✅ Format new ID (STT100011)
      return "STT${newNumber.toString().padLeft(6, '0')}";
    } catch (e) {
      print("Error generating new StationID: $e");
      return "STT100001"; // Fallback if an error occurs
    }
  }

  // ✅ Update Charging Station Details
  Future<void> updateChargingStation({
    required String stationID,
    required String stationName,
    required String description,
    required String nearby,
    required String location,
    required String latitude,
    required String longitude,
    File? imageFile,
  }) async {
    try {
      String imageUrl = "";
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile, stationID) ?? '';
      }

      Map<String, dynamic> updatedData = {
        "StationName": stationName,
        "Description": description,
        "Nearby": nearby,
        "Location": location,
        "Latitude": latitude,
        "Longitude": longitude,
      };

      if (imageUrl.isNotEmpty) {
        updatedData["ImageUrl"] = imageUrl;
      }

      await _firestore.collection('station').doc(stationID).update(updatedData);
    } catch (e) {
      print("Error updating charging station: $e");
    }
  }

  // ✅ Delete Charging Station
  Future<void> deleteChargingStation(String stationID) async {
    try {
      await _firestore.collection('station').doc(stationID).delete();
    } catch (e) {
      print("Error deleting charging station: $e");
    }
  }

  // ✅ Fetch Charging Bays with Detailed Data
  Future<List<ChargingBay>> fetchChargingBays(String stationID) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('station')
          .doc(stationID)
          .collection('Charger')
          .get();

      for (var doc in snapshot.docs) {
        print("🔍 Raw Firestore Data: ${doc.data()}"); // ✅ Debugging line
      }

      return snapshot.docs
          .map((doc) => ChargingBay.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("❌ Error fetching charging bays: $e");
      return [];
    }
  }

  // ✅ Add Charging Bay with Full Details
  Future<void> addChargingBay(String stationID, ChargingBay bay) async {
    try {
      await _firestore
          .collection('station')
          .doc(stationID)
          .collection('Charger')
          .doc(bay.chargerID)
          .set({
        ...bay.toMap(),
        "Status": "Available", // ✅ Ensure "status" field exists
      }, SetOptions(merge: true)); // ✅ Merge to prevent overwriting

      await updateCapacity(stationID); // ✅ Update capacity after adding bay
    } catch (e) {
      print("❌ Error adding charging bay: $e");
    }
  }

  // ✅ Update Charging Bay Details
  Future<void> updateChargingBay(String stationID, ChargingBay bay) async {
    try {
      await _firestore
          .collection('station')
          .doc(stationID)
          .collection('Charger')
          .doc(bay.chargerID)
          .update(bay.toMap());
    } catch (e) {
      print("Error updating charging bay: $e");
    }
  }

  // ✅ Delete Charging Bay
  Future<void> deleteChargingBay(String stationID, String chargerID) async {
    try {
      await _firestore
          .collection('station')
          .doc(stationID)
          .collection('Charger')
          .doc(chargerID)
          .delete();

      await updateCapacity(stationID); // Update Capacity Automatically
    } catch (e) {
      print("Error deleting charging bay: $e");
    }
  }

  // ✅ Pick Image from Gallery or Camera
  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery); // Can change to camera

    if (pickedFile != null) {
      return File(pickedFile.path);
    }
    return null;
  }

  Future<String?> getStationImage(String stationID) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('station').doc(stationID).get();
      if (doc.exists && doc['ImageUrl'] != null) {
        return doc['ImageUrl'];
      }
    } catch (e) {
      print("Error fetching station image: $e");
    }
    return null;
  }

  // ✅ Upload Image to Firebase Storage and Get URL
  Future<String?> uploadImage(File imageFile, String stationID) async {
    try {
      Reference ref = _storage
          .ref()
          .child('charging_stations/$stationID.jpg'); // ✅ Correct path
      UploadTask uploadTask = ref.putFile(imageFile);

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});

      if (snapshot.state == TaskState.success) {
        // ✅ Ensure upload is successful
        return await snapshot.ref.getDownloadURL(); // ✅ Get image URL
      } else {
        print("Image upload failed");
        return null;
      }
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  // ✅ Auto Update Capacity, Occupied Bays & Capacity Status
  Future<void> updateCapacity(String stationID) async {
    try {
      QuerySnapshot chargerSnapshot = await _firestore
          .collection('station')
          .doc(stationID)
          .collection('Charger')
          .get();

      int totalBays = chargerSnapshot.docs.length;

      // ✅ Count occupied bays based on "status"
      int occupiedBays = chargerSnapshot.docs.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data.containsKey("Status") && data["Status"] == "Occupied";
      }).length;

      // ✅ Determine Capacity Status
      String capacityStatus;
      if (occupiedBays == totalBays && totalBays > 0) {
        capacityStatus = "Overloaded";
      } else if (totalBays == 0) {
        capacityStatus = "Undefined";
      } else if (occupiedBays >= (totalBays * 0.75).toInt()) {
        capacityStatus = "High Demand";
      } else {
        capacityStatus = "Optimal";
      }

      // ✅ Update Firestore Document
      await _firestore.collection('station').doc(stationID).update({
        "Capacity": totalBays,
        "OccupiedBays": occupiedBays,
        "CapacityStatus": capacityStatus,
      });

      print(
          "✅ Updated Station $stationID → Capacity: $totalBays, Occupied: $occupiedBays, Status: $capacityStatus");
    } catch (e) {
      print("❌ Error updating capacity: $e");
    }
  }
}
