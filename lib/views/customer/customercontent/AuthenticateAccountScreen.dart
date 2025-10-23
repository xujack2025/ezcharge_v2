import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:ezcharge/views/customer/customercontent/UploadSelfieScreen.dart';

class AuthenticateAccountScreen extends StatefulWidget {
  const AuthenticateAccountScreen({super.key});

  @override
  State<AuthenticateAccountScreen> createState() =>
      _AuthenticateAccountScreenState();
}

class _AuthenticateAccountScreenState extends State<AuthenticateAccountScreen> {
  final ImagePicker picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _getCustomerID();
  }

  File? _licenseImage;
  final bool _isUploading = false;
  String _accountId = "";

  //Pick Image from Gallery
  Future<void> _getImageFromGallery() async {
    final XFile? galleryImage =
    await picker.pickImage(source: ImageSource.gallery);
    if (galleryImage != null) {
      setState(() {
        _licenseImage = File(galleryImage.path);
      });
    }
  }

  //Take Picture from Camera
  Future<void> _getImageFromCamera() async {
    final XFile? cameraImage =
    await picker.pickImage(source: ImageSource.camera);
    if (cameraImage != null) {
      setState(() {
        _licenseImage = File(cameraImage.path);
      });
    }
  }

// Fetch current log in user id from Firestore
  Future<void> _getCustomerID() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) return;

        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;

          setState(() {
            _accountId = userDoc["CustomerID"];
          });
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }

  //Upload Image to Firebase Storage with better user feedback
  Future<void> _uploadLicenseImage() async {
    if (_licenseImage == null) return;

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Uploading... Please wait"),
          ],
        ),
      ),
    );

    try {
      // Generate unique filename
      final fileName = '$_accountId${path.extension(_licenseImage!.path)}';
      final Reference storageRef =
      FirebaseStorage.instance.ref().child('license/$fileName');

      // Upload file
      UploadTask uploadTask = storageRef.putFile(_licenseImage!);

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            "Uploading: ${snapshot.bytesTransferred} / ${snapshot.totalBytes}");
      });

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Close Loading Dialog
      Navigator.pop(context);

      // Show Success Dialog
      _showSuccessDialog(downloadUrl);
    } catch (error) {
      Navigator.pop(context); // Close Loading Dialog
      _showErrorDialog("Failed to upload image. Please try again.");
      print("Upload error: $error");
    }
  }

  //Show Success Dialog
  void _showSuccessDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upload Successful"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            Text("Your license has been uploaded successfully."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Dismiss the current screen or dialog
              Navigator.pop(context);
              // Navigate to TopUpScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UploadSelfieScreen()),
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Show Error Dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upload Failed", style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Authenticate Account",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          //Step Indicator "1/2"
          Container(
            width: double.infinity,
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: const Text(
              "Step 1/2",
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 20),

          //Upload Driving License Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black45, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: _licenseImage == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_outlined,
                        size: 50, color: Colors.black45),
                    SizedBox(height: 8),
                    Text(
                      "Please upload your driving license",
                      style:
                      TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_licenseImage!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          //Buttons for Selecting Image (Hide if an image is selected)
          if (_licenseImage == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _getImageFromGallery,
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text(
                        "Choose from Gallery",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _getImageFromCamera,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text(
                        "Take a picture",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          //UPLOAD Button (Only Shows if Image is Selected)
          if (_licenseImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _uploadLicenseImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "UPLOAD",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
