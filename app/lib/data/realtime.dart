import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';

class RealtimeClient {
  RealtimeClient(this.api);

  final ApiClient api;
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  bool _connected = false;
  bool _closing = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _connected;

  Future<void> connect() {
    if (_connected) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    _closing = false;
    final token = await api.tokens.accessToken;
    if (token == null) {
      throw const ApiException('Your session expired. Sign in again.');
    }
    await _subscription?.cancel();
    final httpUri = Uri.parse('${api.baseUrl}/realtime');
    final uri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
    );
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    final ready = Completer<void>();
    _subscription = channel.stream.listen(
      (raw) {
        try {
          final decoded = jsonDecode(raw.toString());
          if (decoded is! Map) return;
          final event = Map<String, dynamic>.from(decoded);
          if (event['type'] == 'ready' && !ready.isCompleted) {
            _connected = true;
            ready.complete();
          }
          _events.add(event);
        } catch (_) {
          _events.add({
            'type': 'transport.error',
            'data': {'message': 'The live reply was incomplete.'},
          });
        }
      },
      onError: (_) {
        _connected = false;
        if (!ready.isCompleted) {
          ready.completeError(
            const ApiException('We could not open the live conversation.'),
          );
        }
        _events.add({
          'type': 'transport.error',
          'data': {'message': 'The live conversation was interrupted.'},
        });
      },
      onDone: () {
        _connected = false;
        if (!ready.isCompleted) {
          ready.completeError(
            const ApiException('We could not open the live conversation.'),
          );
        }
        if (!_closing) {
          _events.add({
            'type': 'transport.error',
            'data': {'message': 'The live conversation was interrupted.'},
          });
        }
      },
    );
    await channel.ready.timeout(const Duration(seconds: 12));
    channel.sink.add(
      jsonEncode({
        'type': 'auth',
        'data': {'token': token},
      }),
    );
    await ready.future.timeout(const Duration(seconds: 12));
  }

  void send(String type, Map<String, dynamic> data) {
    if (!_connected || _channel == null) {
      throw const ApiException('The live conversation is not connected.');
    }
    _channel!.sink.add(jsonEncode({'type': type, 'data': data}));
  }

  Future<void> close() async {
    _closing = true;
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}
