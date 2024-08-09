import 'package:flutter/material.dart';

import '../Services/location.dart';
import '../Services/udp.dart';
import '../Services/utils.dart';

class UdpChatScreen extends StatefulWidget {
  const UdpChatScreen({super.key});

  @override
  _UdpChatScreenState createState() => _UdpChatScreenState();
}

class _UdpChatScreenState extends State<UdpChatScreen> {
  int _selectedIndex = 0;
  final List<String> topics = ['Topic 1', 'Topic 2', 'Topic 3'];
  final Map<String, List<Map<String, String>>> _chatHistories = {
    'Topic 1': [],
    'Topic 2': [],
    'Topic 3': [],
  };

  late UdpService _udpService;
  late LocationService _locationService;
  String? _locationAddress;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _udpService = UdpService();
    _locationService = LocationService();
    _udpService.initializeUdpClient(_onMessageReceived);
  }

  void _onMessageReceived(String message) {
    print('Received response: $message');
    setState(() {
      _chatHistories[topics[_selectedIndex]]?.add({
        'role': 'assistant',
        'content': message,
      });
    });
    _scrollToBottom(); // Scroll to the bottom when a new message is added
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.isNotEmpty) {
      setState(() {
        _chatHistories[topics[_selectedIndex]]?.add({
          'role': 'user',
          'content': message,
        });
      });

      // Check if the message requires location data
      if (Utils.requiresLocationData(message)) {
        _locationAddress = await _locationService.fetchAndStoreLocation();
      }

      String messageWithOptionalLocation = message;
      if (_locationAddress != null && Utils.requiresLocationData(message)) {
        messageWithOptionalLocation = '$message\nLocation: $_locationAddress';
      }

      _udpService.sendUdpMessage(
        messageWithOptionalLocation,
        topics[_selectedIndex],
        '10.0.0.122', // Server IP address
        8765, // Server port
      );

      _scrollToBottom(); // Scroll to the bottom after sending a message
    }
  }

  @override
  void dispose() {
    _udpService.dispose(); // Dispose UDP service
    _scrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            destinations: topics.map((topic) {
              return NavigationRailDestination(
                icon: Icon(Icons.topic),
                label: Text(topic),
              );
            }).toList(),
          ),
          Expanded(
            child: ChatView(
              chatHistory: _chatHistories[topics[_selectedIndex]]!,
              onSendMessage: _sendMessage,
              isGettingLocation: _locationAddress == null,
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatView extends StatelessWidget {
  final List<Map<String, String>> chatHistory;
  final Function(String) onSendMessage;
  final bool isGettingLocation;
  final ScrollController scrollController;

  ChatView({
    required this.chatHistory,
    required this.onSendMessage,
    required this.isGettingLocation,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController _controller = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController, // Attach the scroll controller
            itemCount: chatHistory.length,
            itemBuilder: (context, index) {
              final message = chatHistory[index];
              final isUser = message['role'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue : Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(message['content'] ?? ''),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      onSendMessage(text);
                      _controller.clear();
                      _scrollToBottom(); // Scroll to the bottom after submitting a message
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    onSendMessage(_controller.text);
                    _controller.clear();
                    _scrollToBottom(); // Scroll to the bottom after sending a message
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
