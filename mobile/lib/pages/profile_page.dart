import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'Administrador';
    final userEmail = authProvider.user?.email ?? 'admin@gmail.com';

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          "Mi Perfil",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            Text(
              userEmail,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGray),
            ),
            const SizedBox(height: 48),
            
            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildMenuItem(context, Icons.lock_outline_rounded, "Cambiar Contraseña"),
                  _buildMenuItem(context, Icons.notifications_none_rounded, "Notificaciones"),
                  _buildMenuItem(context, Icons.help_outline_rounded, "Soporte y Ayuda"),
                  
                  const SizedBox(height: 40),
                  
                  // Logout Button
                  OutlinedButton(
                    onPressed: () {
                      _showLogoutDialog(context, authProvider);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.emergencyRed,
                      side: const BorderSide(color: AppTheme.emergencyRed),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          "Cerrar Sesión",
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryBlue),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textGray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("La función '$title' está en desarrollo."),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cerrar sesión"),
        content: const Text("¿Estás seguro que deseas salir?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text("Cerrar sesión", style: TextStyle(color: AppTheme.emergencyRed)),
          ),
        ],
      ),
    );
  }
}
