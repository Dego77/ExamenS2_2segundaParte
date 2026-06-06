import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(-17.7833, -63.1821);
  LatLng _technicianPosition = const LatLng(-17.7780, -63.1750);
  bool _loadingLocation = true;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  Timer? _pollingTimer;
  int? _idIncidente;
  bool _argsLoaded = false;
  String _estadoSolicitud = "Pendiente";
  String? _tipoProblema;
  String? _nivelPrioridad;
  String? _diagnosticoIA;
  String _tallerNombre = "Buscando taller...";
  final ApiService _apiService = ApiService();
  String _etaText = "Calculando...";
  String _distanceText = "";
  bool _hasTechnicianPosition = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadTrackData();
    _startTechnicianPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _idIncidente = args['id_incidente'];
        _fetchTechnicianLocation();
      }
      _argsLoaded = true;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startTechnicianPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchTechnicianLocation();
    });
  }

  Future<void> _fetchTechnicianLocation() async {
    if (_idIncidente != null) {
      try {
        final response = await _apiService.getIncidenteTracking(_idIncidente!);
        if (response.statusCode == 200) {
          final data = response.data;
          if (mounted) {
            setState(() {
              _estadoSolicitud = data['estado'] ?? 'Pendiente';
              _tipoProblema = data['tipo_problema'];
              _nivelPrioridad = data['nivel_prioridad'];
              _diagnosticoIA = data['diagnostico_ia'];
              _tallerNombre = data['taller_nombre'] ?? 'Taller AsistAuto';
              _currentPosition = LatLng(
                data['lat_cliente'] ?? _currentPosition.latitude,
                data['lng_cliente'] ?? _currentPosition.longitude,
              );
              final newLat = data['lat_tecnico'];
              final newLng = data['lng_tecnico'];
              if (newLat != null && newLng != null) {
                _technicianPosition = LatLng(newLat, newLng);
                _hasTechnicianPosition = true;
              }
            });

            _calculateETA();
            _loadTrackData();

            if (_estadoSolicitud == 'Por Pagar') {
              _pollingTimer?.cancel();
              Navigator.pushReplacementNamed(
                context,
                '/checkout',
                arguments: {'id_incidente': _idIncidente},
              );
            }

            if (_estadoSolicitud == 'Completado') {
              _pollingTimer?.cancel();
              _showAsistenciaRealizadaDialog();
            }
          }
        }
      } catch (e) {
        debugPrint("Error consultando tracking del incidente: $e");
      }
    }
  }

  void _showAsistenciaRealizadaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "¡Asistencia Realizada!",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              "Muchas gracias por confiar en nosotros. Tu vehículo está listo.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textDark),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(
                  context,
                  '/rating',
                  arguments: {'id_incidente': _idIncidente},
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Calificar Servicio"),
            ),
          ),
        ],
      ),
    );
  }

  void _loadTrackData() {
    _markers.clear();
    _polylines.clear();

    // Marcador del Cliente
    _markers.add(
      Marker(
        markerId: const MarkerId('client'),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // Solo añadir técnico y ruta si hay un incidente activo
    if (_idIncidente != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('technician'),
          position: _technicianPosition,
          infoWindow: const InfoWindow(title: 'Técnico en camino'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      _getPolyline();
    }
  }

  void _getPolyline() async {
    PolylinePoints polylinePoints = PolylinePoints();

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: "AIzaSyDQBB3iWZhPvB5hXpNMESLjyput04sYrdY",
        request: PolylineRequest(
          origin: PointLatLng(
            _technicianPosition.latitude,
            _technicianPosition.longitude,
          ),
          destination: PointLatLng(
            _currentPosition.latitude,
            _currentPosition.longitude,
          ),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        if (mounted) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylineCoordinates,
                color: AppTheme.primaryBlue,
                width: 5,
              ),
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: [_currentPosition, _technicianPosition],
                color: AppTheme.primaryBlue,
                width: 5,
              ),
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: [_currentPosition, _technicianPosition],
              color: AppTheme.primaryBlue,
              width: 5,
            ),
          );
        });
      }
    }
  }

  void _calculateETA() {
    if (!_hasTechnicianPosition) return;

    double distanceMeters = Geolocator.distanceBetween(
      _technicianPosition.latitude,
      _technicianPosition.longitude,
      _currentPosition.latitude,
      _currentPosition.longitude,
    );

    double distanceKm = distanceMeters / 1000;
    double etaMinutes = (distanceKm / 30) * 60; // 30 km/h promedio urbano

    if (mounted) {
      setState(() {
        _distanceText = "${distanceKm.toStringAsFixed(1)} km";
        if (etaMinutes < 1) {
          _etaText = "< 1 min";
        } else {
          _etaText = "${etaMinutes.toInt()} min";
        }
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _loadingLocation = false;
        });
        _loadTrackData();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 15),
        );
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Stack(
        children: [
          // Mapa a Pantalla Completa
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 15.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_loadingLocation) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition, 15),
                  );
                }
              },
            ),
          ),

          if (_loadingLocation)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),

          // ETA / Distance chip (solo si hay técnico y está en camino)
          if (_hasTechnicianPosition &&
              (_estadoSolicitud == 'En Camino' ||
                  _estadoSolicitud == 'Aceptado' ||
                  _estadoSolicitud == 'Asignado'))
            Positioned(
              top: 55,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _etaText,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        Text(
                          _distanceText,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Header Flotante / Back Button
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textDark,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Título Central Superior
          Positioned(
            top: 60,
            left: 80,
            right: 80,
            child: Center(
              child: Text(
                "Seguimiento",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ),

          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: _idIncidente == null
                      ? [
                          const SizedBox(height: 40),
                          Center(
                            child: Icon(
                              Icons.location_off_rounded,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              "Sin asistencias activas",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              "Aquí podrás ver el progreso de tu auxilio vial en tiempo real una vez que lo solicites.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textGray,
                              ),
                            ),
                          ),
                        ]
                      : [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_diagnosticoIA != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Diagnóstico IA (${_tipoProblema ?? 'Procesando'})",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _diagnosticoIA!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppTheme.textGray,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _estadoSolicitud == 'Pendiente'
                                          ? Colors.blue.withOpacity(0.1)
                                          : (_estadoSolicitud == 'Completado'
                                                ? Colors.green.withOpacity(0.1)
                                                : const Color(0xFFFFFBEB)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _estadoSolicitud == 'Pendiente'
                                          ? "Buscando Taller..."
                                          : (_estadoSolicitud == 'Aceptado'
                                                ? "Taller Asignado"
                                                : (_estadoSolicitud ==
                                                          'En Camino'
                                                      ? "Mecánico en Camino"
                                                      : (_estadoSolicitud ==
                                                                'Atendido'
                                                            ? "En Atención"
                                                            : "Finalizado"))),
                                      style: GoogleFonts.inter(
                                        color: _estadoSolicitud == 'Pendiente'
                                            ? Colors.blue
                                            : (_estadoSolicitud == 'Completado'
                                                  ? Colors.green
                                                  : AppTheme.accentYellow),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    Container(
                                      height: 6,
                                      width:
                                          MediaQuery.of(context).size.width *
                                          (_estadoSolicitud == 'Pendiente'
                                              ? 0.2
                                              : (_estadoSolicitud == 'Aceptado'
                                                    ? 0.4
                                                    : (_estadoSolicitud ==
                                                              'En Camino'
                                                          ? 0.6
                                                          : (_estadoSolicitud ==
                                                                    'Atendido'
                                                                ? 0.8
                                                                : 1.0)))),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                _buildStep(
                                  Icons.check_rounded,
                                  "Buscando taller",
                                  true,
                                  true,
                                  _estadoSolicitud == 'Pendiente',
                                ),
                                _buildStep(
                                  Icons.check_rounded,
                                  "Taller asignado",
                                  _estadoSolicitud == 'Aceptado' ||
                                      _estadoSolicitud == 'En Camino' ||
                                      _estadoSolicitud == 'Atendido' ||
                                      _estadoSolicitud == 'Completado',
                                  true,
                                  _estadoSolicitud == 'Aceptado',
                                ),

                                _buildStep(
                                  Icons.check_rounded,
                                  "En camino",
                                  _estadoSolicitud == 'En Camino' ||
                                      _estadoSolicitud == 'Atendido' ||
                                      _estadoSolicitud == 'Completado',
                                  _estadoSolicitud == 'En Camino',
                                  false,
                                ),
                                _buildStep(
                                  Icons.build_circle_rounded,
                                  "En atención",
                                  _estadoSolicitud == 'Atendido' ||
                                      _estadoSolicitud == 'Completado',
                                  _estadoSolicitud == 'Atendido',
                                  _estadoSolicitud == 'Atendido',
                                ),
                                _buildStep(
                                  Icons.star_rounded,
                                  "Finalizada",
                                  _estadoSolicitud == 'Completado',
                                  _estadoSolicitud == 'Completado',
                                  _estadoSolicitud == 'Completado',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Taller asignado",
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.textGray,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withOpacity(
                                          0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.handyman_rounded,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _tallerNombre,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textDark,
                                            ),
                                          ),

                                          Text(
                                            "A 1.5 km de tu posición",
                                            style: GoogleFonts.inter(
                                              color: AppTheme.textGray,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: AppTheme.accentYellow,
                                          size: 18,
                                        ),
                                        Text(
                                          " 4.8",
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed:
                                      (_estadoSolicitud == 'Por Pagar' ||
                                          _estadoSolicitud == 'Completado')
                                      ? () => Navigator.pushReplacementNamed(
                                          context,
                                          '/checkout',
                                          arguments: {
                                            'id_incidente': _idIncidente,
                                          },
                                        )
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        (_estadoSolicitud == 'Por Pagar' ||
                                            _estadoSolicitud == 'Completado')
                                        ? AppTheme.primaryBlue
                                        : Colors.grey.shade200,
                                    foregroundColor:
                                        (_estadoSolicitud == 'Por Pagar' ||
                                            _estadoSolicitud == 'Completado')
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                    elevation: 0,
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    (_estadoSolicitud == 'Por Pagar' ||
                                            _estadoSolicitud == 'Completado')
                                        ? "Proceder al Pago"
                                        : (_estadoSolicitud == 'Atendido'
                                              ? "Técnico trabajando..."
                                              : "Esperando asistencia..."),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    IconData icon,
    String title,
    bool isCompleted,
    bool showLine,
    bool isCurrent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.primaryBlue
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isCompleted ? Colors.white : Colors.grey.shade400,
                size: 20,
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 35,
                color: isCompleted
                    ? AppTheme.primaryBlue
                    : Colors.grey.shade200,
              ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCurrent
                      ? AppTheme.primaryBlue
                      : (isCompleted ? AppTheme.textDark : AppTheme.textGray),
                ),
              ),
              if (isCurrent)
                Text(
                  "En progreso...",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textGray,
                  ),
                ),
            ],
          ),
        ),
        if (isCompleted && !isCurrent)
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppTheme.secondaryGreen,
            size: 24,
          ),
      ],
    );
  }
}
