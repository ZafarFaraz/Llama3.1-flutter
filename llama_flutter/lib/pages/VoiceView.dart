import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../Services/location.dart';
import '../Services/udp.dart';
import '../Services/utils.dart';

class VoiceView extends StatefulWidget {
  const VoiceView({super.key});

  @override
  _VoiceViewState createState() => _VoiceViewState();
}

class _VoiceViewState extends State<VoiceView> {
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
  final TextEditingController _controller = TextEditingController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcription = '';

  @override
  void initState() {
    super.initState();
    _udpService = UdpService();
    _locationService = LocationService();
    _udpService.initializeUdpClient(_onMessageReceived, false);
    _speech = stt.SpeechToText();
  }

  void _onMessageReceived(String message) {
    print('Received response: $message');
    setState(() {
      _chatHistories[topics[_selectedIndex]]?.add({
        'role': 'assistant',
        'content': message,
      });
    });
    _controller.clear();
    _scrollToBottom();
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
        _chatHistories[topics[_selectedIndex]]
            ?.add({'role': 'user', 'content': message});
      });

      if (Utils.requiresLocationData(message)) {
        _locationAddress = await _locationService.fetchAndStoreLocation();
      }

      String messageWithOptionalLocation =
          "${message} note that the response will be read out to me aloud, so please keep it as short as possible without letting useful infomation let out. Also dont use contraction, use proper words so that i can understand it better";

      if (_locationAddress != null && Utils.requiresLocationData(message)) {
        messageWithOptionalLocation = '$message\nLocation: $_locationAddress';
      }

      _udpService.sendUdpMessage(
        messageWithOptionalLocation,
        topics[_selectedIndex],
        '10.0.0.122', // Server IP address
        8765, // Server port
      );

      _scrollToBottom();
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _transcription = val.recognizedWords;
            _controller.text = _transcription;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _sendMessage(_transcription);
      _controller.clear();
    }
  }

  _addTopic(String topic) {
    setState(() {
      if (!topics.contains(topic)) {
        topics.add(topic);
        _chatHistories[topic] = [];
      }
    });
  }

  @override
  void dispose() {
    _udpService.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _speech.stop();
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
              controller: _controller,
              onMicPressed: _startListening,
              isListening: _isListening,
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
  final TextEditingController controller;
  final VoidCallback onMicPressed;
  final bool isListening;

  ChatView({
    required this.chatHistory,
    required this.onSendMessage,
    required this.isGettingLocation,
    required this.scrollController,
    required this.controller,
    required this.onMicPressed,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
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
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(isListening ? Icons.mic_off : Icons.mic),
                onPressed: onMicPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
