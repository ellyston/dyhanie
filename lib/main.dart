import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
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
    await Future.delayed(const Duration(milliseconds: 500));
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
    if (username.isEmpty) {
      setState(() => _error = 'Введите имя пользователя');
      return;
    }
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(username)) {
      setState(() => _error = 'Только маленькие английские буквы и цифры');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Минимум 3 символа');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    if (_avatarBytes != null) {
      await prefs.setString('avatar', base64Encode(_avatarBytes!));
    }
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
  Uint8List? avatarBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username') ?? '';
    final avatarStr = prefs.getString('avatar');
    setState(() {
      username = name;
      avatarBytes = avatarStr != null ? base64Decode(avatarStr) : null;
    });
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
            icon: const Icon(Icons.contacts_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ContactsScreen(myUsername: username)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Colors.white70),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VpnScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(username: username, avatarBytes: avatarBytes)),
                  );
                  _loadProfile();
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white12,
                      backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : null,
                      child: avatarBytes == null
                          ? Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 28))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text('@$username', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const Text('Нажми, чтобы открыть профиль', style: TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              const Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300, letterSpacing: 3)),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    final code = _generateRoomCode();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomCode: code, username: username)));
                  },
                  child: const Text('Создать комнату', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => JoinRoomScreen(username: username)));
                  },
                  child: const Text('Войти по коду', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final String username;
  final Uint8List? avatarBytes;
  const ProfileScreen({super.key, required this.username, this.avatarBytes});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _usernameController;
  Uint8List? _avatarBytes;
  final ImagePicker _picker = ImagePicker();
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _avatarBytes = widget.avatarBytes;
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty || !RegExp(r'^[a-z0-9]+$').hasMatch(username) || username.length < 3) {
      setState(() => _error = 'Некорректный username');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    if (_avatarBytes != null) {
      await prefs.setString('avatar', base64Encode(_avatarBytes!));
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Профиль', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white12,
                backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 32) : null,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Сменить аватар', style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 40),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]'))],
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: Colors.white54),
                errorText: _error,
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _save,
                child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  final String myUsername;
  const ContactsScreen({super.key, required this.myUsername});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<String> contacts = [];
  List<String> filtered = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filter);
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('contacts') ?? [];
    setState(() {
      contacts = raw;
      filtered = raw;
    });
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty ? contacts : contacts.where((c) => c.contains(q)).toList();
    });
  }

  Future<void> _removeContact(String name) async {
    final prefs = await SharedPreferences.getInstance();
    contacts.remove(name);
    await prefs.setStringList('contacts', contacts);
    _filter();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _writeTo(String name) {
    final code = _generateRoomCode();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Чат с @$name', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Отправь этот код собеседнику:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            SelectableText(code, style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.w300)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код скопирован')));
            },
            child: const Text('Копировать', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomCode: code, username: widget.myUsername)));
            },
            child: const Text('Открыть чат', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Контакты', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 52, color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        Text(contacts.isEmpty ? 'Пока нет контактов' : 'Ничего не найдено', style: const TextStyle(color: Colors.white38, fontSize: 16)),
                        if (contacts.isEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Они появятся после общения', style: TextStyle(color: Colors.white24, fontSize: 13)),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                    itemBuilder: (context, index) {
                      final name = filtered[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.white12,
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                        title: Text('@$name', style: const TextStyle(color: Colors.white, fontSize: 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 22),
                              onPressed: () => _writeTo(name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white30, size: 18),
                              onPressed: () => _removeContact(name),
                            ),
                          ],
                        ),
                        onTap: () => _writeTo(name),
                      );
                    },
                  ),
          ),
        ],
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
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ChatScreen(roomCode: code, username: widget.username)),
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

class ChatScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  const ChatScreen({super.key, required this.roomCode, required this.username});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  final Map<String, Timer> _timers = {};
  final Map<String, int> _remainingSeconds = {};
  final Set<String> _knownMessageKeys = {};

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _saveSubscription;
  StreamSubscription? _presenceSubscription;
  StreamSubscription? _callSubscription;

  int selectedTime = 30;
  double messageFontSize = 16.0;
  Uint8List? backgroundBytes;
  String? typingUser;
  bool isSavedChat = false;
  bool saveRequestIncoming = false;
  String? saveRequestedBy;
  String? otherUser;
  bool otherOnline = false;
  bool _incomingDialogShown = false;

  final List<int> timeOptions = [5, 10, 15, 30, 60, 120, 300, 600];
  Timer? _typingThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _listenMessages();
    _listenTyping();
    _listenSaveStatus();
    _listenPresence();
    _listenCalls();
    _controller.addListener(_onTyping);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnline(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOnline(false);
    }
  }

  void _setOnline(bool online) {
    final ref = _db.child('rooms').child(widget.roomCode).child('presence').child(widget.username);
    if (online) {
      ref.set(true);
      ref.onDisconnect().remove();
    } else {
      ref.remove();
    }
  }

  void _listenPresence() {
    _presenceSubscription = _db.child('rooms').child(widget.roomCode).child('presence').onValue.listen((event) async {
      if (event.snapshot.value == null) {
        setState(() {
          otherUser = null;
          otherOnline = false;
        });
        return;
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      String? other;
      bool online = false;
      data.forEach((key, value) {
        if (key.toString() != widget.username) {
          other = key.toString();
          online = value == true;
        }
      });
      setState(() {
        otherUser = other;
        otherOnline = online;
      });
      if (other != null) {
        final prefs = await SharedPreferences.getInstance();
        final contacts = prefs.getStringList('contacts') ?? [];
        if (!contacts.contains(other)) {
          contacts.add(other!);
          await prefs.setStringList('contacts', contacts);
        }
      }
    });
  }

  void _listenCalls() {
    _callSubscription = _db.child('rooms').child(widget.roomCode).child('call').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final status = data['status']?.toString();
      final to = data['to']?.toString();
      final from = data['from']?.toString();
      if (status == 'ringing' && to == widget.username && from != null && !_incomingDialogShown) {
        _incomingDialogShown = true;
        _showIncomingCall(from);
      }
      if (status == 'ended' || status == 'rejected') {
        _incomingDialogShown = false;
      }
    });
  }

  void _showIncomingCall(String from) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Входящий звонок', style: TextStyle(color: Colors.white)),
          content: Text('@$from звонит вам', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () {
                _db.child('rooms').child(widget.roomCode).child('call').update({'status': 'rejected'});
                _incomingDialogShown = false;
                Navigator.pop(context);
              },
              child: const Text('Отклонить', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () {
                _db.child('rooms').child(widget.roomCode).child('call').update({'status': 'accepted'});
                _incomingDialogShown = false;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      roomCode: widget.roomCode,
                      username: widget.username,
                      otherUser: from,
                      isIncoming: true,
                    ),
                  ),
                );
              },
              child: const Text('Принять', style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        );
      },
    );
  }

  void _onTyping() {
    _typingThrottle?.cancel();
    _db.child('rooms').child(widget.roomCode).child('typing').child(widget.username).set(true);
    _typingThrottle = Timer(const Duration(milliseconds: 1500), () {
      _db.child('rooms').child(widget.roomCode).child('typing').child(widget.username).remove();
    });
  }

  void _listenTyping() {
    _typingSubscription = _db.child('rooms').child(widget.roomCode).child('typing').onValue.listen((event) {
      if (event.snapshot.value == null) {
        setState(() => typingUser = null);
        return;
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      String? other;
      data.forEach((key, value) {
        if (key.toString() != widget.username && value == true) other = key.toString();
      });
      setState(() => typingUser = other);
    });
  }

  void _listenSaveStatus() {
    _saveSubscription = _db.child('rooms').child(widget.roomCode).child('meta').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final saved = data['saved'] == true;
      final requestedBy = data['saveRequestedBy']?.toString();
      setState(() {
        isSavedChat = saved;
        if (requestedBy != null && requestedBy != widget.username && !saved) {
          saveRequestIncoming = true;
          saveRequestedBy = requestedBy;
        } else {
          saveRequestIncoming = false;
          saveRequestedBy = null;
        }
      });
    });
  }

  void _listenMessages() {
    _messagesSubscription = _db.child('rooms').child(widget.roomCode).child('messages').onValue.listen((event) {
      if (event.snapshot.value == null) {
        setState(() => messages = []);
        return;
      }
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
        if (!_knownMessageKeys.contains(key)) {
          _knownMessageKeys.add(key);
          if (msg['username'] != widget.username) {
            HapticFeedback.mediumImpact();
            SystemSound.play(SystemSoundType.click);
          }
          if (!isSavedChat) _startMessageTimer(msg);
        }
      }
      setState(() => messages = list);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _startMessageTimer(Map<String, dynamic> msg) {
    if (isSavedChat) return;
    final key = msg['key'] as String;
    final created = msg['timestamp'] as int;
    final ttlSeconds = msg['ttl'] as int? ?? 30;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - created) ~/ 1000;
    var remaining = ttlSeconds - elapsed;
    if (remaining <= 0) {
      _removeMessage(key);
      return;
    }
    _remainingSeconds[key] = remaining;
    _timers[key]?.cancel();
    _timers[key] = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds[key] = remaining);
      if (remaining <= 0) {
        timer.cancel();
        _removeMessage(key);
      }
    });
  }

  void _removeMessage(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _remainingSeconds.remove(key);
    _db.child('rooms').child(widget.roomCode).child('messages').child(key).remove();
    if (mounted) setState(() => messages.removeWhere((m) => m['key'] == key));
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
    _db.child('rooms').child(widget.roomCode).child('typing').child(widget.username).remove();
    HapticFeedback.lightImpact();
  }

  void _proposeSaveChat() {
    _db.child('rooms').child(widget.roomCode).child('meta').update({
      'saveRequestedBy': widget.username,
      'saved': false,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Запрос на сохранение отправлен')));
  }

  void _acceptSaveChat() {
    _db.child('rooms').child(widget.roomCode).child('meta').update({'saved': true, 'saveRequestedBy': null});
    for (var t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    setState(() => isSavedChat = true);
  }

  void _declineSaveChat() {
    _db.child('rooms').child(widget.roomCode).child('meta').update({'saveRequestedBy': null});
    setState(() => saveRequestIncoming = false);
  }

  Future<void> _pickBackground() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => backgroundBytes = bytes);
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код комнаты скопирован'), duration: Duration(seconds: 1)));
  }

  void _exitRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Выйти из комнаты?', style: TextStyle(color: Colors.white)),
        content: const Text('В призрачном режиме сообщения могут исчезнуть.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              await _db.child('rooms').child(widget.roomCode).child('presence').child(widget.username).remove();
              await _db.child('rooms').child(widget.roomCode).child('typing').child(widget.username).remove();
              final snap = await _db.child('rooms').child(widget.roomCode).child('presence').get();
              if (!isSavedChat && (snap.value == null || (snap.value as Map).isEmpty)) {
                await _db.child('rooms').child(widget.roomCode).remove();
              }
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _startCall() {
    if (otherUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Собеседник не в сети')));
      return;
    }
    _db.child('rooms').child(widget.roomCode).child('call').set({
      'from': widget.username,
      'to': otherUser,
      'status': 'ringing',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          roomCode: widget.roomCode,
          username: widget.username,
          otherUser: otherUser,
          isIncoming: false,
        ),
      ),
    );
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
                  const SizedBox(height: 20),
                  const Align(alignment: Alignment.centerLeft, child: Text('Размер шрифта', style: TextStyle(color: Colors.white70))),
                  Slider(
                    value: messageFontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      setModalState(() => messageFontSize = v);
                      setState(() => messageFontSize = v);
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                      onPressed: () {
                        Navigator.pop(context);
                        _pickBackground();
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Выбрать фон'),
                    ),
                  ),
                  if (!isSavedChat) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                          _proposeSaveChat();
                        },
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Предложить сохранить чат'),
                      ),
                    ),
                  ],
                  if (isSavedChat)
                    const Padding(padding: EdgeInsets.only(top: 12), child: Text('Чат сохранён', style: TextStyle(color: Colors.greenAccent))),
                  const SizedBox(height: 16),
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _saveSubscription?.cancel();
    _presenceSubscription?.cancel();
    _callSubscription?.cancel();
    _typingThrottle?.cancel();
    for (var t in _timers.values) {
      t.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
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
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitRoom),
            title: Column(
              children: [
                const Text('Дыхание', style: TextStyle(color: Colors.white, fontSize: 18)),
                GestureDetector(
                  onTap: _copyRoomCode,
                  child: Text(
                    otherUser != null
                        ? '@$otherUser ${otherOnline ? "• онлайн" : "• оффлайн"}'
                        : 'Код: ${widget.roomCode}  (нажми, чтобы копировать)',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.call, color: Colors.white70), onPressed: _startCall),
              IconButton(icon: const Icon(Icons.timer, color: Colors.white70), onPressed: _openTimeSelector),
              IconButton(icon: const Icon(Icons.tune, color: Colors.white70), onPressed: _openSettings),
            ],
          ),
          body: Column(
            children: [
              if (saveRequestIncoming)
                Container(
                  width: double.infinity,
                  color: Colors.white10,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text('@$saveRequestedBy предлагает сохранить чат', style: const TextStyle(color: Colors.white))),
                      TextButton(onPressed: _declineSaveChat, child: const Text('Нет', style: TextStyle(color: Colors.white54))),
                      TextButton(onPressed: _acceptSaveChat, child: const Text('Да', style: TextStyle(color: Colors.greenAccent))),
                    ],
                  ),
                ),
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.air, size: 48, color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(height: 16),
                            const Text('Пока тихо', style: TextStyle(color: Colors.white38, fontSize: 18)),
                            const SizedBox(height: 8),
                            Text(
                              isSavedChat ? 'Напишите первое сообщение' : 'Сообщения исчезнут после прочтения',
                              style: const TextStyle(color: Colors.white24, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final key = msg['key'] as String;
                          final isMe = msg['username'] == widget.username;
                          final remaining = _remainingSeconds[key];

                          Widget bubble = Align(
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
                                  if (!isMe)
                                    Text('@${msg['username']}', style: TextStyle(color: Colors.white54, fontSize: messageFontSize - 3)),
                                  Text(msg['text'] ?? '', style: TextStyle(color: Colors.white, fontSize: messageFontSize)),
                                  if (!isSavedChat && remaining != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('${remaining}s', style: TextStyle(color: Colors.white38, fontSize: messageFontSize - 4)),
                                    ),
                                ],
                              ),
                            ),
                          );

                          bubble = TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 350),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
                            ),
                            child: bubble,
                          );

                          if (isMe) {
                            return Dismissible(
                              key: Key(key),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _removeMessage(key),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              ),
                              child: bubble,
                            );
                          }
                          return bubble;
                        },
                      ),
              ),
              if (typingUser != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('@$typingUser печатает...', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  border: const Border(top: BorderSide(color: Colors.white10)),
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

class CallScreen extends StatefulWidget {
  final String roomCode;
  final String username;
  final String? otherUser;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.roomCode,
    required this.username,
    this.otherUser,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool muted = false;
  bool speakerOn = true;
  bool cameraOn = false;
  Duration duration = Duration.zero;
  Timer? _timer;
  StreamSubscription? _callSub;
  String statusText = 'Соединение...';

  @override
  void initState() {
    super.initState();
    statusText = widget.isIncoming ? 'Звонок' : 'Вызов...';
    _callSub = _db.child('rooms').child(widget.roomCode).child('call').onValue.listen((event) {
      if (event.snapshot.value == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final status = data['status']?.toString();
      if (status == 'accepted') {
        if (_timer == null) {
          setState(() => statusText = 'Разговор');
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            setState(() => duration += const Duration(seconds: 1));
          });
        }
      }
      if (status == 'rejected' || status == 'ended') {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  String get _timeText {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    _db.child('rooms').child(widget.roomCode).child('call').update({'status': 'ended'});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              widget.otherUser != null ? '@${widget.otherUser}' : 'Ожидание...',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 8),
            Text(statusText == 'Разговор' ? _timeText : statusText, style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const Spacer(),
            CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white12,
              child: Text(
                (widget.otherUser ?? widget.username).substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 48),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundButton(
                    icon: muted ? Icons.mic_off : Icons.mic,
                    label: muted ? 'Микрофон выкл' : 'Микрофон',
                    active: !muted,
                    onTap: () => setState(() => muted = !muted),
                  ),
                  _roundButton(
                    icon: Icons.call_end,
                    label: 'Завершить',
                    color: Colors.redAccent,
                    onTap: _endCall,
                  ),
                  _roundButton(
                    icon: speakerOn ? Icons.volume_up : Icons.volume_off,
                    label: speakerOn ? 'Динамик' : 'Динамик выкл',
                    active: speakerOn,
                    onTap: () => setState(() => speakerOn = !speakerOn),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundButton(
                    icon: cameraOn ? Icons.videocam : Icons.videocam_off,
                    label: cameraOn ? 'Камера' : 'Камера выкл',
                    active: cameraOn,
                    onTap: () => setState(() => cameraOn = !cameraOn),
                  ),
                  _roundButton(
                    icon: Icons.cameraswitch,
                    label: 'Сменить',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool active = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? (active ? Colors.white24 : Colors.white10),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}