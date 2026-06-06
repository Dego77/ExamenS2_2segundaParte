import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/offline_db_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _vehiculosCount = 0;
  String _ultimoServicio = '--';
  String _subtitleServicio = 'Sin servicios';
  bool _isLoading = true;
  int _pendingOffline = 0;
  StreamSubscription? _syncSub;
  StreamSubscription? _connectivitySub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchData();
    _loadPendingCount();
    _listenSync();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await OfflineDbService.contarPendientes();
      if (mounted) setState(() => _pendingOffline = count);
    } catch (_) {}
  }

  void _listenSync() {
    _syncSub = SyncService().onSyncResult.listen((_) {
      _loadPendingCount();
      _fetchData();
    });
    _connectivitySub = ConnectivityService().onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) _loadPendingCount();
    });
  }

  Future<void> _fetchData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final idCliente = authProvider.user?.id;
    if (idCliente == null) return;

    try {
      final api = ApiService();

      // 1. Cargar Vehículos
      final resVehiculos = await api.getVehiculos(idCliente);
      if (resVehiculos.statusCode == 200 && resVehiculos.data != null) {
        final List list = resVehiculos.data;
        _vehiculosCount = list.length;
      }

      // 2. Cargar Historial
      final resHistorial = await api.getHistorialPagos(idCliente);
      if (resHistorial.statusCode == 200 && resHistorial.data != null) {
        final List list = resHistorial.data;
        if (list.isNotEmpty) {
          final last =
              list.last; // El más reciente suele ser el último en añadirse
          _ultimoServicio = "Bs. ${last['monto'] ?? '0'}";
          _subtitleServicio = last['fecha'] != null
              ? "Pagado el ${last['fecha'].toString().substring(0, 10)}"
              : "Asistencia exitosa";
        }
      }
    } catch (e) {
      debugPrint("Error cargando estadísticas de cliente: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'Administrador';

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Inicio",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Offline pending banner
                    if (_pendingOffline > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$_pendingOffline emergencia(s) pendiente(s) de envío',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                SyncService().sincronizarPendientes();
                              },
                              child: Icon(
                                Icons.sync_rounded,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Greeting
                    Row(
                      children: [
                        Text(
                          "Hola, $userName",
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("👋", style: TextStyle(fontSize: 24)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Aquí tienes el resumen de tu vehículo",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Primary Action Card (Blue)
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/request');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryBlue, Color(0xFF0056B3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Asistencia Vehicular",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Disponible",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.car_crash_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      "¡Pedir Auxilio Ahora!",
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Toca aquí en caso de emergencia vial",
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sub cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubCard(
                            icon: Icons.directions_car_rounded,
                            iconColor: AppTheme.accentYellow,
                            title: "Vehículos Activos",
                            value: _vehiculosCount.toString(),
                            subtitle: "Registrados",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSubCard(
                            icon: Icons.history_rounded,
                            iconColor: AppTheme.secondaryGreen,
                            title: "Último servicio",
                            value: _ultimoServicio,
                            subtitle: _subtitleServicio,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSubCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(color: AppTheme.textGray, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppTheme.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
