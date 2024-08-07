import 'dart:io';

import 'package:flutter/material.dart';
import 'package:udp/udp.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(), // Enable dark mode
      home: UdpChatScreen(),
    );
  }
}

class UdpChatScreen extends StatefulWidget {
  @override
  _UdpChatScreenState createState() => _UdpChatScreenState();
}

class _UdpChatScreenState extends State<UdpChatScreen> {
  int _selectedIndex = 0;
  final List<List<Map<String, String>>> _chatHistories = [
    [], // Topic 1
    [], // Topic 2
    [], // Topic 3
  ];

  late UDP _udpClient;
  String _response = '';

  @override
  void initState() {
    super.initState();
    _initializeUdpClient();
  }

  void _initializeUdpClient() async {
    _udpClient = await UDP
        .bind(Endpoint.any(port: Port(0))); // Bind to any available port

    // Listen for incoming messages
    _udpClient.asStream().listen((datagram) {
      if (datagram != null) {
        String message = String.fromCharCodes(datagram.data);
        print('Received response: $message');
        setState(() {
          _chatHistories[_selectedIndex].add({
            'role': 'assistant',
            'content': message,
          });
        });
      } else {
        print('Received null Datagram');
      }
    });
  }

  void _sendMessage(String message) async {
    if (message.isNotEmpty) {
      // Add the user's message to the chat history
      setState(() {
        _chatHistories[_selectedIndex].add({
          'role': 'user',
          'content': message,
        });
      });

      // Send the message via UDP
      var dataLength = await _udpClient.send(
        message.codeUnits,
        Endpoint.unicast(
          InternetAddress('10.0.0.122'), // Server IP address
          port: Port(8765), // Server port
        ),
      );
      print('Sent $dataLength bytes');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.topic),
                label: Text('Topic 1'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.topic),
                label: Text('Topic 2'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.topic),
                label: Text('Topic 3'),
              ),
            ],
          ),
          Expanded(
            child: ChatView(
              chatHistory: _chatHistories[_selectedIndex],
              onSendMessage: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _udpClient.close(); // Close the UDP socket when the app is closed
    super.dispose();
  }
}

class ChatView extends StatelessWidget {
  final List<Map<String, String>> chatHistory;
  final Function(String) onSendMessage;

  ChatView({required this.chatHistory, required this.onSendMessage});

  @override
  Widget build(BuildContext context) {
    TextEditingController _controller = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: chatHistory.length,
            itemBuilder: (context, index) {
              final message = chatHistory[index];
              final isUser = message['role'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue : Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(message['content'] ?? ''),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    onSendMessage(_controller.text);
                    _controller.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ## checking if this causes anything
