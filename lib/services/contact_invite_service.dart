import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactInviteService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  DatabaseReference _invitesFor(String username) =>
      _db.child('contact_invites').child(username.toLowerCase());

  DatabaseReference _outgoingFor(String username) =>
      _db.child('contact_invites_out').child(username.toLowerCase());

  /// Зарегистрировать ник (вызывать при создании/сохранении профиля)
  Future<void> registerUsername(String username) async {
    final u = username.toLowerCase().trim();
    if (u.isEmpty) return;
    await _db.child('usernames').child(u).set({
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<bool> usernameExists(String username) async {
    final u = username.toLowerCase().trim();
    final snap = await _db.child('usernames').child(u).get();
    return snap.exists;
  }

  Future<List<String>> getLocalContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('contacts') ?? [];
  }

  Future<void> addLocalContact(String contact) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('contacts') ?? [];
    final c = contact.toLowerCase();
    if (!list.contains(c)) {
      list.add(c);
      await prefs.setStringList('contacts', list);
    }
  }

  // —— блок ——
  Future<List<String>> getBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('blocked_users') ?? [];
  }

  Future<void> blockUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList('blocked_users') ?? [];
    final u = username.toLowerCase();
    if (!blocked.contains(u)) {
      blocked.add(u);
      await prefs.setStringList('blocked_users', blocked);
    }
    // убрать из контактов
    final contacts = prefs.getStringList('contacts') ?? [];
    contacts.remove(u);
    await prefs.setStringList('contacts', contacts);

    // отклонить входящее приглашение от него, если есть
    // (myUsername передадим снаружи при необходимости)
  }

  Future<void> unblockUser(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final blocked = prefs.getStringList('blocked_users') ?? [];
    blocked.remove(username.toLowerCase());
    await prefs.setStringList('blocked_users', blocked);
  }

  Future<bool> isBlocked(String username) async {
    final blocked = await getBlocked();
    return blocked.contains(username.toLowerCase());
  }

  /// Результат глобального поиска / приглашения
  Future<String> sendInvite({
    required String fromUsername,
    required String toUsername,
  }) async {
    final from = fromUsername.toLowerCase().trim();
    final to = toUsername.toLowerCase().trim();

    if (from.isEmpty || to.isEmpty) return 'Пустой username';
    if (from == to) return 'Это вы';

    final contacts = await getLocalContacts();
    if (contacts.contains(to)) return 'Уже в контактах';

    if (await isBlocked(to)) return 'Пользователь в чёрном списке';

    final exists = await usernameExists(to);
    if (!exists) return 'Пользователь не найден';

    await _invitesFor(to).child(from).set({
      'from': from,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    // исходящее — чтобы можно было отменить
    await _outgoingFor(from).child(to).set({
      'to': to,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });

    await registerUsername(from);
    return 'ok';
  }

  Future<void> cancelOutgoing({
    required String fromUsername,
    required String toUsername,
  }) async {
    final from = fromUsername.toLowerCase();
    final to = toUsername.toLowerCase();
    await _invitesFor(to).child(from).remove();
    await _outgoingFor(from).child(to).remove();
  }

  Future<void> acceptInvite({
    required String myUsername,
    required String fromUsername,
  }) async {
    final me = myUsername.toLowerCase();
    final from = fromUsername.toLowerCase();

    if (await isBlocked(from)) {
      await declineInvite(myUsername: me, fromUsername: from);
      return;
    }

    await addLocalContact(from);
    await _invitesFor(me).child(from).remove();
    await _outgoingFor(from).child(me).remove();

    await _db.child('contact_accepted').child(from).child(me).set({
      'by': me,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> declineInvite({
    required String myUsername,
    required String fromUsername,
  }) async {
    final me = myUsername.toLowerCase();
    final from = fromUsername.toLowerCase();
    await _invitesFor(me).child(from).remove();
    await _outgoingFor(from).child(me).remove();
  }

  StreamSubscription listenInvites({
    required String myUsername,
    required void Function(List<Map<String, dynamic>> invites) onData,
  }) {
    return _invitesFor(myUsername).onValue.listen((event) {
      if (event.snapshot.value == null) {
        onData([]);
        return;
      }
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];
      map.forEach((key, value) {
        if (value is Map) {
          final m = Map<String, dynamic>.from(value);
          m['from'] = m['from']?.toString() ?? key.toString();
          list.add(m);
        } else {
          list.add({'from': key.toString()});
        }
      });
      onData(list);
    });
  }

  StreamSubscription listenOutgoing({
    required String myUsername,
    required void Function(List<Map<String, dynamic>> list) onData,
  }) {
    return _outgoingFor(myUsername).onValue.listen((event) {
      if (event.snapshot.value == null) {
        onData([]);
        return;
      }
      final map = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = <Map<String, dynamic>>[];
      map.forEach((key, value) {
        if (value is Map) {
          final m = Map<String, dynamic>.from(value);
          m['to'] = m['to']?.toString() ?? key.toString();
          list.add(m);
        } else {
          list.add({'to': key.toString()});
        }
      });
      onData(list);
    });
  }

  StreamSubscription listenAccepted({
    required String myUsername,
    required void Function(String byUser) onAccepted,
  }) {
    return _db
        .child('contact_accepted')
        .child(myUsername.toLowerCase())
        .onChildAdded
        .listen((event) async {
      final by = event.snapshot.key;
      if (by == null) return;
      if (await isBlocked(by)) {
        await event.snapshot.ref.remove();
        return;
      }
      await addLocalContact(by);
      await event.snapshot.ref.remove();
      onAccepted(by);
    });
  }
}