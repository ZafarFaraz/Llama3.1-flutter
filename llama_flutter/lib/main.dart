import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc; // Alias the location package
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
  final List<String> topics = ['Topic 1', 'Topic 2', 'Topic 3'];
  final Map<String, List<Map<String, String>>> _chatHistories = {
    'Topic 1': [],
    'Topic 2': [],
    'Topic 3': [],
  };

  late UDP _udpClient;
  String? _locationAddress;

  @override
  void initState() {
    super.initState();
    _initializeUdpClient();
    _fetchAndStoreLocation();
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
          _chatHistories[topics[_selectedIndex]]?.add({
            'role': 'assistant',
            'content': message,
          });
        });
      } else {
        print('Received null Datagram');
      }
    });
  }

  Future<void> _fetchAndStoreLocation() async {
    loc.Location location = loc.Location(); // Use the alias here
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }

    loc.LocationData locationData = await location.getLocation();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      Placemark place = placemarks[0];
      _locationAddress =
          "${place.locality}, ${place.postalCode}, ${place.country}";
      print('Location fetched: $_locationAddress');
    } catch (e) {
      print('Failed to get address: $e');
      setState(() {
        _locationAddress = 'Address unavailable';
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isNotEmpty) {
      setState(() {
        _chatHistories[topics[_selectedIndex]]?.add({
          'role': 'user',
          'content': message,
        });
      });

      if (_locationAddress != null) {
        // Append the location data to the message
        String messageWithLocation = '$message\nLocation: $_locationAddress';
        _sendUdpMessage(messageWithLocation);
      } else {
        _sendUdpMessage(message);
      }
    }
  }

  void _sendUdpMessage(String message) async {
    // Prepare the JSON payload with topic and content
    final jsonPayload = jsonEncode({
      'topic': topics[_selectedIndex],
      'content': message,
    });

    // Send the message via UDP
    var dataLength = await _udpClient.send(
      jsonPayload.codeUnits,
      Endpoint.unicast(
        InternetAddress('10.0.0.122'), // Server IP address
        port: Port(8765), // Server port
      ),
    );
    print('Sent $dataLength bytes');
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
            destinations: topics.map((topic) {
              return NavigationRailDestination(
                icon: Icon(Icons.topic),
                label: Text(topic),
              );
            }).toList(),
          ),
          Expanded(
            child: ChatView(
              chatHistory: _chatHistories[topics[_selectedIndex]]!,
              onSendMessage: _sendMessage,
              isGettingLocation: _locationAddress == null,
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
  final bool isGettingLocation;

  ChatView(
      {required this.chatHistory,
      required this.onSendMessage,
      required this.isGettingLocation});

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
        if (isGettingLocation) CircularProgressIndicator(),
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
