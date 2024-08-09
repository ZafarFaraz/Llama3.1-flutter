import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
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
  final ScrollController _scrollController = ScrollController();

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
          _chatHistories[topics[_selectedIndex]]?.add({
            'role': 'assistant',
            'content': message,
          });
        });
        _scrollToBottom(); // Scroll to the bottom when a new message is added
      } else {
        print('Received null Datagram');
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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

      // Check if the message requires location data
      if (_requiresLocationData(message)) {
        await _fetchAndStoreLocation();
      }

      String messageWithOptionalLocation = message;
      if (_locationAddress != null && _requiresLocationData(message)) {
        messageWithOptionalLocation = '$message\nLocation: $_locationAddress';
      }

      _sendUdpMessage(messageWithOptionalLocation);

      _scrollToBottom(); // Scroll to the bottom after sending a message
    }
  }

  bool _requiresLocationData(String message) {
    // Remove punctuation from the message and convert to lowercase
    final normalizedMessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    // Check for keywords that imply location-based information is needed
    final keywords = ['location', 'weather', 'near me'];
    return keywords.any((keyword) => normalizedMessage.contains(keyword));
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
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _udpClient.close(); // Close the UDP socket when the app is closed
    _scrollController.dispose(); // Dispose of the scroll controller
    super.dispose();
  }
}

class ChatView extends StatelessWidget {
  final List<Map<String, String>> chatHistory;
  final Function(String) onSendMessage;
  final bool isGettingLocation;
  final ScrollController scrollController;

  ChatView({
    required this.chatHistory,
    required this.onSendMessage,
    required this.isGettingLocation,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController _controller = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController, // Attach the scroll controller
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
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      onSendMessage(text);
                      _controller.clear();
                      _scrollToBottom(); // Scroll to the bottom after submitting a message
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    onSendMessage(_controller.text);
                    _controller.clear();
                    _scrollToBottom(); // Scroll to the bottom after sending a message
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
