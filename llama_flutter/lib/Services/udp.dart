import 'dart:convert';
import 'dart:io';
import 'package:udp/udp.dart';

class UdpService {
  late UDP _udpClient;

  Future<void> initializeUdpClient(Function(String) onMessageReceived) async {
    _udpClient = await UDP
        .bind(Endpoint.any(port: Port(0))); // Bind to any available port

    // Listen for incoming messages
    _udpClient.asStream().listen((datagram) {
      if (datagram != null) {
        String message = String.fromCharCodes(datagram.data);
        onMessageReceived(
            message); // Call the callback with the received message
      }
    });
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
