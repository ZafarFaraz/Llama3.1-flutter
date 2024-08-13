import 'dart:convert';
import 'dart:io';
import 'package:udp/udp.dart';
import 'package:flutter_tts/flutter_tts.dart';

class UdpService {
  late UDP _udpClient;
  late FlutterTts _flutterTts;

  UdpService() {
    _flutterTts = FlutterTts();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setVoice({"name": "Oliver", "locale": "en-GB"});
    await _flutterTts.setPitch(0.8); // Adjust pitch as needed
    await _flutterTts.setSpeechRate(0.55); // Adjust speech rate as needed

    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );

    await _flutterTts.speak('Welcome to my world');
  }

  Future<void> initializeUdpClient(
      Function(String) onMessageReceived, bool chatMode) async {
    _udpClient = await UDP
        .bind(Endpoint.any(port: Port(0))); // Bind to any available port

    // Listen for incoming messages
    _udpClient.asStream().listen((datagram) {
      if (datagram != null) {
        String message = String.fromCharCodes(datagram.data);
        onMessageReceived(
            message); // Call the callback with the received message
        if (!chatMode) {
          _speak(message);
        } // Read the message out loud if not in chat mode
      }
    });
  }

  Future<void> _speak(String text) async {
    // Sanitize the text by escaping problematic characters
    String sanitizedText = text.replaceAll("'", "");

    // Set completion and error handlers before starting TTS
    _flutterTts.setCompletionHandler(() {
      print("Speech completed");
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });

    // Wait for any ongoing speech to complete before starting new one
    await _flutterTts.awaitSpeakCompletion(true);

    // Ensure the TTS starts after the delay
    var result = await _flutterTts.speak(sanitizedText);
    print(sanitizedText);
    if (result == 1) {
      print("Speech started successfully");
    } else {
      print("Failed to start speech");
    }
  }

  Future<void> sendUdpMessage(
      String message, String topic, String address, int port) async {
    final jsonPayload = jsonEncode({
      'topic': topic,
      'content': message,
    });

    // Send the message via UDP
    await _udpClient.send(
      jsonPayload.codeUnits,
      Endpoint.unicast(
        InternetAddress(address), // Server IP address
        port: Port(port), // Server port
      ),
    );
  }

  void dispose() {
    _udpClient.close();
  }
}
