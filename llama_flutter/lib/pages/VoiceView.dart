import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livespeechtotext/livespeechtotext.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  late FlutterTts _flutterTts;
  late UdpService _udpService;
  late LocationService _locationService;

  bool _isListening = false;
  bool _isResponding = false;
  String _recognizedText = '';
  String _responseText = '';
  String _topic = ''; // This will be generated dynamically
  String? _localeDisplayName = '';
  StreamSubscription<dynamic>? onSuccessEvent;

  @override
  void initState() {
    super.initState();
    _liveSpeechToText = Livespeechtotext();
    initTts();
    _udpService = UdpService();
    _locationService = LocationService();

    // Generate a unique topic for each session
    _topic = _generateUniqueTopic();

    _initializeUdpClient();
    _initializeSpeechToText();

    // Fetch locale display name
    _liveSpeechToText.getLocaleDisplayName().then((value) {
      setState(() {
        _localeDisplayName = value;
      });
    });

    _speak('Welcome to voice chat');
  }

  @override
  void dispose() {
    onSuccessEvent?.cancel();
    _udpService.dispose();
    _flutterTts.stop(); // Stop any ongoing TTS when the screen is disposed
    super.dispose();
  }

  Future<dynamic> initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
        ],
        IosTextToSpeechAudioMode.defaultMode);
  }

  String _generateUniqueTopic() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return 'Topic_$timestamp';
  }

  void _initializeSpeechToText() {
    onSuccessEvent = _liveSpeechToText.addEventListener("success", (value) {
      if (value.runtimeType != String) return;
      if ((value as String).isEmpty) return;

      setState(() {
        _recognizedText = value;
      });

      // Send the transcribed text to your server via UDP
      _sendMessage(_recognizedText);
    });
  }

  void _initializeUdpClient() {
    _udpService.initializeUdpClient((message) {
      setState(() {
        _responseText = message;
        _isResponding = true;
      });

      // Use TTS to speak out the response
      _speak(_responseText);
    });
  }

  void _startListening() {
    try {
      _liveSpeechToText.start();
      setState(() {
        _isListening = true;
      });
    } on PlatformException {
      log('Error starting speech recognition');
    }
  }

  void _stopListening() {
    try {
      _liveSpeechToText.stop();
      setState(() {
        _isListening = false;
      });
    } on PlatformException {
      log('Error stopping speech recognition');
    }
  }

  void _sendMessage(String message) async {
    if (message.isNotEmpty) {
      // Check if the message requires location data
      if (Utils.requiresLocationData(message)) {
        final location = await _locationService.fetchAndStoreLocation();
        if (location != null) {
          message += '\nLocation: $location';
        }
      }

      final jsonPayload = jsonEncode({
        'topic': _topic,
        'content': message,
      });

      _udpService.sendUdpMessage(
        message,
        _topic,
        '10.0.0.122', // Server IP address
        8765, // Server port
      );
      _stopListening();
      print('Sent message: $message');
    }
  }

  Future<void> _speak(String text) async {
    print("Speaking: $text"); // Debugging statement

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);

    // Check if speaking is available and then speak
    var result = await _flutterTts.speak(text);
    await _flutterTts.awaitSpeakCompletion(true);
    if (result == 1) {
      print("Speech started successfully");
    } else {
      print("Failed to start speech");
    }

    // Handle the completion of the speech
    _flutterTts.setCompletionHandler(() {
      print("Speech completed"); // Debugging statement
      setState(() {
        _isResponding = false;
      });
    });

    // Handle TTS errors
    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });
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
              onTap: _isListening ? _stopListening : _startListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularVisualizer(
                    isListening: _isListening,
                    isResponding: _isResponding,
                  ),
                  Text(
                    'Tap to Speak',
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
