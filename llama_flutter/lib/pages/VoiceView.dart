import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livespeechtotext/livespeechtotext.dart';

import '../Components/audioVisualizer.dart';
import '../Services/location.dart';
import '../Services/udp.dart';
import '../Services/utils.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<StatefulWidget> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  late Livespeechtotext _liveSpeechToText;
  late UdpService _udpService;
  late LocationService _locationService;

  bool _isListening = false;
  bool _isResponding = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _liveSpeechToText = Livespeechtotext();
    _udpService = UdpService();
    _locationService = LocationService();

    // Initialize UDP client with a callback to handle received messages
    _udpService.initializeUdpClient((message) {
      setState(() {
        _isResponding = true;
        // Optionally process the received message if needed
      });
    }, false);

    // Initialize speech-to-text recognition
    _initializeSpeechToText();
  }

  @override
  void dispose() {
    _udpService.dispose();
    super.dispose();
  }

  void _initializeSpeechToText() {
    _liveSpeechToText.addEventListener("success", (value) {
      if (value is String && value.isNotEmpty) {
        setState(() {
          _recognizedText = value;
        });
      }
    });
  }

  void _toggleRecording() {
    if (_isListening) {
      _stopRecording();
    } else {
      _startListening();
    }
  }

  void _startListening() {
    try {
      _liveSpeechToText.start();
      setState(() {
        _isListening = true;
      });
    } on PlatformException {
      print('Error starting speech recognition');
    }
  }

  void _stopRecording() {
    if (_isListening) {
      _liveSpeechToText.stop();
      setState(() {
        _isListening = false;
      });
      _sendMessage(_recognizedText);
    }
  }

  void _sendMessage(String message) async {
    if (message.isNotEmpty) {
      if (Utils.requiresLocationData(message)) {
        final location = await _locationService.fetchAndStoreLocation();
        if (location != null) {
          message += '\nLocation: $location';
        }
      }

      _udpService.sendUdpMessage(
        message,
        'Topic_${DateTime.now().millisecondsSinceEpoch}',
        '10.0.0.122', // Server IP address
        8765, // Server port
      );
      print('Sent message: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _toggleRecording,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularVisualizer(
                    isListening: _isListening,
                    isResponding: _isResponding,
                  ),
                  Text(
                    _isListening ? 'Stop Recording' : 'Tap to Start Recording',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
