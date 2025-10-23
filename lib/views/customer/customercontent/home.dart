// import 'dart:async';
//
// import 'package:flutter/material.dart';
//
// //file
// import '../../EZCHARGE/HomeScreen.dart';
// import '../../auth/Intro_screen.dart';
// import '../Notification/NotificationScreen.dart';
// import '../Reward/RewardScreen.dart';
// import 'DeleteAccountScreen.dart';
// import 'EditProfileScreen.dart';
// import 'PaymentMethodScreen.dart';
//
// //firebase
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class AccountScreen extends StatefulWidget {
//   const AccountScreen({super.key});
//
//   @override
//   _AccountScreenState createState() => _AccountScreenState();
// }
//
// class _AccountScreenState extends State<AccountScreen> {
//   String _customerName = "Loading...";
//   String _accountId = "00000000";
//   double _walletBalance = 0.0;
//   int _pointBalance = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchCustomerData();
//   }
//
//   /// 🔹 Fetch logged-in user's details from Firestore
//   Future<void> _fetchCustomerData() async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         String userPhone = user.phoneNumber ?? "";
//         if (userPhone.isEmpty) return;
//
//         QuerySnapshot querySnapshot = await FirebaseFirestore.instance
//             .collection("customers")
//             .where("PhoneNumber", isEqualTo: userPhone)
//             .limit(1)
//             .get();
//
//         if (querySnapshot.docs.isNotEmpty) {
//           var userDoc = querySnapshot.docs.first;
//
//           setState(() {
//             _customerName = "${userDoc["FirstName"]} ${userDoc["LastName"]}";
//             _accountId = userDoc["CustomerID"];
//             _walletBalance = userDoc["WalletBalance"].toDouble();
//             _pointBalance = userDoc["PointBalance"];
//           });
//         }
//       }
//     } catch (e) {
//       print("❌ Error fetching customer data: $e");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[200],
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 1,
//         automaticallyImplyLeading: false,
//         title: const Text("Account",
//             style: TextStyle(
//                 color: Colors.black,
//                 fontSize: 30,
//                 fontWeight: FontWeight.bold)),
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // 🔹 User Info Section
//                   Container(
//                     color: Colors.black,
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           _customerName,
//                           style: const TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(height: 5),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               "Account ID: $_accountId",
//                               style: const TextStyle(
//                                   fontSize: 14, color: Colors.white),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 10, vertical: 5),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Row(
//                                 children: [
//                                   const Icon(Icons.bolt,
//                                       color: Colors.blue, size: 18),
//                                   const SizedBox(width: 5),
//                                   Text(
//                                     "$_pointBalance pts",
//                                     style: const TextStyle(
//                                       color: Colors.blue,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // 🔹 Wallet Balance Section
//                   Container(
//                     margin: const EdgeInsets.all(16),
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: Colors.blue,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           children: [
//                             const Icon(Icons.account_balance_wallet,
//                                 color: Colors.white, size: 28),
//                             const SizedBox(width: 10),
//                             Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   "EZCharge Credits",
//                                   style: TextStyle(
//                                       fontSize: 14, color: Colors.white),
//                                 ),
//                                 Text(
//                                   "RM ${_walletBalance.toStringAsFixed(2)}",
//                                   style: const TextStyle(
//                                     fontSize: 22,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.white,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                         ElevatedButton(
//                           onPressed: () {
//                             // TODO: Implement Top Up Functionality
//                           },
//                           style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.white),
//                           child: const Text("+ TOP UP",
//                               style:
//                                   TextStyle(color: Colors.blue, fontSize: 14)),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   _buildSection("My Account", [
//                     _buildListItem("Edit Profile", onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (context) => EditProfileScreen()),
//                       );
//                     }),
//                     _buildListItem("Charging"),
//                     _buildListItem("Authenticate Account"),
//                     _buildListItem("Bookmarks"),
//                     _buildListItem("Language Preferences"),
//                   ]),
//                   _buildSection("Payments", [
//                     _buildListItem("Payment Methods", onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (context) => PaymentMethodScreen()),
//                       );
//                     }),
//                     _buildListItem("Payment History"),
//                   ]),
//                   _buildSection("Others", [
//                     _buildListItem("F.A.Q"),
//                     _buildListItem("Contact Us"),
//                     _buildListItem("Terms of Use"),
//                     _buildListItem("Privacy Policy"),
//                     _buildListItem("Delete Account", onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                             builder: (context) => const DeleteAccountScreen()),
//                       );
//                     }),
//                   ]),
//
//                   _buildCenteredListItem(context, "Log Out", Icons.logout),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: _buildBottomNavBar(context),
//     );
//   }
//
//   // 🔹 UI Components
//   Widget _buildSection(String title, List<Widget> items) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           color: Colors.grey[300],
//           child: Text(
//             title,
//             style: const TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.black,
//             ),
//           ),
//         ),
//         Column(children: items),
//       ],
//     );
//   }
//
//   Widget _buildListItem(String title, {VoidCallback? onTap}) {
//     return ListTile(
//       title: Text(title),
//       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//       onTap: onTap,
//     );
//   }
//
//   Widget _buildBottomNavBar(BuildContext context) {
//     return BottomNavigationBar(
//       type: BottomNavigationBarType.fixed,
//       selectedItemColor: Colors.blue,
//       unselectedItemColor: Colors.black54,
//       currentIndex: 2,
//       // Index for "Me"
//       onTap: (index) {
//         if (index == 1) {
//           // ✅ When "Rewards" is tapped
//           Navigator.push(context,
//               MaterialPageRoute(builder: (context) => const RewardScreen()));
//         } else if (index == 3) {
//           // Inbox - Replace with actual screen
//           Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                   builder: (context) => const NotificationScreen()));
//         } else if (index == 0) {
//           // Inbox - Replace with actual screen
//           Navigator.pushReplacement(
//               context, MaterialPageRoute(builder: (context) => const HomeScreen()));
//         }
//       },
//
//       items: const [
//         BottomNavigationBarItem(
//             icon: Icon(Icons.directions_car), label: "EZCharge"),
//         BottomNavigationBarItem(
//             icon: Icon(Icons.card_giftcard), label: "Rewards"),
//         BottomNavigationBarItem(icon: Icon(Icons.person), label: "Me"),
//         BottomNavigationBarItem(icon: Icon(Icons.mail), label: "Inbox"),
//       ],
//     );
//   }
//
//   Widget _buildCenteredListItem(
//       BuildContext context, String title, IconData icon) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       color: Colors.grey[300],
//       child: Center(
//         child: InkWell(
//           onTap: () => _logoutUser(context),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, color: Colors.black),
//               const SizedBox(width: 8),
//               Text(title,
//                   style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _logoutUser(BuildContext context) {
//     FirebaseAuth.instance.signOut();
//     Navigator.pushReplacement(
//         context, MaterialPageRoute(builder: (context) => const IntroScreen()));
//   }
// }
