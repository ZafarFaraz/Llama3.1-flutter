import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:llama_flutter/pages/VoiceView.dart';

import 'pages/ChatView.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(), // Enable dark mode
      home: CommMode(),
    );
  }
}

class CommMode extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _CommState();
}

class _CommState extends State<CommMode> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[UdpChatScreen(), VoiceScreen()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.speaker_notes),
            label: 'Text',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Voice',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
