import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import 'outbox_service.dart';

class DialogSignalService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  DatabaseReference _dialogRef(String dialogId) =>
      _db.child('dialogs').child(dialogId);

  Future<void> setPendingIn({
    required String from,
    required String to,
    required int count,
  }) async {
    final dialogId = OutboxService.dialogIdFor(from, to);
    final ref = _dialogRef(dialogId);

    await ref.child('members').update({
      from: true,
      to: true,
    });

    await ref.child('signal').child(to).set({
      'type': 'pending_in',
      'from': from,
      'count': count,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clearPendingIn({
    required String from,
    required String to,
  }) async {
    final dialogId = OutboxService.dialogIdFor(from, to);
    await _dialogRef(dialogId).child('signal').child(to).remove();
  }

  Future<void> requestPull({
    required String myUsername,
    required String otherUser,
  }) async {
    final dialogId = OutboxService.dialogIdFor(myUsername, otherUser);
    await _dialogRef(dialogId).child('pull').child(myUsername).set({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'from': myUsername,
    });
  }

  Future<void> clearPull({
    required String myUsername,
    required String otherUser,
  }) async {
    final dialogId = OutboxService.dialogIdFor(myUsername, otherUser);
    await _dialogRef(dialogId).child('pull').child(myUsername).remove();
  }

  Future<void> setComeOnline({
    required String from,
    required String to,
  }) async {
    final dialogId = OutboxService.dialogIdFor(from, to);
    final ref = _dialogRef(dialogId);

    await ref.child('members').update({
      from: true,
      to: true,
    });

    await ref.child('signal').child(to).set({
      'type': 'come_online',
      'from': from,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clearComeOnline({
    required String forUser,
    required String otherUser,
  }) async {
    final dialogId = OutboxService.dialogIdFor(forUser, otherUser);
    final snap = await _dialogRef(dialogId).child('signal').child(forUser).get();
    if (snap.value is Map) {
      final type = (snap.value as Map)['type']?.toString();
      if (type == 'come_online') {
        await _dialogRef(dialogId).child('signal').child(forUser).remove();
      }
    }
  }

  /// Подтверждение: получатель забрал сообщения
  Future<void> setDeliveredAck({
    required String from,
    required String to,
  }) async {
    final dialogId = OutboxService.dialogIdFor(from, to);
    await _dialogRef(dialogId).child('signal').child(to).set({
      'type': 'delivered_ack',
      'from': from,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  StreamSubscription listenMySignals({
    required String myUsername,
    required void Function(String dialogId, Map data) onSignal,
  }) {
    return _db.child('dialogs').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final root = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      root.forEach((dialogId, dialogValue) {
        if (dialogValue is! Map) return;
        final dialog = Map<dynamic, dynamic>.from(dialogValue);
        final signalNode = dialog['signal'];
        if (signalNode is! Map) return;

        final signals = Map<dynamic, dynamic>.from(signalNode);
        final mySignal = signals[myUsername];
        if (mySignal is Map) {
          onSignal(dialogId.toString(), Map<String, dynamic>.from(mySignal));
        }
      });
    });
  }

  StreamSubscription listenPull({
    required String dialogId,
    required String otherUser,
    required void Function(Map data) onPull,
  }) {
    return _dialogRef(dialogId).child('pull').child(otherUser).onValue.listen((event) {
      if (event.snapshot.value == null) return;
      if (event.snapshot.value is Map) {
        onPull(Map<String, dynamic>.from(event.snapshot.value as Map));
      }
    });
  }

  Future<void> publishDelivery({
    required String dialogId,
    required String toUser,
    required List<Map<String, dynamic>> messages,
  }) async {
    final ref = _dialogRef(dialogId).child('delivery').child(toUser);
    await ref.set({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'messages': messages,
    });
  }

  StreamSubscription listenDelivery({
    required String dialogId,
    required String myUsername,
    required void Function(List<Map<String, dynamic>> messages) onMessages,
  }) {
    return _dialogRef(dialogId)
        .child('delivery')
        .child(myUsername)
        .onValue
        .listen((event) async {
      if (event.snapshot.value == null) return;
      if (event.snapshot.value is! Map) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final raw = data['messages'];
      if (raw is List) {
        final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        onMessages(list);
      }

      await event.snapshot.ref.remove();
    });
  }

  Future<void> setDialogPresence({
    required String dialogId,
    required String username,
    required bool online,
  }) async {
    final ref = _dialogRef(dialogId).child('presence').child(username);
    if (online) {
      await ref.set(true);
      ref.onDisconnect().remove();
    } else {
      await ref.remove();
    }
  }

  StreamSubscription listenDialogPresence({
    required String dialogId,
    required String otherUser,
    required void Function(bool online) onChanged,
  }) {
    return _dialogRef(dialogId).child('presence').child(otherUser).onValue.listen((event) {
      onChanged(event.snapshot.value == true);
    });
  }
}