import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
    ),
  );

  // --- Clientes ---

  Future<Response> actualizarFcmTokenCliente(
    int idCliente,
    String token,
  ) async {
    return await _dio.post(
      '/api/clientes/$idCliente/fcm-token',
      data: {'fcm_token': token},
    );
  }

  Future<Response> actualizarFcmTokenTecnico(
    int idTecnico,
    String token,
  ) async {
    return await _dio.post(
      '/api/talleres/tecnicos/$idTecnico/fcm-token',
      data: {'fcm_token': token},
    );
  }

  Future<Response> loginCliente(String correo, String password) async {
    return await _dio.post(
      '/api/auth/login',
      data: {'correo': correo, 'password': password},
    );
  }

  Future<Response> registerCliente({
    required String nombres,
    required String apellidos,
    required String ciDni,
    required String telefono,
    required String correo,
    required String password,
  }) async {
    return await _dio.post(
      '/api/clientes/',
      data: {
        'nombres': nombres,
        'apellidos': apellidos,
        'ci_dni': ciDni,
        'telefono': telefono,
        'correo': correo,
        'password': password,
      },
    );
  }

  // --- Talleres ---

  Future<Response> loginTaller(String correo, String password) async {
    return await _dio.post(
      '/api/talleres/login',
      data: {'correo': correo, 'password': password},
    );
  }

  Future<Response> registerTaller(Map<String, dynamic> data) async {
    return await _dio.post('/api/talleres/', data: data);
  }

  Future<Response> loginTecnico(String correo, String password) async {
    return await _dio.post(
      '/api/talleres/tecnicos/login',
      data: {'correo': correo, 'password': password},
    );
  }

  Future<Response> reportarIncidente({
    required int idCliente,
    required int idVehiculo,
    required double latitud,
    required double longitud,
    String? descripcion,
    String? audioPath,
    String? fotoPath,
    String? clientUuid,
  }) async {
    final map = <String, dynamic>{
      'id_cliente': idCliente,
      'id_vehiculo': idVehiculo,
      'ubicacion_latitud': latitud,
      'ubicacion_longitud': longitud,
      'descripcion_manual': descripcion ?? '',
    };
    if (clientUuid != null) {
      map['client_uuid'] = clientUuid;
    }
    FormData formData = FormData.fromMap(map);

    if (audioPath != null && audioPath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'audio',
          await MultipartFile.fromFile(audioPath, filename: 'audio.m4a'),
        ),
      );
    }

    if (fotoPath != null && fotoPath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'foto',
          await MultipartFile.fromFile(fotoPath, filename: 'foto.jpg'),
        ),
      );
    }

    return await _dio.post('/api/incidentes/reportar', data: formData);
  }

  Future<Response> notificarTaller({
    required int idIncidente,
    required int idTaller,
  }) async {
    return await _dio.post(
      '/api/incidentes/$idIncidente/notificar-taller',
      data: {'id_taller': idTaller},
    );
  }

  Future<Response> cambiarPasswordTecnico(
    int idTecnico,
    String newPassword,
  ) async {
    return await _dio.post(
      '/api/talleres/tecnicos/$idTecnico/cambiar-password',
      data: {'new_password': newPassword},
    );
  }

  Future<Response> getIncidente(int idIncidente) async {
    return await _dio.get('/api/incidentes/$idIncidente');
  }

  // --- Recuperación de Contraseña ---

  Future<Response> recuperarPassword(String correo) async {
    return await _dio.post(
      '/api/auth/forgot-password',
      data: {'correo': correo},
    );
  }

  Future<Response> verificarToken(String correo, String token) async {
    return await _dio.post(
      '/api/auth/verify-token',
      data: {'correo': correo, 'token': token},
    );
  }

  Future<Response> resetPassword(
    String correo,
    String token,
    String nuevaPassword,
  ) async {
    return await _dio.post(
      '/api/auth/reset-password',
      data: {'correo': correo, 'token': token, 'nueva_password': nuevaPassword},
    );
  }

  Future<Response> calificarAsistencia(
    int idIncidente,
    int puntuacion,
    String? comentario,
  ) async {
    return await _dio.post(
      '/api/incidentes/$idIncidente/calificar',
      data: {'puntuacion': puntuacion, 'comentario': comentario ?? ''},
    );
  }

  Future<Response> getTecnicoTrabajos(int idTecnico) async {
    return await _dio.get('/api/talleres/tecnicos/$idTecnico/trabajos');
  }

  Future<Response> getTecnicoPerfil(int idTecnico) async {
    return await _dio.get('/api/talleres/tecnicos/$idTecnico');
  }

  Future<Response> actualizarUbicacionTecnico(
    int idTecnico,
    double lat,
    double lng,
  ) async {
    return await _dio.post(
      '/api/talleres/tecnicos/$idTecnico/ubicacion',
      data: {'latitud': lat, 'longitud': lng},
    );
  }

  Future<Response> actualizarEstadoIncidente(
    int idIncidente,
    String estado,
  ) async {
    return await _dio.put(
      '/api/incidentes/$idIncidente/estado',
      data: {'estado': estado},
    );
  }

  Future<Response> getIncidenteTracking(int idIncidente) async {
    return await _dio.get('/api/incidentes/$idIncidente/tracking');
  }

  Future<Response> getVehiculos(int idCliente) async {
    return await _dio.get('/api/clientes/$idCliente/vehiculos');
  }

  Future<Response> registrarVehiculo(
    int idCliente,
    Map<String, dynamic> vehiculo,
  ) async {
    return await _dio.post(
      '/api/clientes/$idCliente/vehiculos',
      data: vehiculo,
    );
  }

  Future<Response> getHistorialPagos(int idCliente) async {
    return await _dio.get('/api/pagos/cliente/$idCliente');
  }

  // --- Cotizaciones ---

  Future<Response> getCotizacionesIncidente(int idIncidente) async {
    return await _dio.get('/api/cotizaciones/incidente/$idIncidente');
  }

  Future<Response> aceptarCotizacion(int idCotizacion) async {
    return await _dio.patch('/api/cotizaciones/$idCotizacion/aceptar');
  }

  Future<Response> rechazarCotizacion(int idCotizacion) async {
    return await _dio.patch('/api/cotizaciones/$idCotizacion/rechazar');
  }

  // --- Pagos ---

  Future<Response> crearSesionPago({
    required int idIncidente,
    required int idTaller,
    required double montoTotal,
    required String metodoPago,
  }) async {
    return await _dio.post(
      '/api/pagos/crear-sesion',
      data: {
        'id_incidente': idIncidente,
        'id_taller': idTaller,
        'monto_total': montoTotal,
        'metodo_pago': metodoPago,
      },
    );
  }

  Future<Response> confirmarPago(int idPago) async {
    return await _dio.post('/api/pagos/$idPago/confirmar');
  }
}
