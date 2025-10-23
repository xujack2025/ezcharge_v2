import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedDateOfBirth;
  String? _customerId;

  final List<String> _genders = ["Male", "Female", "Other"];

  @override
  void initState() {
    super.initState();
    _fetchCustomerData(); // Fetch Firestore data when screen loads
  }

  //Fetch logged-in user's details from Firestore
  Future<void> _fetchCustomerData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String userPhone = user.phoneNumber ?? "";
        if (userPhone.isEmpty) return;

        //Query Firestore for customer document
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection("customers")
            .where("PhoneNumber", isEqualTo: userPhone)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userDoc = querySnapshot.docs.first;

          setState(() {
            _customerId =
                userDoc["CustomerID"]; // Store CustomerID for updating later
            _firstNameController.text = userDoc["FirstName"];
            _lastNameController.text = userDoc["LastName"];
            _emailController.text = userDoc["EmailAddress"];
            _phoneController.text = userDoc["PhoneNumber"];
            _selectedGender = userDoc["Gender"];
            _selectedDateOfBirth = userDoc["DateOfBirth"];
          });
        }
      }
    } catch (e) {
      print("❌ Error fetching customer data: $e");
    }
  }

  //Save updated profile to Firestore
  Future<void> _saveProfile() async {
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Customer not found.")),
      );
      return;
    }
    final email = _emailController.text.trim();

    // Email validation: must end with @gmail.com
    if (!email.endsWith('@gmail.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid email address"),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection("customers")
          .doc(_customerId)
          .update({
        "FirstName": _firstNameController.text,
        "LastName": _lastNameController.text,
        "EmailAddress": _emailController.text,
        "Gender": _selectedGender,
        "DateOfBirth": _selectedDateOfBirth,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update profile.")),
      );
    }
  }

  void _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateOfBirth =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the body background to grey
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
              color: Colors.black, fontSize: 25, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField("First Name", _firstNameController,
                isRequired: true),
            _buildTextField("Last Name", _lastNameController, isRequired: true),
            _buildTextField("Email Address", _emailController,
                hint: "Enter Email Address"),
            _buildTextField("Phone Number", _phoneController,
                isEditable: false),
            _buildDropdownField("Gender", _genders, _selectedGender,
                (newValue) {
              setState(() => _selectedGender = newValue);
            }),
            _buildDatePickerField(
                "Date of Birth", _selectedDateOfBirth, _pickDate),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
                child: const Text("SAVE",
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

  // Function to build text fields
  Widget _buildTextField(String label, TextEditingController controller,
      {String? hint, bool isRequired = false, bool isEditable = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              if (isRequired)
                const Text(" *", style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            enabled: isEditable,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
            ),
          ),
        ],
      ),
    );
  }

  // Function to build dropdown fields
  Widget _buildDropdownField(String label, List<String> items,
      String? selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              hint: const Text("Select Gender"),
              underline: const SizedBox(),
              onChanged: onChanged,
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Function to build date picker field
  Widget _buildDatePickerField(
      String label, String? selectedDate, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Text(selectedDate ?? "Select Date of Birth"),
                  const Spacer(),
                  const Icon(Icons.calendar_today,
                      color: Colors.black54, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
