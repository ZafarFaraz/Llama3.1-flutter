import 'dart:async';

import 'package:flutter/material.dart';

import '../Services/udp.dart';
import '../Services/utils.dart';

class TextView extends StatefulWidget {
  final List<String> topics;

  const TextView({super.key, required this.topics});

  @override
  _TextScreenState createState() => _TextScreenState();
}

class _TextScreenState extends State<TextView> {
  int _selectedIndex = 0;
  final Map<String, List<Map<String, String>>> _chatHistories = {};

  late UdpService _udpService;
  late LocationService _locationService;
  final EventManager _eventManager = EventManager();
  String? _locationAddress;
  final ScrollController _scrollController = ScrollController();
  bool connStatus = false;

  @override
  void initState() {
    super.initState();
    _udpService = UdpService();
    _locationService = LocationService();
    _udpService.initializeUdpClient(_onMessageReceived, true);
    widget.topics.forEach((topic) {
      _chatHistories[topic] = [];
    });
  }

  void _onMessageReceived(String message) {
    print('Received response: $message');
    setState(() {
      _chatHistories[widget.topics[_selectedIndex]]?.add({
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
      if (Utils.alteringHomeDevices(message)) {
        HomeManager.parseAndExecuteCommand(message);
      } else {
        setState(() {
          _chatHistories[widget.topics[_selectedIndex]]?.add({
            'role': 'user',
            'content': message,
          });
        });
      }

      String messageWithOptionalLocation =
          await _locationService.addLocationData(message);

      String messageWithInfoAndReminders = await _eventManager
          .addInfoEventsAndReminders(messageWithOptionalLocation);

      _udpService.sendUdpMessage(messageWithInfoAndReminders,
          widget.topics[_selectedIndex] // Server port
          );

      _scrollToBottom();
    }
  }

  _addTopic(String topic) {
    setState(() {
      if (!widget.topics.contains(topic)) {
        widget.topics.add(topic);
        _chatHistories[topic] = [];
      }
    });
  }

  @override
  void dispose() {
    _udpService.dispose();
    _scrollController.dispose();
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
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            destinations: widget.topics.map((topic) {
              return NavigationRailDestination(
                icon: Icon(Icons.text_fields), // Text topic icon
                label: Text(topic),
              );
            }).toList(),
          ),
          Expanded(
            child: ChatView(
              chatHistory: _chatHistories[widget.topics[_selectedIndex]]!,
              onSendMessage: _sendMessage,
              isGettingLocation: _locationAddress == null,
              scrollController: _scrollController,
              isDarkMode: isDarkMode,
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
  final bool isDarkMode;

  ChatView(
      {required this.chatHistory,
      required this.onSendMessage,
      required this.isGettingLocation,
      required this.scrollController,
      required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    TextEditingController _controller = TextEditingController();

    return Container(
      margin: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.greenAccent.withAlpha(200)
                : Colors.greenAccent.withAlpha(250),
            blurRadius: 25.0,
            spreadRadius: 10.0,
            offset: const Offset(0.0, 0.0),
          ),
        ],
        color: isDarkMode ? Colors.black : Colors.grey,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController, // Attach the scroll controller
                itemCount: chatHistory.length,
                itemBuilder: (context, index) {
                  final message = chatHistory[index];
                  final isUser = message['role'] == 'user';
                  final content = message['content'] ?? '';

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color.fromARGB(255, 36, 91, 37)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildMessageContent(content),
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
                          borderRadius: BorderRadius.circular(30),
                        ),
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
                  SizedBox(width: 20),
                  CircleAvatar(
                    backgroundColor: Colors.green,
                    radius: 30,
                    child: IconButton(
                      icon: Icon(Icons.send, size: 30),
                      onPressed: () {
                        if (_controller.text.isNotEmpty) {
                          onSendMessage(_controller.text);
                          _controller.clear();
                          _scrollToBottom(); // Scroll to the bottom after sending a message
                        }
                      },
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

  Widget _buildMessageContent(String content) {
    if (content.contains('```')) {
      // Split the content on triple backticks to identify code blocks
      final parts = content.split('```');
      List<Widget> formattedContent = [];

      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          // Regular text
          formattedContent.add(Text(parts[i]));
        } else {
          // Code block
          formattedContent.add(Container(
            width: double.infinity,
            color: isDarkMode ? Colors.black54 : Colors.grey[300],
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.symmetric(vertical: 5),
            child: SelectableText(
              parts[i],
              style: TextStyle(
                fontFamily: 'Courier',
                backgroundColor: Colors.transparent,
                color: isDarkMode ? Colors.greenAccent : Colors.black,
              ),
            ),
          ));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: formattedContent,
      );
    } else {
      // Regular message without code block
      return Text(content);
    }
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
