import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio que detecta el estado de conexión a internet.
/// Emite eventos cuando cambia el estado (online/offline).
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Stream de cambios de conectividad
  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  StreamSubscription? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Inicializar el servicio — llamar una vez al arrancar la app
  Future<void> initialize() async {
    // Verificar estado actual
    final results = await _connectivity.checkConnectivity();
    _isOnline = _checkResults(results);
    debugPrint('🌐 Conectividad inicial: ${_isOnline ? "ONLINE" : "OFFLINE"}');

    // Escuchar cambios
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _checkResults(results);

      if (wasOnline != _isOnline) {
        debugPrint(
          '🌐 Conectividad cambió: ${_isOnline ? "ONLINE" : "OFFLINE"}',
        );
        _onlineController.add(_isOnline);
      }
    });
  }

  bool _checkResults(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
