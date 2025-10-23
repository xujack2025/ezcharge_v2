import 'package:flutter/material.dart';
import 'package:ezcharge/models/notification_model.dart';
import 'package:ezcharge/viewmodels/notification_viewmodel.dart';

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  final NotificationViewModel _notificationViewModel = NotificationViewModel();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<NotificationModel> _notifications = [];
  String? _editingNotificationId;

  @override
  void initState() {
    super.initState();
    _loadNotifications(); // ✅ Load Notifications on Init
  }

  // ✅ Load Notifications and Refresh UI
  Future<void> _loadNotifications() async {
    await _notificationViewModel.fetchNotifications();
    setState(() {
      _notifications = _notificationViewModel.notifications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Notifications"),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNotificationDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Create Notification"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(child: _buildNotificationList()),
        ],
      ),
    );
  }

  // ✅ Build Notification List
  Widget _buildNotificationList() {
    return _notifications.isEmpty
        ? const Center(
            child: Text(
              "No notifications available.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          )
        : ListView.builder(
            itemCount: _notifications.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              var notification = _notifications[index];
              return _buildNotificationCard(notification);
            },
          );
  }

  // ✅ Build Each Notification Card
  Widget _buildNotificationCard(NotificationModel notification) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shadowColor: Colors.grey.shade300,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(Icons.notifications, color: Colors.white),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            notification.description,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditButton(notification),
            _buildDeleteButton(notification.notificationID),
          ],
        ),
      ),
    );
  }

  // ✅ Edit Notification Button
  Widget _buildEditButton(NotificationModel notification) {
    return IconButton(
      icon: const Icon(Icons.edit, color: Colors.blue),
      onPressed: () => _showNotificationDialog(
        notificationId: notification.notificationID,
        title: notification.title,
        message: notification.description,
      ),
    );
  }

  // ✅ Delete Notification Button
  Widget _buildDeleteButton(String notificationID) {
    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () async {
        await _notificationViewModel.deleteNotification(notificationID);
        _loadNotifications(); // ✅ Refresh List After Deletion
      },
    );
  }

  // ✅ Show Notification Dialog for Create/Update
  void _showNotificationDialog(
      {String? notificationId, String? title, String? message}) {
    _titleController.text = title ?? "";
    _messageController.text = message ?? "";
    _editingNotificationId = notificationId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text(notificationId == null
                ? "Create Notification"
                : "Update Notification"),
          ],
        ),
        content: _buildDialogContent(),
        actions: _buildDialogActions(),
      ),
    );
  }

  // ✅ Build Dialog Content (Text Fields)
  Widget _buildDialogContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: "Title",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: "Message",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Build Dialog Actions (Create/Update & Cancel)
  List<Widget> _buildDialogActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Cancel"),
      ),
      ElevatedButton(
        onPressed: _saveNotification,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        child: Text(_editingNotificationId == null ? "Create" : "Update"),
      ),
    ];
  }

  // ✅ Save or Update Notification
  Future<void> _saveNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      return;
    }

    if (_editingNotificationId == null) {
      await _notificationViewModel.createNotification(
        _titleController.text.trim(),
        _messageController.text.trim(),
      );
    } else {
      await _notificationViewModel.updateNotification(
        _editingNotificationId!,
        _titleController.text.trim(),
        _messageController.text.trim(),
      );
    }

    _loadNotifications(); // ✅ Refresh List After Saving
    Navigator.pop(context);
  }
}
