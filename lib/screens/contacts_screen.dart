import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/outbox_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  final String myUsername;
  const ContactsScreen({super.key, required this.myUsername});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<String> contacts = [];
  List<String> filtered = [];
  Map<String, String> notes = {};
  Map<String, String> sounds = {};
  final TextEditingController _searchController = TextEditingController();

  static const Map<String, String> soundPresets = {
    'default': 'Обычный',
    'soft': 'Тихий',
    'alert': 'Громкий',
    'none': 'Без звука',
  };

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('contacts') ?? [];
    final notesRaw = prefs.getString('contact_notes');
    final soundsRaw = prefs.getString('contact_sounds');

    setState(() {
      contacts = raw;
      filtered = raw;
      if (notesRaw != null) {
        notes = Map<String, String>.from(jsonDecode(notesRaw));
      }
      if (soundsRaw != null) {
        sounds = Map<String, String>.from(jsonDecode(soundsRaw));
      }
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_notes', jsonEncode(notes));
  }

  Future<void> _saveSounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_sounds', jsonEncode(sounds));
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? contacts
          : contacts.where((c) {
              final note = (notes[c] ?? '').toLowerCase();
              return c.contains(q) || note.contains(q);
            }).toList();
    });
  }

  Future<void> _remove(String name) async {
    final prefs = await SharedPreferences.getInstance();
    contacts.remove(name);
    notes.remove(name);
    sounds.remove(name);
    await prefs.setStringList('contacts', contacts);
    await _saveNotes();
    await _saveSounds();
    _filter();
  }

  void _writeTo(String name) {
    final roomCode = OutboxService.dialogIdFor(widget.myUsername, name);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomCode: roomCode,
          username: widget.myUsername,
        ),
      ),
    );
  }

  void _editNote(String name) {
    final controller = TextEditingController(text: notes[name] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Заметка: @$name', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Заметка',
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              notes[name] = controller.text.trim();
              await _saveNotes();
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _pickSound(String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: soundPresets.entries.map((e) {
            final selected = (sounds[name] ?? 'default') == e.key;
            return ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: Colors.white70,
              ),
              title: Text(e.value, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                sounds[name] = e.key;
                await _saveSounds();
                if (mounted) setState(() {});
                if (e.key != 'none') {
                  SystemSound.play(SystemSoundType.click);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Пока нет контактов', style: TextStyle(color: Colors.white38)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final name = filtered[index];
                      final note = notes[name] ?? '';
                      final sound = sounds[name] ?? 'default';

                      return Dismissible(
                        key: Key('contact_$name'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(name),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white12,
                            child: Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('@$name', style: const TextStyle(color: Colors.white)),
                          subtitle: note.isEmpty
                              ? null
                              : Text(note, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: soundPresets[sound],
                                icon: Icon(
                                  sound == 'none' ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                onPressed: () => _pickSound(name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.note_alt_outlined, color: Colors.white54, size: 20),
                                onPressed: () => _editNote(name),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                                onPressed: () => _writeTo(name),
                              ),
                            ],
                          ),
                          onTap: () => _writeTo(name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}