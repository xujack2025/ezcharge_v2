import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRewardsScreen extends StatefulWidget {
  const AdminRewardsScreen({super.key});

  @override
  _AdminRewardsScreenState createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> {
  final CollectionReference rewardsCollection =
      FirebaseFirestore.instance.collection('reward');

  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('customers');

  List<String> selectedUsers = [];

  /// Selects all users whose birthday is in the current month
  Future<void> _selectBirthdayUsers() async {
    int currentMonth = DateTime.now().month;

    QuerySnapshot querySnapshot = await usersCollection.get(); // Get all users

    setState(() {
      selectedUsers = querySnapshot.docs
          .where((doc) {
            var user = doc.data() as Map<String, dynamic>;

            print("User: ${doc.id}, DateOfBirth: ${user['DateOfBirth']}");

            if (user['DateOfBirth'] != null) {
              DateTime? dob;

              // ✅ Check if DateOfBirth is a Firestore Timestamp
              if (user['DateOfBirth'] is Timestamp) {
                dob = (user['DateOfBirth'] as Timestamp)
                    .toDate()
                    .add(Duration(hours: 8)); // ✅ Convert to UTC+8
              }

              // ✅ Handle DateOfBirth stored as a String (e.g., "21/2/2025")
              else if (user['DateOfBirth'] is String) {
                try {
                  List<String> parts = user['DateOfBirth'].split('/');
                  int day = int.parse(parts[0]);
                  int month = int.parse(parts[1]);
                  int year = int.parse(parts[2]);

                  // ✅ Create DateTime in UTC and convert to UTC+8
                  dob = DateTime.utc(year, month, day).add(Duration(hours: 8));
                } catch (e) {
                  print("Invalid Date Format for User: ${doc.id}");
                  return false; // Skip users with invalid dates
                }
              }

              // ✅ If dob is valid, check the birth month & day
              if (dob != null) {
                int birthMonth = dob.month;

                print(
                    "Converted Date: $dob, Birth Month: $birthMonth, Expected: $currentMonth");

                return birthMonth == currentMonth; // Compare month only
              }
            }
            return false;
          })
          .map((doc) => doc.id)
          .toList();
    });

    print("Selected Users: $selectedUsers");
  }

  /// Selects all users who registered after a given date
  Future<void> _selectNewRegisteredUsers(DateTime selectedDate) async {
    QuerySnapshot querySnapshot = await usersCollection
        .where("CreatedAt", isGreaterThan: Timestamp.fromDate(selectedDate))
        .get();

    setState(() {
      selectedUsers = querySnapshot.docs.map((doc) => doc.id).toList();
    });
  }

  void _openRewardDialog({String? rewardId, Map<String, dynamic>? rewardData}) {
    TextEditingController rewardDetailsController =
        TextEditingController(text: rewardData?['RewardDetails'] ?? '');
    TextEditingController pointsController =
        TextEditingController(text: rewardData?['Points']?.toString() ?? '');

    DateTime? selectedDate = rewardData?['ExpiredDate']?.toDate();

    List<String> userTypes = [
      'New Register Member',
      'Birthday Member',
      'Anniversary Celebration'
    ];
    List<String> selectedUserTypes =
        List<String>.from(rewardData?['EligibleUserTypes'] ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
              title: Center(
                child: Text(
                  rewardId == null ? 'Add Reward' : 'Edit Reward',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reward Details Input
                    TextField(
                      controller: rewardDetailsController,
                      decoration: InputDecoration(
                        labelText: 'Reward Details',
                        prefixIcon: const Icon(Icons.card_giftcard),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Points Input
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Points',
                        prefixIcon: const Icon(Icons.stars),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Expiry Date Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      tileColor: Colors.grey[200],
                      title: Text(
                        selectedDate != null
                            ? 'Expiry Date: ${selectedDate?.toLocal()}'
                            : 'Select Expiry Date',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing:
                          const Icon(Icons.calendar_today, color: Colors.blue),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    // Eligible User Types
                    const Text(
                      'Eligible User Types:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Card(
                      color: Colors.grey[100],
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: userTypes.map((type) {
                          return CheckboxListTile(
                            title: Text(type),
                            value: selectedUserTypes.contains(type),
                            activeColor: Colors.blue,
                            onChanged: (bool? selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  selectedUserTypes.add(type);
                                } else {
                                  selectedUserTypes.remove(type);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Select Users Button
                    ElevatedButton.icon(
                      onPressed: () => _selectUsersDialog(),
                      icon: const Icon(Icons.people),
                      label: const Text("Select Specific Users"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              actions: [
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    if (rewardDetailsController.text.isNotEmpty &&
                        pointsController.text.isNotEmpty &&
                        selectedDate != null) {

                      List<String> finalSelectedUsers = [];

                      // ✅ If no users are selected, add all users
                      if (selectedUsers.isEmpty) {
                        QuerySnapshot querySnapshot = await usersCollection.get();
                        finalSelectedUsers = querySnapshot.docs.map((doc) => doc.id).toList();
                      } else {
                        finalSelectedUsers = List<String>.from(selectedUsers);
                      }

                      final newReward = {
                        'RewardDetails': rewardDetailsController.text,
                        'Points': int.parse(pointsController.text),
                        'ExpiredDate': Timestamp.fromDate(selectedDate!),
                        'EligibleUserTypes': List<String>.from(selectedUserTypes),
                        'SelectedUsers': finalSelectedUsers,
                        'RewardID': rewardId ?? '',
                      };

                      // Ensure selected users are correctly saved
                      if (rewardId == null) {
                        String newId = "RWD${DateTime.now().millisecondsSinceEpoch}";
                        newReward['RewardID'] = newId;

                        // ✅ Ensure selectedUsers list is actually stored
                        if (selectedUsers.isNotEmpty) {
                          newReward['SelectedUsers'] = List<String>.from(selectedUsers);
                        } else {
                          newReward['SelectedUsers'] = []; // Avoid null issue
                        }

                        rewardsCollection.doc(newId).set(newReward);
                      } else {
                        // ✅ Update the reward with selectedUsers
                        newReward['SelectedUsers'] = List<String>.from(selectedUsers);
                        rewardsCollection.doc(rewardId).update(newReward);
                      }


                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _selectUsersDialog() {
    TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Rounded corners
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Center(
                        child: Text(
                          "Select Users",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search Bar
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: "Search Users...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 10),

                      // Select Birthday Members Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _selectBirthdayUsers();
                          setDialogState(() {}); // Refresh UI
                        },
                        icon: Icon(Icons.cake),
                        label: Text("Select All Birthday Members"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Select New Members Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            await _selectNewRegisteredUsers(pickedDate);
                            setDialogState(() {}); // Refresh UI
                          }
                        },
                        icon: Icon(Icons.person_add),
                        label: Text("Select New Members After Date"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Users List
                      Container(
                        height: MediaQuery.of(context).size.height *
                            0.4, // Dynamic height
                        width: double.maxFinite, // Ensures proper fit
                        child: StreamBuilder(
                          stream: usersCollection.snapshots(),
                          builder:
                              (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text("Error loading users"));
                            }

                            var users = snapshot.data!.docs.where((doc) {
                              var user = doc.data() as Map<String, dynamic>;
                              var name = user['FirstName']?.toLowerCase() ?? '';
                              return searchQuery.isEmpty ||
                                  name.contains(searchQuery);
                            }).toList();

                            if (users.isEmpty) {
                              return Center(child: Text("No users found."));
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                var doc = users[index];
                                var user = doc.data() as Map<String, dynamic>;
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CheckboxListTile(
                                    title: Text(
                                      user['FirstName'] ?? 'No Name',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text("ID: ${doc.id}"),
                                    value: selectedUsers.contains(doc.id),
                                    activeColor: Colors.blue,
                                    onChanged: (bool? selected) {
                                      setDialogState(() {
                                        if (selected == true) {
                                          selectedUsers.add(doc.id);
                                        } else {
                                          selectedUsers.remove(doc.id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text("Done"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteReward(String rewardId) {
    rewardsCollection.doc(rewardId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manage Rewards",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {}); // Refresh data manually
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: rewardsCollection.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading rewards"));
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No rewards available."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var reward = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      reward['Points'].toString(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    reward['RewardDetails'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(
                            // Prevents overflow in case of long expiry date text
                            child: Text(
                              "Expiry: ${reward['ExpiredDate'].toDate()}",
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                              overflow:
                                  TextOverflow.ellipsis, // Truncates long text
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        children:
                            (reward['EligibleUserTypes'] as List<dynamic>?)
                                    ?.map((type) => Chip(
                                          label: Text(type),
                                          backgroundColor: Colors.blue.shade100,
                                        ))
                                    .toList() ??
                                [const Text("No Eligible Users")],
                      ),
                    ],
                  ),
                  trailing: FittedBox(
                    // Ensures icons don't overflow
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Prevents taking too much space
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _openRewardDialog(
                            rewardId: doc.id,
                            rewardData: reward,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteReward(doc.id),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openRewardDialog(),
        backgroundColor: Colors.green,
        tooltip: "Add New Reward",
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
