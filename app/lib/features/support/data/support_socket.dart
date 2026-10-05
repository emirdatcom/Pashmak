import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/logger.dart';

/// One open connection (a seam over `WebSocketChannel` so reconnect logic is testable).
abstract class SocketConnection {
  Stream<String> get messages;
  void send(String text);
  Future<void> close();
}

class _ChannelConnection implements SocketConnection {
  _ChannelConnection(this._ch);
  final WebSocketChannel _ch;
  @override
  Stream<String> get messages => _ch.stream.map((e) => e as String);
  @override
  void send(String text) => _ch.sink.add(text);
  @override
  Future<void> close() async => _ch.sink.close();
}

Future<SocketConnection> connectWebSocket(Uri uri) async {
  final ch = WebSocketChannel.connect(uri);
  await ch.ready;
  return _ChannelConnection(ch);
}

enum SocketState { idle, connecting, live, polling }

/// A server push the repository reacts to (the repository re-syncs over HTTP; frames are hints + payload).
class SocketEvent {
  const SocketEvent(this.type, this.data);
  final String type; // message.new | message.read | conversation.status
  final Map<String, dynamic> data;
}

/// Real-time channel with automatic recovery (docs/21 B3/B6):
///  * the access token travels in the first frame, never in the URL;
///  * JSON ping every 25 s keeps NAT/proxies open;
///  * reconnect with exponential backoff (1 s … 30 s);
///  * after [failuresBeforePolling] consecutive failures the state becomes `polling`, and [onPoll] runs every
///    [pollInterval] until a connection works again — so delivery never depends on the WebSocket.
class SupportSocket {
  SupportSocket({
    required this.baseUri,
    required this.tokenProvider,
    required this.onPoll,
    SocketConnector? connector,
    Future<void> Function(Duration)? delay,
    this.pingInterval = const Duration(seconds: 25),
    this.pollInterval = const Duration(seconds: 10),
    this.failuresBeforePolling = 3,
    this.readyTimeout = const Duration(seconds: 8),
  })  : _connector = connector ?? connectWebSocket,
        _delay = delay ?? Future<void>.delayed;

  final Uri baseUri; // wss://host/v1/support/ws
  final Future<String?> Function() tokenProvider;
  final Future<void> Function() onPoll;
  final SocketConnector _connector;
  final Future<void> Function(Duration) _delay;
  final Duration pingInterval;
  final Duration pollInterval;
  final int failuresBeforePolling;
  final Duration readyTimeout;

  final _events = StreamController<SocketEvent>.broadcast();
  final _state = StreamController<SocketState>.broadcast();
  SocketState _current = SocketState.idle;
  bool _running = false;
  int _failures = 0;
  SocketConnection? _conn;

  Stream<SocketEvent> get events => _events.stream;
  Stream<SocketState> get stateChanges => _state.stream;
  SocketState get state => _current;

  void _set(SocketState s) {
    if (_current == s) return;
    _current = s;
    _state.add(s);
  }

  /// Starts the loop (idempotent). Only call while the chat is on screen or the app is in the foreground with an open conversation.
  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  Future<void> stop() async {
    _running = false;
    await _conn?.close();
    _conn = null;
    _set(SocketState.idle);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _state.close();
  }

  Duration _backoff() {
    final secs = 1 << (_failures - 1).clamp(0, 5); // 1,2,4,8,16,32 → capped below
    return Duration(seconds: secs > 30 ? 30 : secs);
  }

  Future<void> _loop() async {
    while (_running) {
      _set(_failures >= failuresBeforePolling ? SocketState.polling : SocketState.connecting);
      try {
        await _session();
        _failures = 0; // a connection that worked and later closed is not a failure streak
      } catch (e) {
        _failures++;
        AppLogger.warn('support socket: ${e.runtimeType}');
      }
      if (!_running) return;
      if (_failures >= failuresBeforePolling) {
        _set(SocketState.polling);
        try {
          await onPoll();
        } catch (_) {}
        await _delay(pollInterval);
      } else {
        await _delay(_backoff());
      }
    }
  }

  Future<void> _session() async {
    final token = await tokenProvider();
    if (token == null) throw StateError('no token');
    final conn = await _connector(baseUri);
    _conn = conn;
    final ready = Completer<void>();
    final done = Completer<void>();
    Timer? pinger;
    final sub = conn.messages.listen((raw) {
      Map<String, dynamic> f;
      try {
        f = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
      final type = f['type'] as String? ?? '';
      if (type == 'ready' && !ready.isCompleted) ready.complete();
      if (type == 'message.new' || type == 'message.read' || type == 'conversation.status') _events.add(SocketEvent(type, f));
    }, onError: (Object e) {
      if (!ready.isCompleted) ready.completeError(e);
      if (!done.isCompleted) done.complete();
    }, onDone: () {
      if (!ready.isCompleted) ready.completeError(StateError('closed before ready'));
      if (!done.isCompleted) done.complete();
    });
    try {
      conn.send(jsonEncode({'type': 'auth', 'token': token}));
      await ready.future.timeout(readyTimeout);
      _failures = 0;
      _set(SocketState.live);
      pinger = Timer.periodic(pingInterval, (_) => conn.send('{"type":"ping"}'));
      await onPoll(); // catch up on anything missed while disconnected
      await done.future;
    } finally {
      pinger?.cancel();
      await sub.cancel();
      await conn.close();
      _conn = null;
    }
  }
}

typedef SocketConnector = Future<SocketConnection> Function(Uri uri);
