import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  Future<void> _checkExistingPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      // Si ya tiene permisos, saltamos directamente al Main
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handlePermissions() async {
    LocationPermission permission = await Geolocator.requestPermission();
    
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permiso denegado permanentemente. Por favor, actívalo en ajustes."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Success Indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.secondaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "¡Bienvenido!",
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Icons Illustration
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCircleIcon(Icons.location_on_rounded, AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  _buildCircleIcon(Icons.camera_alt_rounded, AppTheme.accentYellow),
                  const SizedBox(width: 10),
                  _buildCircleIcon(Icons.mic_rounded, AppTheme.secondaryGreen),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                "Permisos necesarios",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Para que nuestra Inteligencia Artificial pueda diagnosticar tu vehículo y enviar asistencia, necesitamos acceso a:",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Info Cards
              _buildInfoCard(
                icon: Icons.location_on_outlined,
                title: "Ubicación en tiempo real",
                subtitle: "Para enviar el taller exactamente a donde estás.",
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.camera_alt_outlined,
                title: "Cámara y Fotos",
                subtitle: "Para capturar la evidencia del problema.",
                color: AppTheme.accentYellow,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.mic_none_rounded,
                title: "Micrófono",
                subtitle: "Para describir el incidente con tu voz.",
                color: AppTheme.secondaryGreen,
              ),
              
              const Spacer(),
              
              // Buttons
              ElevatedButton.icon(
                onPressed: _handlePermissions,
                icon: const Icon(Icons.verified_user_rounded, size: 20),
                label: const Text("Permitir accesos"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/main'),
                child: const Text(
                  "Omitir por ahora",
                  style: TextStyle(color: AppTheme.textGray),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(
        icon,
        color: color,
        size: 30,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

