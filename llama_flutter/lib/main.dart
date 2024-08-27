import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _reminders = [];
  Map<String, Map<String, List<Map<String, String>>>> _homeAccessories = {};
  String? _selectedHome;

  @override
  void initState() {
    super.initState();
    _loadEventsAndReminders();
    _loadAccessories();
  }

  void _addTopic() {
    setState(() {
      topics.add('Topic ${topics.length + 1}');
    });
  }

  Future<void> _loadAccessories() async {
    final homeAccessories = await HomeManager.fetchAccessories();
    setState(() {
      _homeAccessories = homeAccessories;
      if (_homeAccessories.isNotEmpty) {
        _selectedHome = _homeAccessories.keys.first;
      }
    });
  }

  Future<void> _loadEventsAndReminders() async {
    final EventManager _eventManager = EventManager();
    try {
      List<Map<String, dynamic>> reminders =
          await _eventManager.loadReminders();
      print(
          reminders); // Now this should print a correctly typed list of reminders.

      List<Map<String, dynamic>> events =
          await _eventManager.loadUpcomingEvents();
      print("Upcoming Events: $events");
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
}
