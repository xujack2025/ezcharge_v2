import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ezcharge/views/auth/Intro_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConfirmDeleteScreen extends StatelessWidget {
  const ConfirmDeleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Container(
            decoration:
                const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Delete Account",
            style: TextStyle(
                color: Colors.black,
                fontSize: 30,
                fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("We are sorry to receive your leaving",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Are you sure you want to delete your account?\nYou will permanently lose:",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text("- Profile\n- Bookmarks\n- Charging records\n- Rewards",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Please note that the account deletion is irreversible. Think wise!",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 430),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showDeleteConfirmation(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: const Text("DELETE",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Show Confirmation Dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Account",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
              "Are you sure you want to permanently remove your account?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No", style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                // Close the dialog
                Navigator.pop(context);

                // Navigate to IntroScreen immediately
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const IntroScreen()),
                  (route) => false, // Remove all previous routes
                );

                // Then, start account deletion in the background
                _deleteAccount();
              },
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) return;

        // Find the user in Firestore
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;

          // 🔹 Delete user from Firestore
          await FirebaseFirestore.instance
              .collection("customers")
              .doc(userDoc.id)
              .delete();
        }

        // Delete user from Firebase Authentication
        await user.delete();

        // Sign out after deletion
        await FirebaseAuth.instance.signOut();

        print("Account deleted successfully.");
      }
    } catch (e) {
      print("Error deleting account: $e");
    }
  }
}
