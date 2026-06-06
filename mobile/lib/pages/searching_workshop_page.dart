import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_db_service.dart';
import '../services/client_websocket_service.dart';
import '../theme.dart';

class SearchingWorkshopPage extends StatefulWidget {
  const SearchingWorkshopPage({super.key});

  @override
  State<SearchingWorkshopPage> createState() => _SearchingWorkshopPageState();
}

class _SearchingWorkshopPageState extends State<SearchingWorkshopPage> {
  String _status = "Analizando situación con Inteligencia Artificial...";
  bool _hasError = false;
  String _errorMessage = "";
  int _step = 0; // 0: IA, 1: Selección, 2: Espera
  int? _idIncidente;
  bool _argsLoaded = false;
  Timer? _pollingTimer;
  StreamSubscription? _wsSubscription;
  final ApiService _apiService = ApiService();
  final ClientWebsocketService _wsService = ClientWebsocketService();

  List<dynamic> _cotizaciones = [];

  int? _idCliente;
  int? _idVehiculo;
  double? _latitud;
  double? _longitud;
  String? _descripcion;
  String? _audioPath;
  String? _fotoPath;

  List<dynamic> _talleresCercanos = [];
  Set<Marker> _markers = {};
  int? _idTallerSeleccionado;
  String? _tallerNombreSeleccionado;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _idIncidente = args['id_incidente'];
        _idCliente = args['idCliente'];
        _idVehiculo = args['idVehiculo'];
        _latitud = args['latitud'];
        _longitud = args['longitud'];
        _descripcion = args['descripcion'];
        _audioPath = args['audioPath'];
        _fotoPath = args['fotoPath'];
      }
      _argsLoaded = true;
      _startRealFlow();
    }
  }

  void _startRealFlow() async {
    if (_idIncidente == null && _idCliente != null) {
      final connectivity = ConnectivityService();

      if (!connectivity.isOnline) {
        await _guardarOffline();
        return;
      }

      try {
        final uuid = Uuid().v4();
        final response = await _apiService.reportarIncidente(
          idCliente: _idCliente!,
          idVehiculo: _idVehiculo!,
          latitud: _latitud!,
          longitud: _longitud!,
          descripcion: _descripcion ?? '',
          audioPath: _audioPath,
          fotoPath: _fotoPath,
          clientUuid: uuid,
        );

        if (response.data is Map) {
          setState(() {
            _idIncidente = response.data['id_incidente'];
            _talleresCercanos = response.data['talleres_notificados'] ?? [];
            _step = 1;
            _status = "Selecciona un taller disponible o espera cotizaciones";
            _updateMarkers();
            _initWebSocket();
          });
        }
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = "Error al conectar con el servidor: $e";
        });
      }
    } else if (_idIncidente != null) {
      setState(() {
        _step = 1;
        _status = "Buscando talleres para este incidente...";
      });
      _initWebSocket();
    }
  }

  Future<void> _guardarOffline() async {
    final uuid = Uuid().v4();
    await OfflineDbService.insertarEmergencia(
      clientUuid: uuid,
      idCliente: _idCliente!,
      idVehiculo: _idVehiculo!,
      latitud: _latitud!,
      longitud: _longitud!,
      descripcion: _descripcion,
      audioPath: _audioPath,
      fotoPath: _fotoPath,
    );

    setState(() {
      _hasError = true;
      _errorMessage =
          "Sin conexión. Emergencia guardada localmente. Se enviará automáticamente al recuperar internet.";
    });
  }

  void _initWebSocket() {
    if (_idCliente == null || _idIncidente == null) return;
    _wsService.connect(_idCliente!);
    _wsSubscription = _wsService.messages.listen((message) {
      if (message['type'] == 'NUEVA_COTIZACION') {
        setState(() {
          _cotizaciones.add(message);
        });
      } else if (message['type'] == 'TALLER_ASIGNADO' ||
          message['type'] == 'ESTADO_CAMBIADO') {
        _checkIncidentStatus();
      }
    });

    _cargarCotizacionesExistentes();
  }

  Future<void> _cargarCotizacionesExistentes() async {
    try {
      final res = await _apiService.getCotizacionesIncidente(_idIncidente!);
      if (res.statusCode == 200 && res.data is List) {
        setState(() {
          _cotizaciones = (res.data as List)
              .map(
                (c) => {
                  'id_cotizacion': c['id_cotizacion'],
                  'id_incidente': c['id_incidente'],
                  'id_taller': c['id_taller'],
                  'monto': c['monto_estimado']?.toDouble() ?? 0.0,
                  'tiempo_minutos': c['tiempo_estimado_minutos'] ?? 0,
                  'taller_nombre': c['taller_nombre'] ?? 'Taller',
                  'descripcion': c['descripcion_propuesta'] ?? '',
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error cargando cotizaciones existentes: $e");
    }
  }

  void _checkIncidentStatus() async {
    try {
      final res = await _apiService.getIncidente(_idIncidente!);
      if (res.statusCode == 200) {
        final status = res.data['estado'];
        if (status == 'En Camino' ||
            status == 'En Proceso' ||
            status == 'Pagado') {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/tracking',
              arguments: {'id_incidente': _idIncidente},
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error verificando estado: $e");
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers = _talleresCercanos.map((t) {
        return Marker(
          markerId: MarkerId(t['id_taller'].toString()),
          position: LatLng(t['latitud'], t['longitud']),
          infoWindow: InfoWindow(
            title: t['razon_social'],
            snippet: "Toca para seleccionar",
          ),
          onTap: () {
            setState(() {
              _idTallerSeleccionado = t['id_taller'];
              _tallerNombreSeleccionado = t['razon_social'];
            });
          },
        );
      }).toSet();
    });
  }

  void _confirmarSeleccionTaller() async {
    if (_idTallerSeleccionado == null) return;
    setState(() {
      _step = 2;
      _status = "Solicitando asistencia a $_tallerNombreSeleccionado...";
    });

    try {
      if (_idIncidente != null) {
        await _apiService.notificarTaller(
          idIncidente: _idIncidente!,
          idTaller: _idTallerSeleccionado!,
        );
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/tracking',
            arguments: {'id_incidente': _idIncidente},
          );
        }
      }
    } catch (e) {
      setState(() {
        _step = 1;
        _status = "Error al solicitar taller. Intenta de nuevo.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_latitud ?? -17.3935, _longitud ?? -66.1570),
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Column(
              children: [_buildHeader(), const Spacer(), _buildInfoPanel()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Buscando Asistencia",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cotizaciones.isNotEmpty) ...[
            Text(
              "Propuestas recibidas:",
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _cotizaciones.length,
                itemBuilder: (context, index) {
                  final cot = _cotizaciones[index];
                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cot['taller_nombre'] ?? 'Taller',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "Bs. ${cot['monto']}",
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${cot['tiempo_minutos']} min - ${cot['descripcion'] ?? ''}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 30,
                          child: ElevatedButton(
                            onPressed: () =>
                                _aceptarCotizacion(cot['id_cotizacion']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Aceptar",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
          _buildStatusText(),
          const SizedBox(height: 16),
          if (_step == 1 && _idTallerSeleccionado != null)
            ElevatedButton(
              onPressed: _confirmarSeleccionTaller,
              child: Text("Solicitar auxilio a $_tallerNombreSeleccionado"),
            ),
          if (_step == 2)
            const LinearProgressIndicator(color: AppTheme.primaryBlue),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        _hasError ? _errorMessage : _status,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 18,
          color: _hasError ? Colors.red : AppTheme.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _aceptarCotizacion(int idCotizacion) async {
    final cot = _cotizaciones.firstWhere(
      (c) => c['id_cotizacion'] == idCotizacion,
      orElse: () => null,
    );
    if (cot == null) return;

    setState(() {
      _step = 2;
      _status = "Aceptando propuesta...";
    });
    try {
      await _apiService.aceptarCotizacion(idCotizacion);
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/payment',
          arguments: {
            'id_incidente': _idIncidente,
            'id_taller': cot['id_taller'],
            'monto': cot['monto'],
          },
        );
      }
    } catch (e) {
      debugPrint("Error aceptando cotización: $e");
      setState(() {
        _step = 1;
        _status = "Error al aceptar propuesta. Intenta de nuevo.";
      });
    }
  }
}
