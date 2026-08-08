import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dialog_signal_service.dart';
import '../services/outbox_service.dart';

class DirectChatScreen extends StatefulWidget {
  final String myUsername;
  final String otherUser;

  const DirectChatScreen({
    super.key,
    required this.myUsername,
    required this.otherUser,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _controller = TextEditingController();
  final _outbox = OutboxService();
  final _signals = DialogSignalService();
  final _scroll = ScrollController();

  late final String dialogId;

  final List<Map<String, dynamic>> messages = [];

  bool otherOnline = false;
  String statusLine = '';
  bool sending = false;

  StreamSubscription? _presenceSub;
  StreamSubscription? _pullSub;
  StreamSubscription? _deliverySub;
  StreamSubscription? _mySignalSub;

  @override
  void initState() {
    super.initState();
    dialogId = OutboxService.dialogIdFor(widget.myUsername, widget.otherUser);
    _join();
  }

  Future<void> _join() async {
    await _signals.setDialogPresence(
      dialogId: dialogId,
      username: widget.myUsername,
      online: true,
    );

    _presenceSub = _signals.listenDialogPresence(
      dialogId: dialogId,
      otherUser: widget.otherUser,
      onChanged: (online) {
        if (!mounted) return;
        setState(() {
          otherOnline = online;
          if (statusLine != 'прочитано' && !statusLine.contains('доставлено')) {
            statusLine = online ? 'онлайн' : 'оффлайн';
          }
        });
        if (online) {
          _requestPullOrComeOnline();
          _flushOutboxIfNeeded();
        }
      },
    );

    _deliverySub = _signals.listenDelivery(
      dialogId: dialogId,
      myUsername: widget.myUsername,
      onMessages: (list) async {
        if (!mounted) return;
        setState(() {
          for (final m in list) {
            messages.add({
              ...m,
              'username': m['from'] ?? widget.otherUser,
              'pending': false,
              'delivered': true,
            });
          }
        });
        _scrollEnd();
        HapticFeedback.mediumImpact();

        // Подтверждение отправителю
        await _signals.setDeliveredAck(
          from: widget.myUsername,
          to: widget.otherUser,
        );
      },
    );

    _pullSub = _signals.listenPull(
      dialogId: dialogId,
      otherUser: widget.otherUser,
      onPull: (_) => _flushOutboxIfNeeded(),
    );



    await _requestPullOrComeOnline();
    await _refreshPendingSignal();
    await _flushOutboxIfNeeded();
  }

  Future<void> _requestPullOrComeOnline() async {
    await _signals.requestPull(
      myUsername: widget.myUsername,
      otherUser: widget.otherUser,
    );

    if (!otherOnline) {
      await _signals.setComeOnline(
        from: widget.myUsername,
        to: widget.otherUser,
      );
      if (mounted) {
        setState(() => statusLine = 'оффлайн · просим зайти в чат');
      }
    } else {
      await _signals.clearComeOnline(
        forUser: widget.otherUser,
        otherUser: widget.myUsername,
      );
    }
  }

  Future<void> _refreshPendingSignal() async {
    final pending = await _outbox.pendingForDialog(
      dialogId: dialogId,
      myUsername: widget.myUsername,
    );
    if (pending.isEmpty) {
      await _signals.clearPendingIn(
        from: widget.myUsername,
        to: widget.otherUser,
      );
    } else {
      await _signals.setPendingIn(
        from: widget.myUsername,
        to: widget.otherUser,
        count: pending.length,
      );
    }
  }

  Future<void> _flushOutboxIfNeeded() async {
    final pending = await _outbox.pendingForDialog(
      dialogId: dialogId,
      myUsername: widget.myUsername,
    );
    if (pending.isEmpty) return;

    final payload = pending.map((m) => m.toJson()).toList();

    await _signals.publishDelivery(
      dialogId: dialogId,
      toUser: widget.otherUser,
      messages: payload,
    );

    await _outbox.removeByIds(pending.map((e) => e.id).toList());
    await _signals.clearPendingIn(
      from: widget.myUsername,
      to: widget.otherUser,
    );
    await _signals.clearComeOnline(
      forUser: widget.myUsername,
      otherUser: widget.otherUser,
    );

    if (mounted) {
      setState(() {
        for (final m in messages) {
          if (m['username'] == widget.myUsername) {
            m['pending'] = false;
            m['delivered'] = true;
          }
        }
        statusLine = 'доставлено';
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || sending) return;

    setState(() => sending = true);

    try {
      final msg = await _outbox.add(
        from: widget.myUsername,
        to: widget.otherUser,
        text: text,
      );

      setState(() {
        messages.add({
          'id': msg.id,
          'text': msg.text,
          'username': widget.myUsername,
          'timestamp': msg.timestamp,
          'pending': true,
          'delivered': false,
        });
      });
      _controller.clear();
      _scrollEnd();

      final count = await _outbox.countTo(widget.myUsername, widget.otherUser);
      await _signals.setPendingIn(
        from: widget.myUsername,
        to: widget.otherUser,
        count: count,
      );

      if (otherOnline) {
        await _flushOutboxIfNeeded();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _leave() async {
    await _signals.setDialogPresence(
      dialogId: dialogId,
      username: widget.myUsername,
      online: false,
    );
    await _signals.clearPull(
      myUsername: widget.myUsername,
      otherUser: widget.otherUser,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _pullSub?.cancel();
    _deliverySub?.cancel();
    _mySignalSub?.cancel();
    _signals.setDialogPresence(
      dialogId: dialogId,
      username: widget.myUsername,
      online: false,
    );
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final scheme = Theme.of(context).colorScheme;
    final onSurf = scheme.onSurface;

    return Scaffold(
      backgroundColor: bg, // было Colors.black
      appBar: AppBar(
        backgroundColor: bg, // было Colors.black
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurf), // было Colors.white
          onPressed: _leave,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${widget.otherUser}',
              style: TextStyle(color: onSurf, fontSize: 18), // было Colors.white
            ),
            Text(
              statusLine.isEmpty
                  ? (otherOnline ? 'онлайн' : 'оффлайн')
                  : statusLine,
              style: TextStyle(
                color: onSurf.withValues(alpha: 0.55), // было Colors.white54
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: onSurf.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              otherOnline
                  ? 'Собеседник в сети — доставка возможна'
                  : 'Собеседник оффлайн — текст у вас, ему уйдёт сигнал «зайди в чат»',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurf.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Напишите сообщение.\nОно будет у собеседника после открытия чата.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onSurf.withValues(alpha: 0.38),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg['username'] == widget.myUsername;
                      final pending = msg['pending'] == true;
                      final delivered = msg['delivered'] == true;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? onSurf.withValues(alpha: 0.16)
                                : onSurf.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text']?.toString() ?? '',
                                style: TextStyle(color: onSurf),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pending
                                    ? 'ожидает открытия чата'
                                    : (delivered
                                        ? 'прочитано'
                                        : 'доставлено в чат'),
                                style: TextStyle(
                                  color: pending
                                      ? Colors.orangeAccent
                                      : (delivered
                                          ? Colors.lightBlueAccent
                                          : onSurf.withValues(alpha: 0.38)),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 20),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: onSurf),
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: TextStyle(
                        color: onSurf.withValues(alpha: 0.3),
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : _send,
                  icon: Icon(
                    Icons.send,
                    color: sending
                        ? onSurf.withValues(alpha: 0.24)
                        : onSurf,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}