import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:ezcharge/views/customer/Service/api_key.dart';

class Chatbotscreen extends StatefulWidget {
  @override
  _ChatbotscreenState createState() => _ChatbotscreenState();
}

class _ChatbotscreenState extends State<Chatbotscreen> {
  String _customerName = "";
  final List<Message> _messages = [];
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
  }

  Future<void> _fetchCustomerData() async {
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
            _customerName = "${userDoc["FirstName"]} ${userDoc["LastName"]}";
          });
        }
      }
    } catch (e) {
      print("Error fetching customer data: $e");
    }
  }
  void onSendMessage() async {
    Message message = Message(text: _textEditingController.text, isMe: true);
    _textEditingController.clear();

    setState(() {
      _messages.insert(0, message);
    });

    String response = await sendMessageToChatGpt(message.text);

    Message chatGpt = Message(text: response, isMe: false);

    setState(() {
      _messages.insert(0, chatGpt);
    });
  }

  Future<String> sendMessageToChatGpt(String message) async {
    Uri uri = Uri.parse("https://api.openai.com/v1/chat/completions");

    Map<String, dynamic> body = {
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content": "You are an EV Charging customer service chatbot for EZCHARGE. "
              "You help customers with EV charging issues like check-in failures, connector problems, payment issues, or slot availability. "
              "If the question is unrelated to EV charging, respond with: 'I can't understand your question'."
        },
        {"role": "user", "content": message}
      ],
      "max_tokens": 500,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${APIKey.apiKey}",
        },
        body: json.encode(body),
      );

      Map<String, dynamic> parsedResponse = json.decode(response.body);

      // Extract response message
      String reply = parsedResponse['choices'][0]['message']['content'].trim();

      return reply;
    } catch (e) {
      print("Error fetching chatbot response: $e");
      return "I can't understand your question";
    }
  }

  //Updated chat-bubble design
  Widget _buildMessage(Message message) {
    // Decide alignment based on who sent the message
    final alignment = message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bgColor = message.isMe ? Colors.blue[50] : Colors.grey[200];
    final textColor = Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: message.isMe ? Radius.circular(12) : Radius.circular(0),
      bottomRight: message.isMe ? Radius.circular(0) : Radius.circular(12),
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Optionally show an avatar on the left side if not the user
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('images/ezcharge_logo.png'),
            ),

            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: borderRadius,
              ),
              child: Column(
                crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Name label (optional)
                  Text(
                    message.isMe ? _customerName : 'EZCHARGE Customer Service',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 6),
                  // Actual message text
                  Text(
                    message.text,
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
          ),
          // Optionally show an avatar on the right side if it's the user
          if (message.isMe) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Example of updating the AppBar to match the style from the first picture
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('images/ezcharge_logo.png'),
            ),
            SizedBox(width: 8),
            Text(
              'EZCHARGE Help Center',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),


      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _textEditingController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(10.0),
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: onSendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isMe;
  Message({required this.text, required this.isMe});
}