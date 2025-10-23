import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/charging_bay_model.dart';
import 'package:ezcharge/viewmodels/charging_station_viewmodel.dart';
import 'package:ezcharge/views/admin/admin_charging_bay.dart';
import 'package:ezcharge/models/charging_bay_model.dart';
class AdminChargingStationsPage extends StatefulWidget {
  const AdminChargingStationsPage({super.key});

  @override
  State<AdminChargingStationsPage> createState() =>
      _AdminChargingStationsPageState();
}

class _AdminChargingStationsPageState extends State<AdminChargingStationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChargingStationViewModel _chargingStationViewModel =
      ChargingStationViewModel();

  final TextEditingController _stationNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nearbyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  File? _selectedImage;
  String? _imageUrl;
  String? _editingStationID;
  final List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
  }

  void _showChargingStationDialog({
    String? stationID,
    String? stationName,
    String? description,
    String? nearby,
    String? location,
    String? latitude,
    String? longitude,
    String? imageUrl,
  }) {
    _stationNameController.text = stationName ?? "";
    _descriptionController.text = description ?? "";
    _nearbyController.text = nearby ?? "";
    _locationController.text = location ?? "";
    _latitudeController.text = latitude ?? "";
    _longitudeController.text = longitude ?? "";
    _imageUrl = imageUrl;
    _selectedImage = null;
    _editingStationID = stationID; // ✅ Correctly assigns station ID for editing

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.ev_station, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  stationID == null
                      ? "Add Charging Station"
                      : "Edit Charging Station",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStyledTextField("Station Name", _stationNameController),
                  _buildStyledTextField("Description", _descriptionController,
                      maxLines: 3),
                  _buildStyledTextField("Nearby", _nearbyController),
                  _buildStyledTextField("Location", _locationController),
                  Row(
                    children: [
                      Expanded(
                          child: _buildStyledTextField(
                              "Latitude", _latitudeController)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStyledTextField(
                              "Longitude", _longitudeController)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Station Image",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _selectedImage != null
                          ? Image.file(_selectedImage!, height: 120)
                          : (_imageUrl != null && _imageUrl!.isNotEmpty)
                              ? Image.network(_imageUrl!, height: 120)
                              : Container(
                                  height: 120,
                                  width: 120,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported,
                                      size: 40, color: Colors.grey),
                                ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        File? pickedImage =
                            await _chargingStationViewModel.pickImage();
                        if (pickedImage != null) {
                          setDialogState(() {
                            _selectedImage = pickedImage;
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Pick Image"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _saveChargingStation(setDialogState);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text("Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ Save Charging Station (With Auto Capacity & Status Update)
  Future<void> _saveChargingStation(Function setDialogState) async {
    if (_stationNameController.text.isEmpty ||
        _locationController.text.isEmpty) {
      return; // ✅ Prevent saving with empty fields
    }

    // ✅ Upload image if new image is selected
    if (_selectedImage != null) {
      String? uploadedImageUrl = await _chargingStationViewModel.uploadImage(
        _selectedImage!,
        _editingStationID ?? _stationNameController.text,
      );

      if (uploadedImageUrl != null) {
        setDialogState(() {
          _imageUrl = uploadedImageUrl;
        });
      }
    }

    // ✅ Keep previous image if no new one is selected
    if (_imageUrl == null && _editingStationID != null) {
      _imageUrl =
          await _chargingStationViewModel.getStationImage(_editingStationID!);
    }

    if (_editingStationID == null) {
      // ✅ Generate ID and create new station (Capacity is auto-managed)
      String newStationID =
          await _chargingStationViewModel.generateNewStationID();
      await _chargingStationViewModel.createChargingStation(
        stationName: _stationNameController.text,
        description: _descriptionController.text,
        nearby: _nearbyController.text,
        location: _locationController.text,
        latitude: _latitudeController.text,
        longitude: _longitudeController.text,
        imageFile: _selectedImage,
      );

      // ✅ Automatically set capacity and occupied bays
      await _chargingStationViewModel.updateCapacity(newStationID);
    } else {
      // ✅ Update existing station (Capacity auto-updated)
      await _chargingStationViewModel.updateChargingStation(
        stationID: _editingStationID!,
        stationName: _stationNameController.text,
        description: _descriptionController.text,
        nearby: _nearbyController.text,
        location: _locationController.text,
        latitude: _latitudeController.text,
        longitude: _longitudeController.text,
        imageFile: _selectedImage,
      );

      // ✅ Automatically update capacity and occupied bays
      await _chargingStationViewModel.updateCapacity(_editingStationID!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showChargingStationDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add Station"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chargingStationViewModel.fetchChargingStationsStream(),
        // ✅ Stream-based fetching
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator()); // ✅ Show loading
          }

          if (snapshot.hasError) {
            return Center(
                child: Text("Error: ${snapshot.error}")); // ✅ Handle error
          }

          final stations = snapshot.data ?? [];

          if (stations.isEmpty) {
            return const Center(
              child: Text(
                "No charging stations available.",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              var station = stations[index];
              return _buildChargingStationCard(station);
            },
          );
        },
      ),
    );
  }

  // ✅ Build Charging Station Card
  Widget _buildChargingStationCard(Map<String, dynamic> station) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header: Station Image + Name + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: station["imageUrl"] != ""
                      ? Image.network(
                          station["imageUrl"],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.ev_station,
                              color: Colors.green, size: 40),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station["stationName"],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "📍 ${station["location"]}",
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status Badge
                _buildStatusBadge(station["capacity_status"]),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 Capacity & Occupancy Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(Icons.battery_charging_full,
                    "Capacity: ${station["capacity"]} Bays"),
                _buildInfoChip(Icons.car_repair,
                    "Occupied: ${station["occupied_bays"]} Bays"),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 Actions: Manage Bays, Edit, Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildBayManagementButton(station["stationID"]),
                const SizedBox(width: 8),
                _buildEditButton(station),
                const SizedBox(width: 8),
                _buildDeleteButton(station["stationID"]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Build Text Field Widget
  Widget _buildStyledTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  // ✅ Manage Charging Bays Button
  Widget _buildBayManagementButton(String stationID) {
    return IconButton(
      icon: const Icon(Icons.ev_station, color: Colors.orange),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminChargingBayPage(stationID: stationID),
          ),
        );
      },
    );
  }

  // ✅ Edit Button
  Widget _buildEditButton(Map<String, dynamic> station) {
    return IconButton(
      icon: const Icon(Icons.edit, color: Colors.blue),
      onPressed: () => _showChargingStationDialog(
        stationID: station["stationID"],
        stationName: station["stationName"],
        description: station["description"],
        nearby: station["nearby"],
        location: station["location"],
        latitude: station["latitude"],
        longitude: station["longitude"],
        imageUrl: station["imageUrl"],
      ),
    );
  }

  // ✅ Delete Button
  Widget _buildDeleteButton(String stationID) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () async {
        await _chargingStationViewModel.deleteChargingStation(stationID);
        //_loadChargingStations();
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status) {
      case "Overloaded":
        badgeColor = Colors.red;
        break;
      case "High Demand":
        badgeColor = Colors.orange;
        break;
      case "Undefined":
        badgeColor = Colors.grey;
        break;
      default:
        badgeColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 18),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
