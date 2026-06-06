import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_db_service.dart';
import 'connectivity_service.dart';

/// Servicio de sincronización automática.
/// Cuando detecta reconexión a internet, envía todas las
/// emergencias pendientes en SQLite al backend (PostgreSQL via FastAPI).
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivity = ConnectivityService();

  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  // Notificaciones de sincronización para la UI
  final _syncResultController = StreamController<SyncResult>.broadcast();
  Stream<SyncResult> get onSyncResult => _syncResultController.stream;

  /// Inicializar — escuchar cambios de conectividad
  void initialize() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('🔄 Reconexión detectada, iniciando sincronización...');
        sincronizarPendientes();
      }
    });
  }

  /// Sincronizar todas las emergencias pendientes con el backend
  Future<void> sincronizarPendientes() async {
    if (_isSyncing) {
      debugPrint('⏳ Sincronización ya en curso...');
      return;
    }

    if (!_connectivity.isOnline) {
      debugPrint('📡 Sin conexión, sincronización aplazada');
      return;
    }

    _isSyncing = true;

    try {
      // Resetear los que tuvieron error (para reintentar)
      await OfflineDbService.resetearParaReintento();

      final pendientes = await OfflineDbService.obtenerPendientes();

      if (pendientes.isEmpty) {
        debugPrint('✅ No hay emergencias pendientes de sincronización');
        _isSyncing = false;
        return;
      }

      debugPrint('📤 Sincronizando ${pendientes.length} emergencia(s)...');

      int exitosos = 0;
      int fallidos = 0;

      for (final emergencia in pendientes) {
        final id = emergencia['id'] as int;
        final clientUuid = emergencia['client_uuid'] as String;

        // Máximo 5 reintentos
        if ((emergencia['retry_count'] as int) >= 5) {
          debugPrint('⚠️ Emergencia $clientUuid excedió máximo de reintentos');
          continue;
        }

        try {
          final response = await _apiService.reportarIncidente(
            idCliente: emergencia['id_cliente'] as int,
            idVehiculo: emergencia['id_vehiculo'] as int,
            latitud: emergencia['ubicacion_latitud'] as double,
            longitud: emergencia['ubicacion_longitud'] as double,
            descripcion: emergencia['descripcion_manual'] as String?,
            audioPath: emergencia['audio_path'] as String?,
            fotoPath: emergencia['foto_path'] as String?,
            clientUuid: clientUuid,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await OfflineDbService.marcarSincronizada(id);
            exitosos++;
            debugPrint('✅ Emergencia $clientUuid sincronizada');
          }
        } catch (e) {
          final errorStr = e.toString();

          // Si es 409 (duplicado), marcar como sincronizado
          if (errorStr.contains('409')) {
            await OfflineDbService.marcarSincronizada(id);
            exitosos++;
            debugPrint('♻️ Emergencia $clientUuid ya existía en el servidor');
          } else {
            await OfflineDbService.marcarError(id, errorStr);
            fallidos++;
            debugPrint('❌ Error sincronizando $clientUuid: $errorStr');
          }
        }
      }

      // Limpiar las sincronizadas de la BD local
      await OfflineDbService.limpiarSincronizadas();

      // Notificar a la UI
      _syncResultController.add(
        SyncResult(
          exitosos: exitosos,
          fallidos: fallidos,
          totalPendientes: await OfflineDbService.contarPendientes(),
        ),
      );

      debugPrint(
        '🔄 Sincronización completada: $exitosos exitosos, $fallidos fallidos',
      );
    } catch (e) {
      debugPrint('❌ Error general en sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncResultController.close();
  }
}

/// Resultado de una sincronización
class SyncResult {
  final int exitosos;
  final int fallidos;
  final int totalPendientes;

  SyncResult({
    required this.exitosos,
    required this.fallidos,
    required this.totalPendientes,
  });
}
