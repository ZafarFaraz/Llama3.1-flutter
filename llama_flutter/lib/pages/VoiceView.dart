import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../Services/location.dart';
import '../Services/udp.dart';
import '../Services/utils.dart';

class VoiceView extends StatefulWidget {
  final List<String> topics;

  const VoiceView({super.key, required this.topics});

  @override
  _VoiceViewState createState() => _VoiceViewState();
}

class _VoiceViewState extends State<VoiceView> {
  int _selectedIndex = 0;
  final Map<String, List<Map<String, String>>> _chatHistories = {};

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
        _chatHistories[widget.topics[_selectedIndex]]
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
        widget.topics[_selectedIndex],
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
                icon: Icon(Icons.mic), // Voice topic icon
                label: Text(topic),
              );
            }).toList(),
          ),
          Expanded(
            child: VoiceChat(
              chatHistory: _chatHistories[widget.topics[_selectedIndex]]!,
              onSendMessage: _sendMessage,
              isGettingLocation: _locationAddress == null,
              scrollController: _scrollController,
              controller: _controller,
              onMicPressed: _startListening,
              isListening: _isListening,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceChat extends StatelessWidget {
  final List<Map<String, String>> chatHistory;
  final Function(String) onSendMessage;
  final bool isGettingLocation;
  final ScrollController scrollController;
  final TextEditingController controller;
  final VoidCallback onMicPressed;
  final bool isListening;
  final bool isDarkMode;

  VoiceChat({
    required this.chatHistory,
    required this.onSendMessage,
    required this.isGettingLocation,
    required this.scrollController,
    required this.controller,
    required this.onMicPressed,
    required this.isListening,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(20), // Added margin for shadow space
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.purpleAccent.withAlpha(200)
                : Colors.purpleAccent.withAlpha(250),
            blurRadius: 25.0,
            spreadRadius: 10.0,
            offset: const Offset(0.0, 0.0), // Centered shadow for even spread
          ),
        ],
        color: isDarkMode ? Colors.black : Colors.grey,
      ),
      child: Padding(
        padding: EdgeInsets.all(16), // Added padding inside the container
        child: Column(
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
                      margin: EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.purple : Colors.grey[800],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message['content'] ?? '',
                        style: TextStyle(color: Colors.white),
                      ),
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
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: IconButton(
                      icon: Icon(isListening ? Icons.mic_off : Icons.mic),
                      onPressed: onMicPressed,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
