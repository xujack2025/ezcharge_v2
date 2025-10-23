import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'FilterScreen.dart';
import 'ReservationScreen.dart';
import 'package:intl/intl.dart'; // Import package for date formatting

import 'package:ezcharge/views/EZCHARGE/CheckInScreen.dart';
import 'package:ezcharge/views/EZCHARGE/StationScreen.dart';
import 'package:ezcharge/views/EZCHARGE/book_a_charge_screen.dart';
import 'package:ezcharge/views/customer/Notification/NotificationScreen.dart';
import 'package:ezcharge/views/customer/Reward/RewardScreen.dart';
import 'package:ezcharge/views/customer/customercontent/AccountScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Location _location = Location();
  LatLng _currentLocation =
      const LatLng(3.2197929237993033, 101.6437936423279); // Default: KL
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _filteredStations = []; // For search results
  bool _isLoading = true;
  String _accountId = "00000000";
  String _authStatus = "";
  String _reservationStatus = "";
  ValueNotifier<double> sheetSize = ValueNotifier(0.15);

  // Added for search functionality:
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchStations();
    _getCustomerID();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //Fetch station data from Firestore
  //Fetch all stations and their Charger subcollection
  Future<void> _fetchStations() async {
    try {
      //Get all stations
      QuerySnapshot stationSnapshot =
          await FirebaseFirestore.instance.collection("station").get();

      //Temporary list to hold the final data
      List<Map<String, dynamic>> tempStations = [];

      //Loop through each station doc
      for (var stationDoc in stationSnapshot.docs) {
        final stationId = stationDoc.id; // or stationDoc["StationID"]
        final stationData = stationDoc.data() as Map<String, dynamic>;

        //Get the Charger subcollection for this station
        QuerySnapshot chargerSnapshot = await FirebaseFirestore.instance
            .collection("station")
            .doc(stationId)
            .collection("Charger")
            .get();

        // Gather all current types from the Charger docs
        List<String> currentTypes = [];
        for (var chargerDoc in chargerSnapshot.docs) {
          final chargerData = chargerDoc.data() as Map<String, dynamic>;
          final type = chargerData["CurrentType"] ?? "";
          // Only add if it's not empty and not already in the list
          if (type.isNotEmpty && !currentTypes.contains(type)) {
            currentTypes.add(type);
          }
        }

        // Build your station object
        tempStations.add({
          "StationID": stationData["StationID"] ?? stationId,
          "StationName": stationData["StationName"] ?? "",
          "Description": stationData["Description"] ?? "",
          "Capacity": stationData["Capacity"] ?? 0,
          "Location": stationData["Location"], // if you have a GeoPoint
          "Nearby": stationData["Nearby"], // might be string or list
          "ImageUrl":
              stationData["ImageUrl"] ?? "https://via.placeholder.com/80",

          // Store all the charger types found in the subcollection
          "CurrentType": currentTypes,
        });
      }

      // Update your state
      setState(() {
        _stations = tempStations; // Full station list
        _filteredStations = _stations; // Default: show all
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching stations: $e");
      setState(() => _isLoading = false);
    }
  }

  //Filter stations based on search query.
  void _filterStations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        // If user clears the search, show all stations again
        _filteredStations = _stations;
      } else {
        // Filter stations whose name contains the query (ignoring case)
        final matches = _stations.where((station) {
          return station["StationName"]
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        if (matches.isNotEmpty) {
          // Only display the first matching station
          _filteredStations = [matches.first];
        } else {
          _filteredStations = [];
        }
      }
    });
  }

  void _applyFilters(String power, List<String> nearby) {
    setState(() {
      if (power.isEmpty && nearby.isEmpty) {
        // If user didn't select anything, show all stations
        _filteredStations = _stations;
      } else {
        _filteredStations = _stations.where((station) {
          // Match Power if selected
          bool matchPower = true;
          if (power.isNotEmpty) {
            // Expecting a list of strings in station["CurrentTypes"]
            final currentTypes = station["CurrentType"];
            if (currentTypes is List) {
              // Check if the station’s CurrentTypes list contains the selected power (e.g., "AC" or "DC")
              matchPower = currentTypes.contains(power);
            } else {
              // If CurrentTypes is missing or not a List, this station doesn't match
              matchPower = false;
            }
          }

          // Match Nearby if selected
          bool matchNearby = true;
          if (nearby.isNotEmpty) {
            // station["Nearby"] can be a String or a List in your DB
            final stationNearby = station["Nearby"];
            if (stationNearby is String) {
              // If it's a string, check if any of the filters is a substring
              matchNearby = nearby.any(
                  (n) => stationNearby.toLowerCase().contains(n.toLowerCase()));
            } else if (stationNearby is List) {
              // If it's a list, check if any filter value is in the list
              matchNearby = nearby.any((n) => stationNearby.contains(n));
            } else {
              // If there's no valid nearby data, no match if the user selected something
              matchNearby = false;
            }
          }
          return matchPower && matchNearby;
        }).toList();
      }
    });
  }

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
          _fetchAuthenticationStatus();
          _fetchReservationStatus();
        }
      }
    } catch (e) {
      print(" Error fetching customer data: $e");
    }
  }

  Future<void> _fetchAuthenticationStatus() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("customers")
          .doc(_accountId)
          .collection("authenticate")
          .doc("authentication")
          .get();

      if (doc.exists) {
        setState(() {
          _authStatus = doc["Status"];
        });
      }
    } catch (e) {
      print("Error fetching authentication status: $e");
    }
  }

  Future<void> _fetchReservationStatus() async {
    if (_accountId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("reservation")
          .doc(_accountId)
          .get();

      if (doc.exists) {
        setState(() {
          _reservationStatus = doc["Status"] ?? "";
        });
      }
    } catch (e) {
      print("Error fetching reservation status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            initialCameraPosition:
                CameraPosition(target: _currentLocation, zoom: 14.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            /*markers: _buildMarkers(),*/
          ),

          // EZCHARGE Title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              child: const Text(
                "EZCHARGE",
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0),
              ),
            ),
          ),

          // Top Navigation Buttons
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavButton(Icons.qr_code, isSelected: false, onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CheckInScreen()));
                  }),
                  _buildNavButton(Icons.electric_bolt, isSelected: true),
                  _buildNavButton(Icons.local_gas_station, isSelected: false, onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BookAChargeScreen()));
                  }),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: () async {
                // Navigate to FilterScreen and wait for result
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterScreen()),
                );

                // If user returns filter data, apply it
                if (result != null && result is Map<String, dynamic>) {
                  final selectedPower =
                      result['power'] as String; // "AC", "DC", or ""
                  final selectedNearby = result['nearby'] as List<String>;
                  _applyFilters(selectedPower, selectedNearby);
                }
              },
            ),
          ),

          // Draggable Bottom Sheet (Search Bar + Station List)
          DraggableScrollableSheet(
            initialChildSize: 0.15,
            minChildSize: 0.15,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                        width: 40,
                        height: 5,
                        color: Colors.grey[400]), // Drag Handle
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          _filterStations(value);
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: "SEARCH",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredStations.isEmpty
                              ? const Center(child: Text("No station found"))
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: _filteredStations.length,
                                  itemBuilder: (context, index) {
                                    final station = _filteredStations[index];
                                    return _buildStationCard(station);
                                  },
                                ),
                    ),
                  ],
                ),
              );
            },
          ),
          //Floating Location Button (omitted for brevity)
        ],
      ),
      //Bottom Navigation Bar (omitted for brevity)
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  //Build Station Card (Displays Station Name + Button)

  Widget _buildStationCard(Map<String, dynamic> station) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isBookmarked = false; // Track bookmark state
        String bookmarkId = ""; // Store Firestore document ID

        //Check if the station is already bookmarked
        Future<void> checkBookmark() async {
          if (_accountId.isEmpty) return;
          try {
            QuerySnapshot bookmarkSnapshot = await FirebaseFirestore.instance
                .collection("customers")
                .doc(_accountId)
                .collection("bookmark")
                .where("StationID", isEqualTo: station["StationID"])
                .limit(1)
                .get();

            if (bookmarkSnapshot.docs.isNotEmpty) {
              setState(() {
                isBookmarked = true;
                bookmarkId = bookmarkSnapshot.docs.first.id;
              });
            }
          } catch (e) {
            print("Error checking bookmark: $e");
          }
        }

        /// Toggle Bookmark
        Future<void> toggleBookmark(Function setState) async {
          if (_accountId.isEmpty) return;

          try {
            if (isBookmarked) {
              //Remove bookmark from Firestore
              await FirebaseFirestore.instance
                  .collection("customers")
                  .doc(_accountId)
                  .collection("bookmark")
                  .doc(bookmarkId)
                  .delete();

              setState(() {
                isBookmarked = false;
                bookmarkId = "";
              });
            } else {
              // Format date as YYYYMMDD
              String formattedDate =
                  DateFormat('yyyyMMdd').format(DateTime.now());
              String newBookmarkId = "BKK$formattedDate"; //BookmarkID format

              // Add bookmark to Firestore
              await FirebaseFirestore.instance
                  .collection("customers")
                  .doc(_accountId)
                  .collection("bookmark")
                  .doc(newBookmarkId) // Use the formatted ID
                  .set({
                "BookmarkID": newBookmarkId,
                "StationID": station["StationID"],
                "CustomerID": _accountId,
              });

              setState(() {
                isBookmarked = true;
                bookmarkId = newBookmarkId;
              });

              // Display SnackBar message after successful addition
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Successful add the station to bookmark")),
              );
            }
          } catch (e) {
            print("Error toggling bookmark: $e");
          }
        }

        //Check bookmark status when card is built
        checkBookmark();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
                color: Colors.black, width: 1), //Black Border
          ),
          color: Colors.white, // White Background
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Row for Image, Station Name & Bookmark
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Station Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        station["ImageUrl"] ?? "https://via.placeholder.com/80",
                        width: 150,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),

                    //Station Name (Centered)
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end, // Aligns text to the right
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[200], //Grey background
                              border: Border.all(
                                  color: Colors.black,
                                  width: 1.5), //Black border
                              borderRadius:
                                  BorderRadius.circular(8), //Rounded corners
                            ),
                            child: Text(
                              station["Nearby"],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Text(
                            station["StationName"],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const SizedBox(
                              height:
                                  4), // Small spacing between name and description
                          Text(
                            station["Description"] ??
                                "", // Display description if available
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                "Capacity: ",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                station["Capacity"]
                                    .toString(), // Convert to String for display
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue, // Highlight in blue
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    //Bookmark Button
                    IconButton(
                      icon: Icon(
                        Icons.bookmark,
                        color: isBookmarked
                            ? Colors.black
                            : Colors.grey, //Fix color toggle
                      ),
                      onPressed: () =>
                          toggleBookmark(setState), //Pass setState
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                //Button Row (Shifted to the Right)
                Align(
                  alignment:
                      Alignment.centerRight, // Moves buttons to the right
                  child: Row(
                    mainAxisSize: MainAxisSize
                        .min, // Ensures row only takes required space
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Check if user is authenticated
                          if (_authStatus != "Pass") {
                            _showAuthReminder(context);
                            return;
                          }
                          // Check if user already has an Upcoming/Active reservation
                          if (_reservationStatus == "Upcoming" ||
                              _reservationStatus == "Active") {
                            _showReservationReminder(context);
                            return;
                          }

                          // Otherwise, proceed to ReservationScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReservationScreen(
                                  stationId: station["StationID"]),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_authStatus == "Pass" &&
                                  _reservationStatus != "Upcoming" &&
                                  _reservationStatus != "Active")
                              ? Colors.blue
                              : Colors.grey, // Grey if disabled
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "RESERVE",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),

                      const SizedBox(width: 10), // Space between buttons
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StationScreen(
                                stationId: station["StationID"],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text(
                          "VIEW CHARGERS",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  //Bottom Navigation Bar
  Widget _buildBottomNavBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const RewardScreen()));
        } else if (index == 3) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => NotificationScreen()));
        } else if (index == 2) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => AccountScreen()));
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.directions_car), label: "EZCharge"),
        BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard), label: "Rewards"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Me"),
        BottomNavigationBarItem(icon: Icon(Icons.mail), label: "Inbox"),
      ],
    );
  }

  //Build Markers for Stations
  Set<Marker> _buildMarkers() {
    return _stations.map((station) {
      return Marker(
        markerId: MarkerId(station["StationID"]),
        position: station["Location"],
        infoWindow: InfoWindow(title: station["StationName"]),
      );
    }).toSet();
  }

  // Build Navigation Button (QR / Charging / Gas)
  Widget _buildNavButton(IconData icon,
      {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap, // Assign the onTap function
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : Colors.white, // Background color change
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.white
              : Colors.black, // White icon when selected
          size: 30,
        ),
      ),
    );
  }

  void _showAuthReminder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Authentication Required"),
        content: const Text(
            "Please authenticate your account before making a reservation."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showReservationReminder(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Existing Reservation"),
        content:
            const Text("You already have an upcoming or active reservation. "
                "Please complete or cancel it before making a new one."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled;
      PermissionStatus permissionGranted;

      // Check if location services are enabled
      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print("Location services are disabled.");
          return;
        }
      }

      //Check location permissions
      permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print("Location permission denied.");
          return;
        }
      }

      // Get the current user location
      LocationData locationData = await _location.getLocation();
      LatLng userLocation =
          LatLng(locationData.latitude!, locationData.longitude!);

      setState(() {
        _currentLocation = userLocation;
      });

      //Move camera to user's location
      final GoogleMapController controller = await _controller.future;
      controller
          .animateCamera(CameraUpdate.newLatLngZoom(_currentLocation, 14));
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // Move Camera
  Future<void> _moveCamera(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 14.0));
  }
}
