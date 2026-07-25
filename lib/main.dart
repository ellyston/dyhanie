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

  final List<Map<String, dynamic>> backgroundOptions = [
    {'name': 'Чёрный', 'color': Color(0xFF0A0A0A)},
    {'name': 'Тёмно-синий', 'color': Color(0xFF0B1220)},
    {'name': 'Ночной лес', 'url': 'https://images.unsplash.com/photo-1511497584788-876760111969?w=800'},
    {'name': 'Туман', 'url': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800'},
    {'name': 'Звёзды', 'url': 'https://images.unsplash.com/photo-1419242902214-272b3f66ee70?w=800'},
  ];

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

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Настройки', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    const Text('Время исчезновения', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 5, 8, 10, 15].map((sec) {
                        return ChoiceChip(
                          label: Text('$sec сек'),
                          selected: selectedTime == sec,
                          onSelected: (_) {
                            setState(() => selectedTime = sec);
                            setModalState(() {});
                          },
                          selectedColor: Colors.white24,
                          labelStyle: TextStyle(color: selectedTime == sec ? Colors.white : Colors.white70),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text('Размер шрифта', style: TextStyle(color: Colors.white70)),
                    Slider(
                      value: fontSize,
                      min: 14,
                      max: 22,
                      divisions: 8,
                      activeColor: Colors.white,
                      onChanged: (value) {
                        setState(() => fontSize = value);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Фон', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: backgroundOptions.map((option) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (option.containsKey('url')) {
                                backgroundImageUrl = option['url'];
                                backgroundColor = Colors.black;
                              } else {
                                backgroundImageUrl = null;
                                backgroundColor = option['color'];
                              }
                            });
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(option['name'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black26,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
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
      body: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          image: backgroundImageUrl != null
              ? DecorationImage(
                  image: NetworkImage(backgroundImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
                )
              : null,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            title: const Text(
              'Дыхание',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, fontSize: 22, letterSpacing: 1.5),
            ),
            centerTitle: true,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white70),
                onPressed: _openSettings,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  onPressed: () => sendMessage(isMe: false),
                  child: const Text('+ Симулировать входящее', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.horizontal,
                      onDismissed: (_) => _deleteMessage(message),
                      background: Container(color: Colors.transparent),
                      child: AnimatedOpacity(
                        opacity: message.isDisappearing ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 600),
                        child: AnimatedSlide(
                          offset: message.isDisappearing ? const Offset(0, -0.25) : Offset.zero,
                          duration: const Duration(milliseconds: 600),
                          child: Align(
                            alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: message.isMe ? myBubbleColor : otherBubbleColor,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(message.isMe ? 18 : 4),
                                  bottomRight: Radius.circular(message.isMe ? 4 : 18),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Flexible(child: _buildMessageContent(message)),
                                  const SizedBox(width: 8),
                                  Text('${message.secondsLeft}', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
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
                          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => sendMessage(type: MessageType.audio),
                          icon: const Icon(Icons.mic, color: Colors.white70, size: 20),
                          label: const Text('Аудио', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                        TextButton.icon(
                          onPressed: () => sendMessage(type: MessageType.video),
                          icon: const Icon(Icons.videocam, color: Colors.white70, size: 20),
                          label: const Text('Кружок', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
