import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';

import '../services/api_service.dart';

class MechanicHomePage extends StatefulWidget {
  final int idTecnico;
  const MechanicHomePage({super.key, required this.idTecnico});

  @override
  State<MechanicHomePage> createState() => _MechanicHomePageState();
}

class _MechanicHomePageState extends State<MechanicHomePage> {
  bool _enTurno = true;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _trabajos = [];
  bool _isLoading = true;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _fetchTrabajos();
    _requestLocationPermissions();
  }

  Future<void> _requestLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    _startGpsTracking();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  void _startGpsTracking() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_enTurno) {
        _sendGpsLocation();
      }
    });
  }

  Future<void> _sendGpsLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _apiService.actualizarUbicacionTecnico(
        widget.idTecnico,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint("Error al enviar GPS del técnico: $e");
    }
  }

  Future<void> _fetchTrabajos() async {
    try {
      final response = await _apiService.getTecnicoTrabajos(widget.idTecnico);
      if (response.statusCode == 200) {
        setState(() {
          final allJobs = List<Map<String, dynamic>>.from(response.data);
          _trabajos = allJobs
              .where(
                (job) =>
                    job["estado"] != "Completado" &&
                    job["estado"] != "Finalizado" &&
                    job["estado"] != "Cancelado",
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _trabajos = [];
        });
        debugPrint("Error al obtener trabajos: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          "Panel del Técnico",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.primaryBlue,
            ),
            tooltip: "Actualizar servicios",
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchTrabajos();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de Estado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _enTurno ? "Estás en Turno" : "Fuera de Turno",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _enTurno
                              ? AppTheme.secondaryGreen
                              : AppTheme.textGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _enTurno
                            ? "Disponible para emergencias"
                            : "No recibirás alertas",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _enTurno,
                    activeColor: AppTheme.secondaryGreen,
                    onChanged: (val) {
                      setState(() => _enTurno = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              "Servicios Asignados",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : _trabajos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_rounded,
                            size: 64,
                            color: AppTheme.textGray.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No tienes trabajos pendientes",
                            style: GoogleFonts.inter(color: AppTheme.textGray),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _trabajos.length,
                      itemBuilder: (context, index) {
                        final job = _trabajos[index];
                        final isAlta = job["prioridad"] == "Alta";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAlta
                                  ? AppTheme.emergencyRed.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    job["id"],
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAlta
                                          ? AppTheme.emergencyRed.withOpacity(
                                              0.1,
                                            )
                                          : AppTheme.accentYellow.withOpacity(
                                              0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      job["prioridad"],
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isAlta
                                            ? AppTheme.emergencyRed
                                            : AppTheme.accentYellow,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                job["cliente"],
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                job["vehiculo"],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.textGray,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: AppTheme.textGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      job["problema"],
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 16,
                                        color: AppTheme.secondaryGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        job["distancia"] ?? "En ruta",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/mechanic_job_details',
                                        arguments: job,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(120, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      backgroundColor: AppTheme.primaryBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      job["estado"] == "Asignado"
                                          ? "Atender"
                                          : "Ver Ruta",
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }
}
