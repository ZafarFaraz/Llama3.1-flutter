import 'dart:convert';
import 'dart:io';
import 'package:udp/udp.dart';
import 'package:flutter_tts/flutter_tts.dart';

class UdpService {
  late UDP _udpClient;
  late FlutterTts _flutterTts;
  String udpAddress = "10.0.0.73";
  int udpPort = 8765;

  UdpService() {
    _flutterTts = FlutterTts();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setVoice({"name": "Oliver", "locale": "en-GB"});
    await _flutterTts.setPitch(0.8); // Adjust pitch as needed
    await _flutterTts.setSpeechRate(0.35); // Adjust speech rate as needed

    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
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

  String sendIntroduction() {
    // Construct the introduction string with home accessories and response format
    final introductionData = {
      "introduction":
          "Hi, I'm Zafar and I live in Reservoir, Melbourne 3073. Here is some additional information about my home accessories to help you perform actions:",
      "home_accessories": {
        "Phantom Zone": {
          "Living Room": ["Temporal Spark", "TV lights", "TV Lamp"],
          "Default Room": ["Philips hue"],
          "Study": ["Desk lamp"],
          "Zafars Room": ["Bedroom lights"]
        }
      },
      "action_format": {
        "description":
            "When an action needs to be performed, please send it back in the following format:",
        "format": {
          "action": "toggle",
          "device_name": "TV Lamp",
          "room_name": "Living room",
          "state": "on"
        }
      }
    };

    // Use jsonEncode and format the result with indentation for readability
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(introductionData);

    // Log the formatted introduction message for debugging
    print("The formatted introduction message is: \n$jsonString");

    return jsonString;
  }

  Future<void> sendUdpMessage(String message, String topic) async {
    final String messageContent = message;

    // Create the JSON payload with the resolved message content
    final jsonPayload = jsonEncode({
      'topic': topic,
      'content': messageContent,
    });

    print("The message sent was $jsonPayload");

    // Send the message via UDP
    await _udpClient.send(
      jsonPayload.codeUnits,
      Endpoint.unicast(
        InternetAddress(udpAddress), // Server IP address
        port: Port(udpPort), // Server port
      ),
    );
  }

  void dispose() {
    _udpClient.close();
  }
}
