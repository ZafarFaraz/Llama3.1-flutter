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
  final List<String> topics = ['Topic 1', 'Topic 2'];
  final Map<String, List<Map<String, String>>> _chatHistories = {
    'Topic 1': [],
    'Topic 2': [],
  };

  late UdpService _udpService;
  late LocationService _locationService;
  String? _locationAddress;
  final ScrollController _scrollController = ScrollController();
  Map<String, Map<String, List<Map<String, String>>>> _homeAccessories = {};
  String? _selectedHome;

  @override
  void initState() {
    super.initState();
    _udpService = UdpService();
    _locationService = LocationService();
    _udpService.initializeUdpClient(_onMessageReceived, true);
    _loadAccessories();
    _sendMessage('turn off TV Lamp');
  }

  Future<void> _loadAccessories() async {
    final homeAccessories = await HomeManager.fetchAccessories();
    setState(() {
      _homeAccessories = homeAccessories;
      if (_homeAccessories.isNotEmpty) {
        _selectedHome = _homeAccessories.keys.first;
      }
    });
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
      // Add the message to the chat history
      setState(() {
        _chatHistories[topics[_selectedIndex]]?.add({
          'role': 'user',
          'content': message,
        });
      });

      // Utility function to check if a message is a HomeKit command
      bool _isHomeKitCommand(String message) {
        String lowerMessage = message.toLowerCase();
        return lowerMessage.startsWith('turn on') ||
            lowerMessage.startsWith('turn off');
      }

      // Intercept the message to check if it's a command for HomeKit
      if (_isHomeKitCommand(message)) {
        HomeManager.handleMessage(message);
      } else {
        // Check if the message requires location data
        if (Utils.requiresLocationData(message)) {
          _locationAddress = await _locationService.fetchAndStoreLocation();
        }

        if (Utils.requiresHomeInfo(message)) {
          message =
              '$message some home data information for you $_homeAccessories';
        }

        String messageWithOptionalLocation = message;
        if (_locationAddress != null && Utils.requiresLocationData(message)) {
          messageWithOptionalLocation = '$message\nLocation: $_locationAddress';
        }

        // If not a HomeKit command, send the message to the AI
        _udpService.sendUdpMessage(
          messageWithOptionalLocation,
          topics[_selectedIndex],
          '10.0.0.122', // Server IP address
          8765, // Server port
        );
      }

      // Scroll to the bottom after sending a message
      _scrollToBottom();
    }
  }

  _addTopic(String topic) {
    setState(() {
      if (!topics.contains(topic)) {
        topics.add(topic);
        _chatHistories[topic] =
            []; // Initialize an empty chat history for the new topic
      }
    });
  }

  @override
  void dispose() {
    _udpService.dispose(); // Dispose UDP service
    _scrollController.dispose(); // Dispose scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey,
      body: Row(
        children: [
          FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () {
              // Example of adding a new topic
              _addTopic('Topic ${topics.length + 1}');
            },
          ),
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30)),
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
