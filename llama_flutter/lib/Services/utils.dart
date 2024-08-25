import 'dart:io';

import 'package:flutter/services.dart';

class Utils {
  static bool requiresLocationData(String message) {
    // Remove punctuation from the message and convert to lowercase
    final normalizedMessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    // Check for keywords that imply location-based information is needed
    final keywords = ['location', 'weather', 'near me'];
    return keywords.any((keyword) => normalizedMessage.contains(keyword));
  }

  static bool requiresHomeInfo(String message) {
    // Remove punctuation from the message and convert to lowercase
    final normalizedMessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    final keywords = ['accessories', 'lights'];
    return keywords.any((keyword) => normalizedMessage.contains(keyword));
  }

  static bool alteringHomeDevices(String message) {
    // Remove punctuation from the message and convert to lowercase
    final normalizedMessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    final keywords = ['turn on', 'turn off'];
    return keywords.any((keyword) => normalizedMessage.contains(keyword));
  }
}

class HomeManager {
  static const MethodChannel _platform = MethodChannel('jarvis_data');

  // Fetch accessories from the native side and group them by home and room
  static Future<Map<String, Map<String, List<Map<String, String>>>>>
      fetchAccessories() async {
    final Map<String, Map<String, List<Map<String, String>>>> homeAccessories =
        {};

    try {
      final List<dynamic> result =
          await _platform.invokeMethod('fetchAccessories');
      final List<Map<String, String>> accessories =
          result.map((item) => Map<String, String>.from(item)).toList();

      // Group accessories by home and room
      for (var accessory in accessories) {
        final home = accessory['home'] ?? 'Unknown Home';
        final room = accessory['room'] ?? 'Unknown Room';
        if (homeAccessories.containsKey(home)) {
          if (homeAccessories[home]!.containsKey(room)) {
            homeAccessories[home]![room]!.add(accessory);
          } else {
            homeAccessories[home]![room] = [accessory];
          }
        } else {
          homeAccessories[home] = {
            room: [accessory]
          };
        }
      }
    } on PlatformException catch (e) {
      print("Failed to fetch accessories: '${e.message}'.");
    }

    return homeAccessories;
  }

  static void handleMessage(String message) {
    _parseAndExecuteCommand(message);
  }

  static void _parseAndExecuteCommand(String message) {
    String lowerMessage = message.toLowerCase();

    bool isTurnOn = lowerMessage.contains('turn on');
    bool isTurnOff = lowerMessage.contains('turn off');

    if (isTurnOn || isTurnOff) {
      // Extract the accessory name
      String accessoryName = message
          .replaceFirst('turn on ', '')
          .replaceFirst('turn off ', '')
          .trim();

      // Assume the room is known and is 'Living room'
      String roomName = 'Living room';

      // Call the native method to toggle the accessory
      _toggleAccessory(accessoryName, roomName, isTurnOn);
    }
  }

  static void _toggleAccessory(
      String accessoryName, String roomName, bool turnOn) {
    try {
      _platform.invokeMethod('toggleAccessory', {
        'name': accessoryName,
        'room': roomName,
      }).then((result) {
        print(
            '${turnOn ? 'Turned on' : 'Turned off'} $accessoryName in $roomName');
      }).catchError((error) {
        print('Failed to toggle $accessoryName: $error');
      });
    } catch (e) {
      print("Error: $e");
    }
  }

  // Fetch the current state of the accessory
  static void _fetchAccessoryState(
      String accessoryName, Function(bool) callback) {
    try {
      _platform.invokeMethod('getAccessoryState', {
        'name': accessoryName,
        'room': 'Living Room',
      }).then((state) {
        bool currentState = state as bool;
        callback(currentState);
      }).catchError((error) {
        print('Failed to fetch state for $accessoryName: $error');
        callback(
            false); // Assuming false as a fallback, depending on your needs
      });
    } catch (e) {
      print("Error: $e");
      callback(false);
    }
  }

  // Send the summary back to the AI model
  static void _sendSummaryToAI(String summary, [Function(String)? onSummary]) {
    // This could involve sending it to a server, logging it, or any other mechanism depending on your AI model setup
    print("Summary sent to AI: $summary");
    if (onSummary != null) {
      onSummary(summary);
    }
  }
}
