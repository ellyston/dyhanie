import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'screens/vpn_screen.dart';

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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (username == null || username.isEmpty) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreateProfileScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w300))),
    );
  }
}

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  Uint8List? _avatarBytes;
  String? _error;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    final valid = RegExp(r'^[a-z0-9]+$').hasMatch(username);
    if (username.isEmpty) {
      setState(() => _error = 'Введите имя пользователя');
      return;
    }
    if (!valid) {
      setState(() => _error = 'Только маленькие английские буквы и цифры');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Минимум 3 символа');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('Создай профиль', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300)),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white12,
                  backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 32) : null,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Нажми, чтобы выбрать аватар', style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]'))],
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: const TextStyle(color: Colors.white30),
                  errorText: _error,
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _saveProfile,
                  child: const Text('Продолжить', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => username = prefs.getString('username') ?? '');
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VpnScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('@$username', style: const TextStyle(color: Colors.white54, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () {
                    final code = _generateRoomCode();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomCode: code, username: username)));
                  },
                  child: const Text('Создать комнату', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JoinRoomScreen(username: username))),
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

class JoinRoomScreen extends StatefulWidget {
  final String username;
  const JoinRoomScreen({super.key, required this.username});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Вход в комнату', style: TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
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
              decoration: const InputDecoration(hintText: 'КОД', hintStyle: TextStyle(color: Colors.white30, letterSpacing: 10), counterText: '', enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white))),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  final code = _codeController.text.trim().toUpperCase();
                  if (code.length == 6) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomCode: code, username: widget.username)));
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

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  const ChatScreen({super.key, required this.roomCode, required this.username});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> messages = [];
  final Map<String, Timer> _timers = {};
  final Map<String, double> _opacities = {};

  StreamSubscription? _messagesSubscription;
  int selectedTime = 30;
  double messageFontSize = 16.0;
  Uint8List? backgroundBytes;

  final List<int> timeOptions = [5, 10, 15, 30, 60, 120, 300, 600];

  @override
  void initState() {
    super.initState();
    _listenMessages();
  }

  void _listenMessages() {
    _messagesSubscription = _db.child('rooms').child(widget.roomCode).child('messages').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = <Map<String, dynamic>>[];
        data.forEach((key, value) {
          final msg = Map<String, dynamic>.from(value as Map);
          msg['key'] = key.toString();
          list.add(msg);
        });
        list.sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
        for (var msg in list) {
          final key = msg['key'] as String;
          if (!_timers.containsKey(key)) {
            _startMessageTimer(msg);
          }
        }
        setState(() => messages = list);
      } else {
        setState(() => messages = []);
      }
    });
  }

  void _startMessageTimer(Map<String, dynamic> msg) {
    final key = msg['key'] as String;
    final created = msg['timestamp'] as int;
    final ttlSeconds = msg['ttl'] as int? ?? 30;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - created) ~/ 1000;
    final remaining = ttlSeconds - elapsed;

    if (remaining <= 0) {
      _removeMessage(key);
      return;
    }

    _opacities[key] = 1.0;
    final fadeStart = remaining > 2 ? remaining - 1 : remaining;

    _timers[key] = Timer(Duration(seconds: fadeStart), () {
      if (!mounted) return;
      setState(() => _opacities[key] = 0.0);
      Future.delayed(const Duration(milliseconds: 800), () => _removeMessage(key));
    });
  }

  void _removeMessage(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _opacities.remove(key);
    _db.child('rooms').child(widget.roomCode).child('messages').child(key).remove();
    if (mounted) {
      setState(() => messages.removeWhere((m) => m['key'] == key));
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _db.child('rooms').child(widget.roomCode).child('messages').push().set({
      'text': text,
      'username': widget.username,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': selectedTime,
    });
    _controller.clear();
    HapticFeedback.lightImpact();
  }

  Future<void> _pickBackground() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => backgroundBytes = bytes);
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Настройки чата', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 24),
                  const Align(alignment: Alignment.centerLeft, child: Text('Размер шрифта сообщений', style: TextStyle(color: Colors.white70))),
                  Slider(
                    value: messageFontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: messageFontSize.round().toString(),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (value) {
                      setModalState(() => messageFontSize = value);
                      setState(() => messageFontSize = value);
                    },
                  ),
                  Text('${messageFontSize.round()} px', style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        Navigator.pop(context);
                        _pickBackground();
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Выбрать фон чата'),
                    ),
                  ),
                  if (backgroundBytes != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          setState(() => backgroundBytes = null);
                          Navigator.pop(context);
                        },
                        child: const Text('Убрать фон', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openTimeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  final label = sec < 60 ? '$sec сек' : '${sec ~/ 60} мин';
                  return ChoiceChip(
                    label: Text(label),
                    selected: selectedTime == sec,
                    selectedColor: Colors.white24,
                    labelStyle: TextStyle(color: selectedTime == sec ? Colors.white : Colors.white70),
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
    for (var timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: backgroundBytes != null
              ? DecorationImage(
                  image: MemoryImage(backgroundBytes!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.55), BlendMode.darken),
                )
              : null,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.6),
            title: Column(
              children: [
                const Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text('Код: ${widget.roomCode}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.timer, color: Colors.white70), onPressed: _openTimeSelector),
              IconButton(icon: const Icon(Icons.tune, color: Colors.white70), onPressed: _openSettings),
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
                    final key = msg['key'] as String;
                    final isMe = msg['username'] == widget.username;
                    final opacity = _opacities[key] ?? 1.0;
                    return AnimatedOpacity(
                      opacity: opacity,
                      duration: const Duration(milliseconds: 700),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) Text('@${msg['username']}', style: TextStyle(color: Colors.white54, fontSize: messageFontSize - 3)),
                              Text(msg['text'] ?? '', style: TextStyle(color: Colors.white, fontSize: messageFontSize)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 20),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), border: const Border(top: BorderSide(color: Colors.white10))),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Сообщение...', hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: Colors.white)),
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
