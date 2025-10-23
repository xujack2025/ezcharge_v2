import 'package:flutter/material.dart';

class CustomBottomAppBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final bool isAdmin;

  const CustomBottomAppBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onTap,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: isAdmin
          ? const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Analytics"),
        BottomNavigationBarItem(icon: Icon(Icons.report), label: "Complaints"),
        BottomNavigationBarItem(icon: Icon(Icons.ev_station), label: "Stations"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ]
          : const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.star), label: "Ratings"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
