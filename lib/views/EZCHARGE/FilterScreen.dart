import 'package:flutter/material.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String _selectedPower = ''; // AC / DC
  List<String> _selectedNearby = []; // Nearby filters
  double _priceRange = 2; // Default price range

  //Toggle Power Supply Filter
  void _togglePowerSupply(String type) {
    setState(() {
      _selectedPower = (_selectedPower == type) ? '' : type;
    });
  }

  /// Toggle Nearby Filter
  void _toggleNearby(String type) {
    setState(() {
      _selectedNearby.contains(type)
          ? _selectedNearby.remove(type)
          : _selectedNearby.add(type);
    });
  }

  /// Reset Filters
  void _resetFilters() {
    setState(() {
      _selectedPower = '';
      _selectedNearby.clear();
      _priceRange = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Filter Options",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, size: 28, color: Colors.blue),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Reset Filters
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resetFilters,
                child: const Text("Reset Filters",
                    style: TextStyle(color: Colors.blue, fontSize: 16)),
              ),
            ),

            // Power Supply Filter
            _buildFilterCategory(
              title: "Current Type",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton("AC", _selectedPower == "AC",
                      () => _togglePowerSupply("AC")),
                  _buildFilterButton("DC", _selectedPower == "DC",
                      () => _togglePowerSupply("DC")),
                ],
              ),
            ),

            // Nearby Filter
            _buildFilterCategory(
              title: "Nearby",
              child: Wrap(
                spacing: 15,
                children: [
                  _buildFilterButton(
                      "Coffee Shop",
                      _selectedNearby.contains("Coffee Shop"),
                      () => _toggleNearby("Coffee Shop")),
                  _buildFilterButton(
                      "Restaurant",
                      _selectedNearby.contains("Restaurant"),
                      () => _toggleNearby("Restaurant")),
                  _buildFilterButton(
                      "Shopping Mall",
                      _selectedNearby.contains("Shopping Mall"),
                      () => _toggleNearby("Shopping Mall")),
                ],
              ),
            ),

            const Spacer(),

            //Show Result Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'power': _selectedPower, // "AC" or "DC" or ""
                    'nearby':
                        _selectedNearby, // e.g. ["Coffee Shop","Restaurant"]
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  "SHOW RESULT",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Build Filter Category Section
  Widget _buildFilterCategory({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  //Build Filter Button
  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.blue,
          ),
        ),
      ),
    );
  }
}
