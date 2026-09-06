import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config.dart';

enum RealtimeState { connecting, online, offline }

/// Channel realtime ke Cloudflare Durable Object.
///
/// Server mengirim event JSON:
///   {"type":"order.update","payload":{...}}
///   {"type":"chat.message","payload":{...}}
///   {"type":"stock.update","payload":{"id":"pc-1","unitTersedia":3}}
///   {"type":"cs.typing","payload":{"typing":true}}
class RealtimeService {
  RealtimeService();

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _sengajaTutup = false;
  String? _room;
  String? _token;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _state = StreamController<RealtimeState>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeState> get state => _state.stream;
  RealtimeState current = RealtimeState.offline;

  void _setState(RealtimeState s) {
    current = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> connect({required String room, required String token}) async {
    _room = room;
    _token = token;
    _sengajaTutup = false;
    _open();
  }

  void _open() {
    if (_room == null) return;
    _setState(RealtimeState.connecting);
    try {
      _ch = WebSocketChannel.connect(Uri.parse(XyConfig.wsUrl(_room!, _token ?? '')));
      _sub = _ch!.stream.listen(
        (data) {
          _attempt = 0;
          if (current != RealtimeState.online) _setState(RealtimeState.online);
          try {
            final m = jsonDecode(data as String) as Map<String, dynamic>;
            if (m['type'] == 'pong') return;
            _events.add(RealtimeEvent(m['type'] ?? '', (m['payload'] ?? {}) as Map<String, dynamic>));
          } catch (_) {/* abaikan frame non-JSON */}
        },
        onDone: _handleDrop,
        onError: (_) => _handleDrop(),
        cancelOnError: true,
      );
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => send('ping', {}));
    } catch (_) {
      _handleDrop();
    }
  }

  void _handleDrop() {
    _ping?.cancel();
    _sub?.cancel();
    _setState(RealtimeState.offline);
    if (_sengajaTutup) return;
    // exponential backoff + jitter, maks 20 detik
    final delay = min(20, pow(2, _attempt++).toInt()) * 1000 + Random().nextInt(600);
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: delay), _open);
  }

  void send(String type, Map<String, dynamic> payload) {
    try {
      _ch?.sink.add(jsonEncode({'type': type, 'payload': payload}));
    } catch (_) {}
  }

  Future<void> dispose() async {
    _sengajaTutup = true;
    _ping?.cancel();
    _retry?.cancel();
    await _sub?.cancel();
    await _ch?.sink.close();
    await _events.close();
    await _state.close();
  }
}

class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;
  RealtimeEvent(this.type, this.payload);
}
