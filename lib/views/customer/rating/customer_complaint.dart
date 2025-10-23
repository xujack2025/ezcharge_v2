import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import 'package:ezcharge/views/customer/rating/manage_complaint.dart';

class CustomerComplaintPage extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String stationDescription;
  final String stationImage;

  const CustomerComplaintPage({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.stationDescription,
    required this.stationImage,
  });

  @override
  State<CustomerComplaintPage> createState() => _CustomerComplaintPageState();
}

class _CustomerComplaintPageState extends State<CustomerComplaintPage> {
  String? _selectedBay;
  String? _reportReason;
  String? _details;
  String? _uploadedImage;
  File? _selectedImage;
  bool _isSubmitting = false;
  List<Map<String, String>> _chargingBays =
      []; // Stores ChargerID & ChargerName
  String? _selectedBayID; // Stores selected ChargerID
  String? _selectedBayName; // Stores selected ChargerName

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchChargingBays();
  }

  /// Function to fetch bays from Firestore
  Future<void> _fetchChargingBays() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("station")
          .doc(widget.stationId) // Fetch chargers for the current station
          .collection("Charger")
          .get();

      List<Map<String, String>> fetchedBays = querySnapshot.docs.map((doc) {
        return {
          "ChargerID": doc["ChargerID"]?.toString() ?? "Unknown ID",
          "ChargerName": doc["ChargerName"]?.toString() ?? "Unknown Bay",
        };
      }).toList();

      if (mounted) {
        setState(() {
          _chargingBays = fetchedBays;
        });
      }
    } catch (e) {
      print("Error fetching charging bays: $e");
      if (mounted) {
        setState(() {
          _chargingBays = [];
        });
      }
    }
  }

  /// Function to pick an image
  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  /// Function to upload image to Firebase Storage
  Future<String?> _uploadImage(File imageFile, String complaintDocID) async {
    try {
      String fileName = "complaints/${widget.stationId}/$complaintDocID.jpg";
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL(); // Returns image URL
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  /// Function to submit complaint
  Future<void> _submitComplaint() async {
    if (_isSubmitting) return;

    // ✅ Ensure both fields are selected
    if (_selectedBayID == null || _reportReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a bay and report reason.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ Get Current User
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in.")),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // ✅ Retrieve Customer ID
      var customerQuery = await FirebaseFirestore.instance
          .collection("customers")
          .where("PhoneNumber", isEqualTo: user.phoneNumber)
          .limit(1)
          .get();

      if (customerQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Customer profile not found.")),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      String customerID = customerQuery.docs.first["CustomerID"];

      // ✅ Generate Complaint ID
      QuerySnapshot complaintSnapshot = await FirebaseFirestore.instance
          .collection("customers")
          .doc(customerID)
          .collection("complaints")
          .orderBy("ComplaintID", descending: true)
          .limit(1)
          .get();

      int nextComplaintNumber = 1;
      if (complaintSnapshot.docs.isNotEmpty) {
        String lastComplaintID = complaintSnapshot.docs.first["ComplaintID"];
        RegExp regex = RegExp(r'CMP(\d+)$');

        if (regex.hasMatch(lastComplaintID)) {
          int lastNumber =
              int.parse(regex.firstMatch(lastComplaintID)!.group(1)!);
          nextComplaintNumber = lastNumber + 1;
        }
      }

      String newComplaintID =
          "CMP${nextComplaintNumber.toString().padLeft(4, '0')}";
      String complaintDocID =
          "$customerID-$newComplaintID"; // Format: CTMxxxxx-CMPxxxx

      // ✅ Upload Image (If Selected)
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!, complaintDocID);
      }

      // ✅ Save Complaint to Firestore
      await FirebaseFirestore.instance
          .collection("customers")
          .doc(customerID)
          .collection("complaints")
          .doc(complaintDocID)
          .set({
        'ComplaintID': newComplaintID,
        'CustomerID': customerID,
        'StationID': widget.stationId,
        'SlotID': _selectedBayID, // ✅ Save ChargerID
        'ChargerBay': _selectedBayName, // ✅ Save ChargerName
        'Reason': _reportReason,
        'Description': _details ?? "",
        'ImageUrl': imageUrl ?? "",
        'ComplaintDate': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'AdminID': null,
        'AssignedStaffID': null,
        'status': "Pending",
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complaint submitted successfully!")),
      );

      setState(() {
        _isSubmitting = false;
        _selectedBay = null;
        _reportReason = null;
        _details = null;
        _selectedImage = null;
      });

      Navigator.pop(context); // ✅ Close after submission
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting complaint: $e")),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 AppBar with Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Report",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🔹 Station Details Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.stationImage,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.stationName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            widget.stationDescription,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 5),
                          const Row(
                            children: [
                              Icon(Icons.bolt, color: Colors.green, size: 18),
                              Text(" Available "),
                              Icon(Icons.ev_station,
                                  color: Colors.black, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Select Charging Bay
            const Text("Location Bay *",
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _selectedBayID,
              hint: const Text("Select Bay"),
              items: _chargingBays.map((bay) {
                return DropdownMenuItem(
                  value: bay["ChargerID"], // ✅ Store ChargerID
                  child: Text(bay["ChargerName"] ??
                      "Unknown Bay"), // ✅ Show ChargerName
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBayID = value; // ✅ Store ChargerID
                  _selectedBayName = _chargingBays.firstWhere(
                    (bay) => bay["ChargerID"] == value,
                    orElse: () => {"ChargerName": "Unknown"},
                  )["ChargerName"]; // ✅ Get the name for display
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 15),

            // 🔹 Select Report Reason
            const Text("Report Reason *",
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _reportReason,
              hint: const Text("Report Reason"),
              items: ["Charger not working", "Blocked bay", "Payment issue"]
                  .map((reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)))
                  .toList(),
              onChanged: (value) => setState(() => _reportReason = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),

            // 🔹 Details (Optional)
            const Text("Details",
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Write your reason here (optional)",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _details = value),
            ),
            const SizedBox(height: 15),

            // 🔹 Upload Photo Section
            const Text("Upload Photo (Optional)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: _selectedImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.grey),
                            Text("Select Photo"),
                          ],
                        )
                      : Image.file(_selectedImage!,
                          width: 100, height: 100, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint,
                // Calls the function
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),

            // 🔹 Manage Complaints Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ManageComplaintsPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text("MANAGE COMPLAINTS",
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
