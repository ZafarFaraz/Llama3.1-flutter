import 'dart:async';
import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:llama_flutter/Services/udp.dart';
import 'package:llama_flutter/Services/utils.dart';
import 'package:llama_flutter/pages/VoiceView.dart';

import 'pages/ChatView.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(), // Enable dark mode
      home: CommMode(),
    );
  }
}

class CommMode extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _CommState();
}

class _CommState extends State<CommMode> {
  bool isVoice = false;
  final List<String> topics = ['Topic 1', 'Topic 2'];
  late UdpService _udpService;
  bool connStatus = false;

  String? _selectedHome;

  @override
  void initState() {
    super.initState();
    _loadAccessories();
    _loadEventsAndReminders();
    _udpService = UdpService();
    _udpService.initializeUdpClient(_onMessageReceived, true).then((_) {
      _checkConnection();
    });
  }

  void _addTopic() {
    setState(() {
      topics.add('Topic ${topics.length + 1}');
    });
  }

  Future<void> _loadAccessories() async {
    final HomeManager _homeManager = HomeManager();
    _homeManager.loadedAccessories = await HomeManager.fetchAccessories();
    print("Loaded accessories: ${_homeManager.loadedAccessories}");
    setState(() {
      if (_homeManager.loadedAccessories.isNotEmpty) {
        _selectedHome = _homeManager.loadedAccessories.keys.first;
      }
    });
  }

  Future<void> _loadEventsAndReminders() async {
    final EventManager _eventManager = EventManager();
    try {
      _eventManager.loadedReminders = await _eventManager.loadReminders();

      _eventManager.loadedEvents = await _eventManager.loadUpcomingEvents();
    } catch (e) {
      print("Error loading reminders: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jarvis'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addTopic,
          ),
          IconButton(
              onPressed: _checkConnection,
              icon: Icon(
                Icons.connect_without_contact,
                color: connStatus ? Colors.green : Colors.red,
              )),
          Switch(
            value: isVoice,
            activeColor: Colors.purple,
            onChanged: (value) {
              setState(() {
                isVoice = value;
              });
            },
          ),
        ],
      ),
      body: isVoice ? VoiceView(topics: topics) : TextView(topics: topics),
    );
  }

  void _checkConnection() {
    _udpService.sendUdpMessage("Check Connection", "Connection Status");
    // Set a timeout to update the connection status if no response is received
    Timer(Duration(seconds: 10), () {
      if (!connStatus) {
        setState(() {
          connStatus = false; // No response, assume disconnected
        });
      }
    });
  }

  _onMessageReceived(String message) {
    print('Received response: $message');
    if (message == "Connection Confirmed") {
      setState(() {
        connStatus = true;
      });
    }
  }
}
