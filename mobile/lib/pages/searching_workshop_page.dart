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

class _SearchingWorkshopPageState extends State<SearchingWorkshopPage> with SingleTickerProviderStateMixin {
  String _status = "Analizando situación con Inteligencia Artificial...";
  bool _hasError = false;
  String _errorMessage = "";
  int _step = 0; // 0: IA, 1: Selección, 2: Espera
  int? _idIncidente;
  bool _argsLoaded = false;
  Timer? _pollingTimer;
  StreamSubscription? _wsSubscription;
  late AnimationController _rotationController;
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
  String? _evaluacionIa;
  String? _urgenciaIa;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
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

            final eval = response.data['evaluacion_ia'];
            if (eval is Map) {
              _evaluacionIa = eval['diagnostico_ia']?.toString();
              _urgenciaIa = eval['urgencia']?.toString();
            } else if (eval != null) {
              _evaluacionIa = eval.toString();
            }

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
    
    // Polling de respaldo por si falla el WebSocket
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _idIncidente != null) {
        _cargarCotizacionesExistentes();
      }
    });
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
    final Set<Marker> newMarkers = {};
    
    // Marcador del Cliente (Azul)
    if (_latitud != null && _longitud != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('cliente_loc'),
          position: LatLng(_latitud!, _longitud!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Tu Ubicación'),
        ),
      );
    }
    
    // Marcadores de Talleres (Verde)
    for (var t in _talleresCercanos) {
      final lat = t['latitud'];
      final lng = t['longitud'];
      if (lat != null && lng != null) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('taller_${t['id_taller']}'),
            position: LatLng(lat.toDouble(), lng.toDouble()),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: t['razon_social'] ?? 'Taller',
              snippet: 'Distancia: ${t['distancia']?.toStringAsFixed(1) ?? '1.5'} km',
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
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
    if (_step == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: Center(
          child: _buildAiOverlay(),
        ),
      );
    }

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
              children: [
                _buildHeader(),
                const Spacer(),
                _buildInfoPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiOverlay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Color(0xFFE5F1FF),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 50,
                  color: Color(0xFF007AFF),
                ),
              ),
            ),
            RotationTransition(
              turns: _rotationController,
              child: const SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50),
        Text(
          "Tranquilo, estamos contigo.",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Analizando situación con Inteligencia Artificial...",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón de retroceso circular
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Pill central "Cotizaciones"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              "Cotizaciones",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Badge circular de cotizaciones recibidas
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "${_cotizaciones.length}",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
        color: const Color(0xFFF7F9FC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle deslizable
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título de la sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Propuestas recibidas",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "Selecciona la mejor opción para tu emergencia",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Listado de cotizaciones
          if (_cotizaciones.isNotEmpty) ...[
            SizedBox(
              height: 310,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _cotizaciones.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final cot = _cotizaciones[index];
                  final tCercano = _talleresCercanos.firstWhere(
                    (t) => t['id_taller'] == cot['id_taller'],
                    orElse: () => null,
                  );
                  final double distancia = tCercano != null ? (tCercano['distancia']?.toDouble() ?? 1.5) : 1.5;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5F1FF), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Color(0xFF2EBA8B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cot['taller_nombre'] ?? 'Taller',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        "5.0",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${distancia.toStringAsFixed(1)} km",
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5F1FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.map_rounded, color: Color(0xFF007AFF), size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE5F1FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.payment_rounded, color: Color(0xFF007AFF), size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Precio", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                                        Text("Bs. ${cot['monto']}", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 30, color: Colors.grey[300]),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFF7E6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.access_time_rounded, color: Colors.orange, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Tiempo est.", style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
                                        Text("${cot['tiempo_minutos']} min", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _rechazarCotizacion(cot['id_cotizacion']),
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                label: Text("Rechazar", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _confirmarAceptacionDialog(cot),
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: Text("Aceptar", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C59A4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Esperando cotizaciones...",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Los talleres cercanos están evaluando tu caso con la IA para enviarte sus propuestas.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          if (_step == 2) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: Color(0xFF007AFF)),
          ],
        ],
      ),
    );
  }

  void _rechazarCotizacion(int idCotizacion) async {
    try {
      await _apiService.rechazarCotizacion(idCotizacion);
      setState(() {
        _cotizaciones.removeWhere((c) => c['id_cotizacion'] == idCotizacion);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Propuesta rechazada")),
        );
      }
    } catch (e) {
      debugPrint("Error al rechazar cotización: $e");
    }
  }

  void _confirmarAceptacionDialog(Map<String, dynamic> cot) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "¿Aceptar cotización?",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    cot['taller_nombre'] ?? 'Taller',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Bs. ${cot['monto']}",
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${cot['tiempo_minutos']} min estimados",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Al aceptar, este taller será notificado y asignará un técnico para atenderte.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "Cancelar",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _aceptarCotizacion(cot['id_cotizacion']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2EBA8B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Aceptar",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          '/tracking',
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
