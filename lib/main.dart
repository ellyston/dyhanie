import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Дыхание',
      home: ChatScreen(),
    );
  }
}

enum MessageType { text, audio, video }

class ChatMessage {
  final String text;
  final bool isMe;
  final MessageType type;
  int secondsLeft;
  bool isDisappearing = false;
  Timer? timer;

  ChatMessage(
    this.text, {
    required this.isMe,
    this.type = MessageType.text,
    this.secondsLeft = 5,
  });
}

class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ChatMessage> messages = [];

  int selectedTime = 5;
  double fontSize = 16;
  Color myBubbleColor = Colors.white.withValues(alpha: 0.15);
  Color otherBubbleColor = Colors.white.withValues(alpha: 0.08);
  String? backgroundImageUrl;
  Color backgroundColor = const Color(0xFF0A0A0A);

  void _vibrate() {
    HapticFeedback.lightImpact();
  }

  void sendMessage({bool isMe = true, MessageType type = MessageType.text}) {
    String text = '';

    if (type == MessageType.text) {
      text = isMe ? _controller.text.trim() : 'Привет, это входящее сообщение';
      if (text.isEmpty) return;
    } else if (type == MessageType.audio) {
      text = isMe ? 'Голосовое сообщение' : 'Входящее голосовое';
    } else if (type == MessageType.video) {
      text = isMe ? 'Видео-кружок' : 'Входящий видео-кружок';
    }

    final newMessage = ChatMessage(
      text,
      isMe: isMe,
      type: type,
      secondsLeft: selectedTime,
    );

    setState(() {
      messages.add(newMessage);
      if (isMe && type == MessageType.text) _controller.clear();
    });

    _vibrate();

    newMessage.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        newMessage.secondsLeft--;
      });

      if (newMessage.secondsLeft <= 0) {
        timer.cancel();
        _startDisappear(newMessage);
      }
    });
  }

  void _startDisappear(ChatMessage message) {
    setState(() {
      message.isDisappearing = true;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          messages.remove(message);
        });
      }
    });
  }

  void _deleteMessage(ChatMessage message) {
    message.timer?.cancel();
    setState(() {
      messages.remove(message);
    });
  }

  Widget _buildMessageContent(ChatMessage message) {
    if (message.type == MessageType.audio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Голосовое', style: TextStyle(color: Colors.white, fontSize: fontSize - 1)),
              Text('0:${message.secondsLeft + 3}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      );
    }

    if (message.type == MessageType.video) {
      return Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black26,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 6),
          Text('Видео-кружок', style: TextStyle(color: Colors.white70, fontSize: fontSize - 2)),
        ],
      );
    }

    return Text(
      message.text,
      style: TextStyle(color: Colors.white, fontSize: fontSize, height: 1.3),
    );
  }

  @override
  void dispose() {
    for (var msg in messages) {
      msg.timer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        title: const Text(
          'Дыхание',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            fontSize: 22,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.horizontal,
                  onDismissed: (_) => _deleteMessage(message),
                  child: AnimatedOpacity(
                    opacity: message.isDisappearing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 600),
                    child: Align(
                      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: message.isMe ? myBubbleColor : otherBubbleColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: _buildMessageContent(message)),
                            const SizedBox(width: 8),
                            Text('${message.secondsLeft}', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 20),
            color: Colors.black54,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: () => sendMessage(),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
