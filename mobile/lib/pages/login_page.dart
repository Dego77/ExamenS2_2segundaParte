import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  String _selectedRole = 'Conductor';

  Widget _buildSlidingToggle() {
    final isConductor = _selectedRole == 'Conductor';
    return Container(
      width: 280,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: isConductor ? 0 : 140,
            top: 0,
            bottom: 0,
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'Conductor'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "Conductor",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isConductor ? Colors.white : AppTheme.textDark.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = 'Técnico'),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "Técnico",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: !isConductor ? Colors.white : AppTheme.textDark.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFirstLoginPasswordDialog(BuildContext context, int idTecnico) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Primer Inicio de Sesión",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Por seguridad, debes cambiar la contraseña genérica asignada por el taller.",
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Nueva Contraseña",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirmar Contraseña",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Completa todos los campos"))
                );
                return;
              }
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Las contraseñas no coinciden"))
                );
                return;
              }

              try {
                final res = await _apiService.cambiarPasswordTecnico(idTecnico, newPasswordController.text);
                if (res.statusCode == 200) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Contraseña actualizada. Bienvenido."),
                        backgroundColor: AppTheme.secondaryGreen,
                      )
                    );
                    Navigator.pushReplacementNamed(context, '/mechanic_main', arguments: {'id_tecnico': idTecnico});
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error al cambiar contraseña: $e"),
                      backgroundColor: AppTheme.emergencyRed,
                    )
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Guardar e Ingresar"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Car Icon Header
              Image.asset(
                'assets/images/logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                "Iniciar sesión",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                "Accede a tu cuenta",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textGray,
                ),
              ),
              const SizedBox(height: 24),
              _buildSlidingToggle(),
              const SizedBox(height: 32),
              
              // Form Fields
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Correo electrónico",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: "tu@email.com",
                      prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textGray, size: 20),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Contraseña",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      hintText: "••••••••",
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textGray, size: 20),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedRole == 'Conductor')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/forgot_password');
                        },
                        child: const Text(
                          "¿Olvidaste tu contraseña?",
                          style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              
              if (authProvider.isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ingresa tus credenciales"))
                      );
                      return;
                    }

                    if (_selectedRole == 'Técnico') {
                      try {
                        final response = await _apiService.loginTecnico(
                          _emailController.text,
                          _passwordController.text,
                        );
                        if (response.statusCode == 200) {
                          final bool esPrimerLogin = response.data['primer_login'] ?? false;
                          final int idTecnico = response.data['user_id'];
                          
                          if (esPrimerLogin && context.mounted) {
                            _showFirstLoginPasswordDialog(context, idTecnico);
                          } else if (context.mounted) {
                            // Configurar Token Push (FCM)
                            try {
                              final fcmToken = await FirebaseMessaging.instance.getToken();
                              if (fcmToken != null) {
                                await _apiService.actualizarFcmTokenTecnico(idTecnico, fcmToken);
                                debugPrint("Token FCM Técnico enviado: $fcmToken");
                              }
                            } catch (fcmError) {
                              debugPrint("Error obteniendo FCM Token: $fcmError");
                            }

                            Navigator.pushReplacementNamed(context, '/mechanic_main', arguments: {'id_tecnico': idTecnico});
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Error al iniciar sesión como Técnico. Verifica tus datos."),
                              backgroundColor: AppTheme.emergencyRed,
                            ),
                          );
                        }
                      }
                      return;
                    }

                    final success = await authProvider.login(
                      _emailController.text,
                      _passwordController.text,
                    );
                    if (success) {
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/permissions');
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error al iniciar sesión. Verifica tu correo y contraseña."),
                            backgroundColor: AppTheme.emergencyRed,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("Ingresar"),
                ),
              const SizedBox(height: 48),
              if (_selectedRole == 'Conductor')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tienes cuenta? ",
                      style: GoogleFonts.inter(color: AppTheme.textGray),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        "Regístrate aquí",
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

}
