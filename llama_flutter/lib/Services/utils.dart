import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;

const MethodChannel _platform = MethodChannel('jarvis_data');

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

class EventManager {
  List<Map<String, dynamic>> loadedEvents = [];
  List<Map<String, dynamic>> loadedReminders = [];
  Future<List<Map<String, dynamic>>> loadReminders() async {
    try {
      final List<dynamic> result =
          await _platform.invokeMethod('loadReminders');
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on PlatformException catch (e) {
      throw Exception("Failed to load reminders: ${e.message}");
    }
  }

  Future<List<Map<String, dynamic>>> loadUpcomingEvents() async {
    try {
      final List<dynamic> result =
          await _platform.invokeMethod('loadUpcomingEvents');
      return result
          .map((item) =>
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      throw Exception("Failed to load upcoming events: ${e.message}");
    }
  }

  Future<String> addInfoEventsAndReminders(String message) async {
    String lowerMessage = message.toLowerCase();
    final EventManager _eventManager = EventManager();

    if (['looking'].any((keyword) => lowerMessage.contains(keyword))) {
      final reminders = await _eventManager.loadReminders();
      final events = await _eventManager.loadUpcomingEvents();

      // Construct a valid JSON string for events and reminders
      final eventsJson = jsonEncode(events);
      final remindersJson = jsonEncode(reminders);

      // Sanitize the input message to remove or escape problematic characters
      String sanitizedMessage = lowerMessage.replaceAll("'", "\\'");

      // Construct the final message, ensuring it's safe for JSON inclusion
      return "$sanitizedMessage. Here is some information from my calendar for the upcoming year: $eventsJson and my due reminders: $remindersJson";
    } else {
      return lowerMessage;
    }
  }
}

class HomeManager {
  Map<String, Map<String, List<Map<String, String>>>> loadedAccessories = {};

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

  void handleLLMActionResponse(String response) {
    print("Received response: $response");
    try {
      // Extract action, device_name, room_name, and state using RegExp
      final actionMatch =
          RegExp(r'action\s+(\w+)', caseSensitive: false).firstMatch(response);
      final deviceMatch =
          RegExp(r'device_name\s+([^\n]+)', caseSensitive: false)
              .firstMatch(response);
      final roomMatch = RegExp(r'room_name\s+([^\n]+)', caseSensitive: false)
          .firstMatch(response);
      final stateMatch =
          RegExp(r'state\s+(\w+)', caseSensitive: false).firstMatch(response);

      if (actionMatch != null &&
          deviceMatch != null &&
          roomMatch != null &&
          stateMatch != null) {
        final String action = actionMatch.group(1)!.toLowerCase();
        final String deviceName = deviceMatch.group(1)!.trim().toLowerCase();
        final String roomName = roomMatch.group(1)!.trim().toLowerCase();
        final String state = stateMatch.group(1)!.toLowerCase();

        // Handle the toggle action
        if (action == "toggle") {
          bool turnOn = (state == "on");
          _toggleAccessory(deviceName, 'Living room', turnOn);
        }

        print(
            "Parsed response: action=$action, device=$deviceName, room=$roomName, state=$state");
      } else {
        print("Unable to extract necessary information from the response.");
      }
    } catch (e) {
      print("Error parsing LLM action response: $e");
    }
  }

  // Toggle accessory on or off without verifying if it exists
  static void _toggleAccessory(
      String accessoryName, String roomName, bool turnOn) {
    try {
      _platform.invokeMethod('toggleAccessory', {
        'name': accessoryName,
        'room': roomName,
        'state': turnOn ? 'on' : 'off',
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
}

class LocationService {
  String? _locationAddress;

  Future<String?> fetchAndStoreLocation() async {
    loc.Location location = loc.Location(); // Use the alias here
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return null;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return null;
      }
    }

    loc.LocationData locationData = await location.getLocation();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      Placemark place = placemarks[0];
      _locationAddress =
          "${place.locality}, ${place.postalCode}, ${place.country}";
      return _locationAddress;
    } catch (e) {
      print('Failed to get address: $e');
      return 'Address unavailable';
    }
  }

  Future<String> addLocationData(message) async {
    String lowermessage =
        message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    if (['location', 'weather', 'near me']
        .any((keyword) => lowermessage.contains(keyword))) {
      String? locationAddress = await fetchAndStoreLocation();
      return '$message my location is: $_locationAddress';
    } else {
      return lowermessage;
    }
  }
}
