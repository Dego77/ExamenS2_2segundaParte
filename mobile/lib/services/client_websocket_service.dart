import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class ClientWebsocketService {
  static final ClientWebsocketService _instance =
      ClientWebsocketService._internal();
  factory ClientWebsocketService() => _instance;
  ClientWebsocketService._internal();

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  int? _currentClientId;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(int idCliente) {
    if (_currentClientId == idCliente && _channel != null) return;

    _currentClientId = idCliente;
    final wsUrl =
        ApiConfig.baseUrl.replaceFirst('http', 'ws') +
        '/ws/clientes/$idCliente';

    debugPrint("🔌 Conectando WebSocket Cliente: $wsUrl");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            debugPrint("❌ Error decodificando mensaje WS: $e");
          }
        },
        onDone: () {
          debugPrint("🔌 WebSocket Cliente desconectado. Reintentando...");
          _reconnect();
        },
        onError: (error) {
          debugPrint("❌ Error WebSocket Cliente: $error");
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint("❌ Error conectando WebSocket: $e");
      _reconnect();
    }
  }

  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentClientId != null) {
        connect(_currentClientId!);
      }
    });
  }

  void disconnect() {
    _currentClientId = null;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
