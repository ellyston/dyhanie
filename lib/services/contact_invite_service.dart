import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'dyhanie_api.dart';

class ContactInviteService {
  Future<void> registerUsername(String username) async {
    // регистрация через CreateProfile + DyhanieApi
  }

  Future<bool> usernameExists(String username) async {
    final u = username.toLowerCase().trim();
    if (u.isEmpty) return false;
    try {
      if (!DyhanieApi.instance.isConnected) {
        await DyhanieApi.instance.connect();
      }
      return await DyhanieApi.instance.usernameExists(u);
    } catch (_) {
      return false;
    }
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
    final contacts = prefs.getStringList('contacts') ?? [];
    contacts.remove(u);
    await prefs.setStringList('contacts', contacts);
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

    try {
      if (!DyhanieApi.instance.isConnected) {
        await DyhanieApi.instance.connect();
        await DyhanieApi.instance.sessionBind(from);
      }
      final exists = await DyhanieApi.instance.usernameExists(to);
      if (!exists) return 'Пользователь не найден';
      await DyhanieApi.instance.contactInvite(to);
      return 'ok';
    } catch (e) {
      final s = e.toString();
      if (s.contains('NOT_FOUND')) return 'Пользователь не найден';
      return 'Ошибка: $e';
    }
  }

  Future<void> cancelOutgoing({
    required String fromUsername,
    required String toUsername,
  }) async {
    try {
      await DyhanieApi.instance.contactCancel(toUsername.toLowerCase());
    } catch (_) {}
  }

  Future<void> acceptInvite({
    required String myUsername,
    required String fromUsername,
  }) async {
    final from = fromUsername.toLowerCase();
    if (await isBlocked(from)) {
      await declineInvite(myUsername: myUsername, fromUsername: from);
      return;
    }
    await DyhanieApi.instance.contactAccept(from);
    await addLocalContact(from);
  }

  Future<void> declineInvite({
    required String myUsername,
    required String fromUsername,
  }) async {
    try {
      await DyhanieApi.instance.contactDecline(fromUsername.toLowerCase());
    } catch (_) {}
  }

  /// Список с сервера: incoming / outgoing / badge
  Future<Map<String, dynamic>> fetchInvites() async {
    try {
      return await DyhanieApi.instance.contactInvitesList();
    } catch (_) {
      return {
        'incoming': <Map<String, dynamic>>[],
        'outgoing': <Map<String, dynamic>>[],
        'badge': 0,
      };
    }
  }

  StreamSubscription listenInvites({
    required String myUsername,
    required void Function(List<Map<String, dynamic>> invites) onData,
  }) {
    Future(() async {
      final list = await fetchInvites();
      final incoming = (list['incoming'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      onData(incoming);
    });

    return DyhanieApi.instance.events.listen((m) async {
      final t = m['type']?.toString();
      if (t == 'contact.invite_incoming' ||
          t == 'contact.accepted' ||
          t == 'contact.declined') {
        final list = await fetchInvites();
        final incoming = (list['incoming'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        onData(incoming);
      }
    });
  }

  StreamSubscription listenOutgoing({
    required String myUsername,
    required void Function(List<Map<String, dynamic>> list) onData,
  }) {
    Future(() async {
      final list = await fetchInvites();
      final outgoing = (list['outgoing'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      onData(outgoing);
    });
    return DyhanieApi.instance.events.listen((m) async {
      final t = m['type']?.toString();
      if (t == 'contact.invite_incoming' ||
          t == 'contact.accepted' ||
          t == 'contact.declined') {
        final list = await fetchInvites();
        final outgoing = (list['outgoing'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        onData(outgoing);
      }
    });
  }

  StreamSubscription listenAccepted({
    required String myUsername,
    required void Function(String byUser) onAccepted,
  }) {
    return DyhanieApi.instance.events.listen((m) async {
      if (m['type']?.toString() != 'contact.accepted') return;
      final p = m['payload'];
      if (p is! Map) return;
      final by = p['by']?.toString();
      if (by == null || by.isEmpty) return;
      await addLocalContact(by);
      onAccepted(by);
    });
  }
}