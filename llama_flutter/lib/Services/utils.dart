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
}

class HomeManager {
  static const platform = MethodChannel('jarvis_data');

  static Future<Map<String, Map<String, List<Map<String, String>>>>>
      fetchAccessories() async {
    final Map<String, Map<String, List<Map<String, String>>>> homeAccessories =
        {};

    try {
      final List<dynamic> result =
          await platform.invokeMethod('fetchAccessories');
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
}
