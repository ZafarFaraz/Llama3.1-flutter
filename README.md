
# Ollama 3.1 Chat Application

This project is a chat application built using Flutter, leveraging Ollama 3.1 for text-to-speech (TTS) and speech-to-text (STT) capabilities. The application uses WebSockets to communicate with a machine server, enabling real-time chat functionality. The project includes two main interfaces: `UdpChatScreen` for standard text chat and `VoiceScreen` for voice-based communication.

## Features

- **Real-time Chat:** Communicate with the server in real time using WebSockets.
- **Text-to-Speech (TTS):** Converts received text messages to speech for an enhanced user experience.
- **Speech-to-Text (STT):** Allows users to send messages by speaking, which are then converted to text.
- **Modular Design:** The application uses a modular approach with shared functionality abstracted into base classes for easy maintenance and scalability.

## Technologies Used

- **Flutter:** For building the cross-platform mobile application.
- **Ollama 3.1:** For text-to-speech and speech-to-text functionalities.
- **WebSockets:** For real-time communication with the machine server.
- **Dart:** The programming language used for Flutter development.

## Project Structure

```
lib/
│
├── Components/
│   └── audioVisualizer.dart   # Custom widget for audio visualization
│
├── Services/
│   ├── location.dart          # Service for handling location-related tasks
│   ├── udp.dart               # Service for handling UDP communication and TTS
│   ├── utils.dart             # Utility functions
│
├── Views/
│   ├── BaseView.dart          # Abstract base class for shared view functionality
│   ├── ChatView.dart          # Implementation of the chat interface
│   ├── VoiceView.dart         # Implementation of the voice interface
│
└── main.dart                  # Main entry point of the application
```

## Getting Started

### Prerequisites

- **Flutter SDK:** Make sure you have Flutter installed on your machine. Follow the official [installation guide](https://flutter.dev/docs/get-started/install) if you haven't already.
- **Ollama 3.1:** Set up Ollama 3.1 on your machine for TTS and STT functionalities.
- **WebSocket Server:** A machine server configured to communicate via WebSockets.

### Installation

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/ollama-chat-app.git
   cd ollama-chat-app
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Configure the WebSocket server:**

   - Make sure your WebSocket server is running and accessible. Update the server address and port in the application code if necessary.

4. **Run the application:**

   ```bash
   flutter run
   ```

### Usage

- **UdpChatScreen:** Provides a standard text-based chat interface. You can switch between different chat topics and send messages to the server.
- **VoiceScreen:** Allows voice-based communication. Tap to start recording, and your speech will be converted to text and sent as a message. Incoming messages are spoken out loud using TTS.

### Customization

- **WebSocket Server Address:** Update the server address in the `UdpService` class in `udp.dart`.
- **TTS Language and Pitch:** Customize the TTS language and pitch in the `_initializeTts` method in `UdpService`.

## Contributing

Contributions are welcome! If you find any issues or want to add new features, feel free to submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- **Flutter:** For providing a powerful framework for cross-platform development.
- **Ollama 3.1:** For enabling TTS and STT functionalities.
- **WebSocket:** For real-time communication.
