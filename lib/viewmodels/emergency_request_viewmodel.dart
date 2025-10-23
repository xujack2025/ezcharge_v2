import 'dart:io';

import 'package:ezcharge/models/emergency_request_model.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EmergencyRequestViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  File? selectedImage;
  String? uploadedImageUrl;
  DateTime? scheduledDateTime;
  bool isLoading = false;

  /// ✅ Get Emergency Requests as a Stream (Real-time Updates)
  Stream<List<EmergencyRequest>> getRequests(String customerID) {
    return _firestore
        .collection('emergency_requests')
        .where('customerID', isEqualTo: customerID)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                EmergencyRequest.fromMap(doc.data()))
            .toList());
  }

  /// ✅ Create Emergency Request
  Future<void> createRequest(EmergencyRequest request) async {
    try {
      // Generate a unique request ID in the format: EMQ_<timestamp>
      String requestID = "EMQ${DateTime.now().millisecondsSinceEpoch}";

      // ✅ Ensure request ID is updated before saving
      request = EmergencyRequest(
          requestID: requestID,
          customerID: request.customerID,
          location: request.location,
          address: request.address,
          bookingReason: request.bookingReason,
          preferredTime: request.preferredTime,
          status: request.status,
          imageUrl: request.imageUrl);

      await _firestore
          .collection('emergency_requests')
          .doc(requestID) // ✅ Use generated request ID
          .set(request.toMap());

      print("✅ Emergency request created successfully: $requestID");
    } catch (e) {
      print("❌ Error creating request: $e");
    }
  }

  /// ✅ Update Request Status (Real-time Changes)
  Future<void> updateRequestStatus(String requestID, String status) async {
    try {
      await _firestore
          .collection('emergency_requests')
          .doc(requestID)
          .update({'status': status});
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  /// ✅ Select Image (Gallery or Camera)
  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      selectedImage = File(pickedFile.path);
      uploadedImageUrl = null; // ✅ Reset URL (New Image Needs Upload)
      notifyListeners();
    }
  }

  /// ✅ Upload Image to Firebase Storage
  Future<String?> uploadImageToFirebase() async {
    if (selectedImage == null) {
      print("⚠️ No image selected. Skipping upload.");
      return null;
    }

    try {
      isLoading = true;
      notifyListeners(); // ✅ Show loading state

      String fileName =
          "requests/RQImage${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(selectedImage!);

      // ✅ Wait for upload to complete
      TaskSnapshot taskSnapshot = await uploadTask;

      // ✅ Get the uploaded image URL
      String imageUrl = await taskSnapshot.ref.getDownloadURL();
      uploadedImageUrl = imageUrl;

      print("✅ Image uploaded successfully: $imageUrl");

      return imageUrl; // ✅ Return image URL for Firestore
    } catch (e) {
      print("❌ Image Upload Error: $e");
      return null; // ✅ Handle failure case
    } finally {
      isLoading = false;
      notifyListeners(); // ✅ Ensure UI updates after upload (success or failure)
    }
  }

  /// ✅ Show DateTime Picker for Scheduling
  Future<void> pickDateTime(BuildContext context) async {
    DateTime now = DateTime.now().toUtc().add(const Duration(hours: 8));
    //DateTime now = DateTime.now().toUtc().add(const Duration(hours: 8)); // ✅ Convert to UTC+8
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        scheduledDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );//.toUtc().add(const Duration(hours: 8)); // ✅ Ensure selected time is also UTC+8

        notifyListeners();
      }
    }
  }


  /// 🔹 **Calculate Fee**
  double calculateFee(double kWhUsed) {
    const double baseFee = 8.0;
    const double perKWhCharge = 1.5;
    return baseFee + (kWhUsed * perKWhCharge);
  }

  /// 🔹 **Update Status to Charging**
  Future<void> startCharging(String requestID) async {
    await _firestore.collection('emergency_requests').doc(requestID).update({
      'status': 'Charging',
    });
  }

  /// 🔹 **Update Charging Completed & Set Payment Due**
  Future<void> updateChargingComplete(String requestID, double kWhUsed) async {
    double totalCost = calculateFee(kWhUsed);
    await _firestore.collection('emergency_requests').doc(requestID).update({
      'kWhUsed': kWhUsed,
      'estimatedCost': totalCost,
      'status': 'Payment',
    });
  }

  /// 🔹 **Process Payment**
  Future<void> processPayment(String requestID) async {
    await _firestore.collection('emergency_requests').doc(requestID).update({
      'status': 'Completed',
    });
  }
}
