import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';

class MechanicProfilePage extends StatefulWidget {
  final int idTecnico;
  const MechanicProfilePage({super.key, required this.idTecnico});

  @override
  State<MechanicProfilePage> createState() => _MechanicProfilePageState();
}

class _MechanicProfilePageState extends State<MechanicProfilePage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String _nombreCompleto = "Cargando...";
  String _correo = "...";
  String _taller = "...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _apiService.getTecnicoPerfil(widget.idTecnico);
      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _nombreCompleto = "${data['nombres']} ${data['apellidos']}";
            _correo = data['correo'];
            _taller = data['taller'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nombreCompleto = "Pedro Mendoza (Offline)";
          _correo = "tecnico@test.com";
          _taller = "Taller Central";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cambiar Contraseña",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Nueva Contraseña",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirmar Contraseña",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: GoogleFonts.inter(color: AppTheme.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Completa todos los campos"))
                );
                return;
              }
              if (_newPasswordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Las contraseñas no coinciden"))
                );
                return;
              }
              
              try {
                await _apiService.cambiarPasswordTecnico(1, _newPasswordController.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Contraseña actualizada correctamente"),
                      backgroundColor: AppTheme.secondaryGreen,
                    )
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error al cambiar contraseña: $e"))
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Actualizar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          "Mi Perfil",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: const Icon(Icons.person_rounded, size: 64, color: AppTheme.primaryBlue),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _nombreCompleto,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            Text(
              "Técnico Automotriz",
              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textGray),
            ),
            const SizedBox(height: 32),
            
            _buildProfileItem(Icons.email_rounded, "Correo Electrónico", _correo),
            const SizedBox(height: 16),
            _buildProfileItem(Icons.business_rounded, "Taller Asignado", _taller),
            const SizedBox(height: 32),

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.emergencyRed),
              label: Text("Cerrar Sesión", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.emergencyRed)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppTheme.emergencyRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textGray)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          )
        ],
      ),
    );
  }
}
