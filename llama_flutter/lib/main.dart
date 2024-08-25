import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _addTopic() {
    setState(() {
      topics.add('Topic ${topics.length + 1}');
    });
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
