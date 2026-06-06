import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../theme.dart';
import '../services/api_service.dart';

class MechanicJobDetailsPage extends StatefulWidget {
  const MechanicJobDetailsPage({super.key});

  @override
  State<MechanicJobDetailsPage> createState() => _MechanicJobDetailsPageState();
}

class _MechanicJobDetailsPageState extends State<MechanicJobDetailsPage> {
  GoogleMapController? _mapController;
  LatLng? _technicianPosition; // Posición real del técnico (GPS)
  LatLng? _clientPosition; // Posición del incidente del cliente
  bool _loadingLocation = true;
  String _currentState = "Asignado";
  final ApiService _apiService = ApiService();
  bool _argsLoaded = false;
  int? _idIncidenteReal;

  // Ruta y ETA
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String _etaText = "Calculando...";
  String _distanceText = "";
  StreamSubscription<Position>? _positionStream;
  Timer? _locationUpdateTimer;

  // Google Directions API Key (misma que usa tracking_page)
  static const String _googleApiKey = "AIzaSyDQBB3iWZhPvB5hXpNMESLjyput04sYrdY";

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _idIncidenteReal = args['id_incidente'];
        _currentState = args['estado'] ?? "Asignado";

        final double? lat = args['latitud'];
        final double? lng = args['longitud'];
        if (lat != null && lng != null) {
          _clientPosition = LatLng(lat, lng);
        }
      }
      _argsLoaded = true;
      _initTechnicianLocation();
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  /// Obtiene la posición GPS real del técnico y arranca el streaming
  Future<void> _initTechnicianLocation() async {
    try {
      // Pedir permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _technicianPosition = LatLng(position.latitude, position.longitude);
          _loadingLocation = false;
        });
        _updateMapData();
        _fitBounds();
        _startLocationStreaming();
      }
    } catch (e) {
      debugPrint("Error obteniendo ubicación del técnico: $e");
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  /// Inicia el streaming de ubicación en tiempo real
  void _startLocationStreaming() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Solo actualizar cuando se mueva 10m
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _technicianPosition = LatLng(
                position.latitude,
                position.longitude,
              );
            });
            _updateMapData();

            // Enviar ubicación al backend cada movimiento
            _sendLocationToBackend(position.latitude, position.longitude);
          }
        });
  }

  /// Envía la ubicación al backend para que el cliente pueda ver el movimiento
  Future<void> _sendLocationToBackend(double lat, double lng) async {
    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      // Usamos el user_id guardado en shared prefs o lo sacamos del login
      // Por ahora usamos el endpoint genérico
      await _apiService.actualizarUbicacionTecnico(
        _idIncidenteReal ?? 0, // Fallback
        lat,
        lng,
      );
    } catch (e) {
      debugPrint("Error enviando ubicación: $e");
    }
  }

  /// Actualiza marcadores y ruta en el mapa
  void _updateMapData() {
    if (_technicianPosition == null) return;

    _markers.clear();

    // Marcador del Técnico (azul)
    _markers.add(
      Marker(
        markerId: const MarkerId('tecnico'),
        position: _technicianPosition!,
        infoWindow: const InfoWindow(title: 'Mi posición'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    // Marcador del Cliente (rojo)
    if (_clientPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('cliente'),
          position: _clientPosition!,
          infoWindow: const InfoWindow(title: 'Cliente'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Dibujar ruta
    if (_clientPosition != null) {
      _drawRoute();
    }

    if (mounted) setState(() {});
  }

  /// Dibuja la ruta entre el técnico y el cliente usando Google Directions
  Future<void> _drawRoute() async {
    if (_technicianPosition == null || _clientPosition == null) return;

    PolylinePoints polylinePoints = PolylinePoints();

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleApiKey,
        request: PolylineRequest(
          origin: PointLatLng(
            _technicianPosition!.latitude,
            _technicianPosition!.longitude,
          ),
          destination: PointLatLng(
            _clientPosition!.latitude,
            _clientPosition!.longitude,
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
            _polylines.clear();
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
        // Fallback: línea recta
        if (mounted) {
          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: [_technicianPosition!, _clientPosition!],
                color: AppTheme.primaryBlue,
                width: 4,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo ruta: $e");
      // Fallback: línea recta punteada
      if (mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: [_technicianPosition!, _clientPosition!],
              color: AppTheme.primaryBlue,
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        });
      }
    }

    // Calcular distancia y ETA
    _calculateETA();
  }

  /// Calcula la distancia y el tiempo estimado de llegada
  void _calculateETA() {
    if (_technicianPosition == null || _clientPosition == null) return;

    double distanceMeters = Geolocator.distanceBetween(
      _technicianPosition!.latitude,
      _technicianPosition!.longitude,
      _clientPosition!.latitude,
      _clientPosition!.longitude,
    );

    double distanceKm = distanceMeters / 1000;
    // Estimación: velocidad promedio urbana 30 km/h
    double etaMinutes = (distanceKm / 30) * 60;

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

  /// Ajusta la cámara para mostrar ambos marcadores
  void _fitBounds() {
    if (_mapController == null ||
        _technicianPosition == null ||
        _clientPosition == null)
      return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        _technicianPosition!.latitude < _clientPosition!.latitude
            ? _technicianPosition!.latitude
            : _clientPosition!.latitude,
        _technicianPosition!.longitude < _clientPosition!.longitude
            ? _technicianPosition!.longitude
            : _clientPosition!.longitude,
      ),
      northeast: LatLng(
        _technicianPosition!.latitude > _clientPosition!.latitude
            ? _technicianPosition!.latitude
            : _clientPosition!.latitude,
        _technicianPosition!.longitude > _clientPosition!.longitude
            ? _technicianPosition!.longitude
            : _clientPosition!.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _updateState(int? idIncidente) async {
    if (_currentState == "Por Pagar") {
      try {
        if (idIncidente != null) {
          final trackResp = await _apiService.getIncidenteTracking(idIncidente);
          if (trackResp.statusCode == 200) {
            final data = trackResp.data;
            bool pagoHecho = data['pago_completado'] ?? false;
            if (!pagoHecho) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "⚠️ Pago Pendiente: El cliente aún no ha pagado.",
                  ),
                  backgroundColor: Colors.orangeAccent,
                ),
              );
              return;
            }
          }
        }
      } catch (e) {
        debugPrint("Error validando pago: $e");
      }
    }

    String nuevoEstado = "Asignado";
    if (_currentState == "Asignado" || _currentState == "Aceptado") {
      nuevoEstado = "En Camino";
    } else if (_currentState == "En Camino" || _currentState == "En camino") {
      nuevoEstado = "Atendido";
    } else if (_currentState == "Atendido") {
      nuevoEstado = "Por Pagar";
    } else if (_currentState == "Por Pagar") {
      nuevoEstado = "Completado";
    }

    try {
      if (idIncidente != null) {
        await _apiService.actualizarEstadoIncidente(idIncidente, nuevoEstado);
      }
    } catch (e) {
      debugPrint("Error al actualizar estado en el backend: $e");
    }

    setState(() {
      _currentState = nuevoEstado;
    });

    if (_currentState == "Completado") {
      _positionStream?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Servicio finalizado exitosamente."),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final cliente = args?['cliente'] ?? "Conductor";
    final vehiculo = args?['vehiculo'] ?? "Vehículo";
    final problema = args?['problema'] ?? "Problema reportado";
    final idDisplay = args?['id'] ?? "INC-?";
    _idIncidenteReal = args?['id_incidente'];

    return Scaffold(
      body: Stack(
        children: [
          // Mapa con ruta
          Positioned.fill(
            child: _loadingLocation
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue,
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _technicianPosition ??
                          _clientPosition ??
                          const LatLng(-17.78, -63.18),
                      zoom: 14.0,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Ajustar la cámara para mostrar ambos marcadores
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _fitBounds();
                      });
                    },
                  ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textDark,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Info de ETA / Distancia (arriba derecha)
          if (_clientPosition != null && _technicianPosition != null)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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

          // Tarjeta inferior de gestión
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        idDisplay,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    cliente,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    vehiculo,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.emergencyRed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            problema,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildActionButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    if (_currentState == "Asignado" || _currentState == "Aceptado") {
      bgColor = AppTheme.primaryBlue.withOpacity(0.1);
      textColor = AppTheme.primaryBlue;
    } else if (_currentState == "En Camino" || _currentState == "En camino") {
      bgColor = AppTheme.accentYellow.withOpacity(0.1);
      textColor = AppTheme.accentYellow;
    } else {
      bgColor = AppTheme.secondaryGreen.withOpacity(0.1);
      textColor = AppTheme.secondaryGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _currentState,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    String label = "Confirmar / En camino";
    IconData icon = Icons.directions_car_rounded;
    Color btnColor = AppTheme.primaryBlue;

    if (_currentState == "En Camino" || _currentState == "En camino") {
      label = "Llegué / Atendiendo";
      icon = Icons.build_circle_rounded;
      btnColor = AppTheme.accentYellow;
    } else if (_currentState == "Atendido" || _currentState == "Atendiendo") {
      label = "Solicitar Pago";
      icon = Icons.payment_rounded;
      btnColor = Colors.teal;
    } else if (_currentState == "Por Pagar") {
      label = "Finalizar Servicio";
      icon = Icons.check_circle_rounded;
      btnColor = AppTheme.secondaryGreen;
    }

    return ElevatedButton.icon(
      onPressed: () => _updateState(_idIncidenteReal),
      icon: Icon(icon),
      label: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
