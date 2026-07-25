import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDUU45D-9Grs6uhD3FaqnEupc-j_lScp40",
      authDomain: "dyhanie-19961.firebaseapp.com",
      databaseURL: "https://dyhanie-19961-default-rtdb.firebaseio.com",
      projectId: "dyhanie-19961",
      storageBucket: "dyhanie-19961.firebasestorage.app",
      messagingSenderId: "220279979423",
      appId: "1:220279979423:web:1ce259ea4fbd6f372511aa",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Дыхание',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

// ===================== СТАРТОВЫЙ ЭКРАН =====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  String _generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Дыхание',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Эфемерный мессенджер',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final code = _generateRoomCode();
                    final userId = _generateUserId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          roomCode: code,
                          userId: userId,
                          isCreator: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('Создать комнату', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                    );
                  },
                  child: const Text('Войти по коду', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== ВХОД ПО КОДУ =====================
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();

  String _generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Вход в комнату', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 10),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'КОД',
                hintStyle: TextStyle(color: Colors.white30, letterSpacing: 10),
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final code = _codeController.text.trim().toUpperCase();
                  if (code.length == 6) {
                    final userId = _generateUserId();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          roomCode: code,
                          userId: userId,
                          isCreator: false,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Войти', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== ЧАТ =====================
class ChatScreen extends StatefulWidget {
  final String roomCode;
  final String userId;
  final bool isCreator;

  const ChatScreen({
    super.key,
    required this.roomCode,
    required this.userId,
    required this.isCreator,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  List<Map<dynamic, dynamic>> messages = [];
  StreamSubscription? _messagesSubscription;
  int selectedTime = 30; // по умолчанию 30 секунд

  final List<int> timeOptions = [5, 10, 15, 30, 60, 120, 300, 600]; // до 10 минут

  @override
  void initState() {
    super.initState();
    _listenMessages();
  }

  void _listenMessages() {
    _messagesSubscription = _db
        .child('rooms')
        .child(widget.roomCode)
        .child('messages')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map((e) {
          final msg = Map<dynamic, dynamic>.from(e.value as Map);
          msg['key'] = e.key;
          return msg;
        }).toList();

        list.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

        setState(() {
          messages = list;
        });

        // Автоудаление просроченных сообщений
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var msg in list) {
          final created = msg['timestamp'] as int;
          final ttl = (msg['ttl'] as int) * 1000;
          if (now - created > ttl) {
            _db.child('rooms').child(widget.roomCode).child('messages').child(msg['key']).remove();
          }
        }
      } else {
        setState(() {
          messages = [];
        });
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final newMessageRef = _db.child('rooms').child(widget.roomCode).child('messages').push();

    newMessageRef.set({
      'text': text,
      'userId': widget.userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': selectedTime,
    });

    _controller.clear();
    HapticFeedback.lightImpact();
  }

  void _openTimeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Время жизни сообщения', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: timeOptions.map((sec) {
                  String label;
                  if (sec < 60) {
                    label = '$sec сек';
                  } else {
                    label = '${sec ~/ 60} мин';
                  }
                  return ChoiceChip(
                    label: Text(label),
                    selected: selectedTime == sec,
                    selectedColor: Colors.white24,
                    labelStyle: TextStyle(
                      color: selectedTime == sec ? Colors.white : Colors.white70,
                    ),
                    onSelected: (_) {
                      setState(() => selectedTime = sec);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          children: [
            const Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 18)),
            Text(
              'Код: ${widget.roomCode}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer, color: Colors.white70),
            onPressed: _openTimeSelector,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['userId'] == widget.userId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
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
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _sendMessage,
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
