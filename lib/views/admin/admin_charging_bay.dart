import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ezcharge/models/charging_bay_model.dart';
import 'package:ezcharge/viewmodels/charging_station_viewmodel.dart';

class AdminChargingBayPage extends StatefulWidget {
  final String stationID;

  const AdminChargingBayPage({super.key, required this.stationID});

  @override
  State<AdminChargingBayPage> createState() => _AdminChargingBayPageState();
}

class _AdminChargingBayPageState extends State<AdminChargingBayPage> {
  final ChargingStationViewModel _chargingStationViewModel =
      ChargingStationViewModel();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Form key for validation

  @override
  void initState() {
    super.initState();
    _listenToChargerStatusChanges();
  }

  void _listenToChargerStatusChanges() {
    FirebaseFirestore.instance
        .collection('station')
        .doc(widget.stationID)
        .collection('Charger')
        .snapshots() // Real-time listener
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        print("📢 Charger Status Updated! Auto-updating capacity...");
        _chargingStationViewModel
            .updateCapacity(widget.stationID); // Auto-run updateCapacity()
      }
    });
  }

  Future<String> _generateNewChargerID() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collectionGroup('Charger')
          .get(); // Get all chargers and manually extract max ID

      if (snapshot.docs.isEmpty) {
        return "CRR00001"; // First Charger ID starts as CRR00001
      }

      List<int> chargerNumbers = snapshot.docs.map((doc) {
        String id = doc['ChargerID'];
        Match? match = RegExp(r'CRR(\d+)$').firstMatch(id);
        return match != null ? int.parse(match.group(1)!) : 0;
      }).toList();

      int lastNumber = chargerNumbers.isNotEmpty
          ? chargerNumbers.reduce((a, b) => a > b ? a : b)
          : 0;
      int newNumber = lastNumber + 1;

      return "CRR${newNumber.toString().padLeft(5, '0')}"; // Format: CRR00011
    } catch (e) {
      print("Error generating ChargerID: $e");
      return "CRR00001"; // Fallback
    }
  }

  // Manage Charging Bay: Add/Edit with validation
  void _editChargingBay(ChargingBay? bay) async {
    TextEditingController _chargerNameController =
        TextEditingController(text: bay?.chargerName ?? "");
    TextEditingController _chargerVoltageController =
        TextEditingController(text: bay?.chargerVoltage.toString() ?? "");
    TextEditingController _pricePerVoltageController =
        TextEditingController(text: bay?.pricePerVoltage.toString() ?? "");

    String chargerType = bay?.chargerType ?? "Type 2";
    String currentType = bay?.currentType ?? "AC";
    String status = bay?.status ?? "Available";

    String? originalStatus = bay?.status;

    String newChargerID = bay?.chargerID ?? await _generateNewChargerID();

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
                Icon(Icons.edit, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  bay == null ? "Add Charging Bay" : "Edit Charging Bay",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Charger ID (Read-only)
                    _buildReadOnlyField("Charger ID", newChargerID),

                    // Charger Name
                    _buildStyledTextField(
                        "Charger Name", _chargerNameController),

                    // Charger Type Dropdown
                    _buildStyledDropdown(
                      label: "Charger Type",
                      value: chargerType,
                      items: ["Type 2", "CCS2"],
                      onChanged: (String? value) {
                        if (value != null) {
                          // Update parent widget's state
                          setState(() {
                            chargerType = value;
                            currentType = chargerType == "Type 2"
                                ? "AC"
                                : "DC"; // Update currentType based on chargerType
                          });
                        }
                      },
                    ),

                    // Current Type (Auto-filled, read-only)
                    _buildReadOnlyField("Current Type", currentType),

                    // Charger Voltage (with validation)
                    _buildStyledTextField(
                      "Kilowatt-hours",
                      _chargerVoltageController,
                      isNumber: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Charger voltage is required";
                        }
                        if (double.tryParse(value) == null) {
                          return "Please enter a valid number for voltage";
                        }
                        return null;
                      },
                    ),

                    // Price per Voltage (with validation)
                    _buildStyledTextField(
                      "Price per kilowatt-hours",
                      _pricePerVoltageController,
                      isNumber: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Price per voltage is required";
                        }
                        if (double.tryParse(value) == null) {
                          return "Please enter a valid number for price";
                        }
                        return null;
                      },
                    ),

                    // Status Dropdown
                    _buildStyledDropdown(
                      label: "Status",
                      value: status,
                      items: ["Available", "Occupied", "In Service"],
                      onChanged: (value) {
                        setDialogState(() {
                          status = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    ChargingBay newBay = ChargingBay(
                      chargerID: newChargerID,
                      chargerName: _chargerNameController.text,
                      chargerType: chargerType,
                      chargerVoltage:
                          double.parse(_chargerVoltageController.text),
                      currentType: currentType,
                      pricePerVoltage:
                          double.parse(_pricePerVoltageController.text),
                      status: status,
                    );

                    if (bay == null) {
                      await _chargingStationViewModel.addChargingBay(
                          widget.stationID, newBay);
                    } else {
                      await _chargingStationViewModel.updateChargingBay(
                          widget.stationID, newBay);
                    }

                    if (originalStatus != status) {
                      await _chargingStationViewModel
                          .updateCapacity(widget.stationID);
                    }

                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text("Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Charging Bays"),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editChargingBay(null),
        icon: const Icon(Icons.add),
        label: const Text("Add Bay"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<List<ChargingBay>>(
        stream:
            _chargingStationViewModel.fetchChargingBaysStream(widget.stationID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          List<ChargingBay> chargingBays = snapshot.data ?? [];

          return chargingBays.isEmpty
              ? const Center(child: Text("No charging bays available."))
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: chargingBays.length,
                  itemBuilder: (context, index) {
                    var bay = chargingBays[index];
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        title: Text(
                          bay.chargerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("🔌 Type: ${bay.chargerType}"),
                            Text("⚡ kilowatt-hours: ${bay.chargerVoltage}kWh"),
                            Text("💲 Price: RM${bay.pricePerVoltage}/kWh"),
                            Text(
                              "📍 Status: ${bay.status}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: bay.status == "Occupied"
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editChargingBay(bay),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _chargingStationViewModel
                                    .deleteChargingBay(
                                        widget.stationID, bay.chargerID);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildStyledTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
      ),
    );
  }
}
