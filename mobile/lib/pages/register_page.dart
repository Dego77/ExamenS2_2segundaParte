import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ciController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Crear Cuenta",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Únete a nosotros",
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Obtén asistencia vial inteligente en segundos.",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: "Nombres",
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textGray, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  hintText: "Apellidos",
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textGray, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _ciController,
                decoration: const InputDecoration(
                  hintText: "Carnet de Identidad (CI/DNI)",
                  prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textGray, size: 20),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: "Correo Electrónico",
                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textGray, size: 20),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: "Teléfono",
                  prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textGray, size: 20),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  hintText: "Contraseña",
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.textGray, size: 20),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              
              if (authProvider.isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.isEmpty || 
                        _lastNameController.text.isEmpty ||
                        _ciController.text.isEmpty ||
                        _emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Por favor, completa los campos obligatorios"))
                      );
                      return;
                    }

                    final success = await authProvider.register(
                      name: _nameController.text,
                      lastName: _lastNameController.text,
                      ciDni: _ciController.text,
                      email: _emailController.text,
                      phone: _phoneController.text,
                      password: _passwordController.text,
                    );
                    
                    if (success) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("¡Cuenta creada con éxito! Ya puedes iniciar sesión."),
                            backgroundColor: AppTheme.secondaryGreen,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error al registrar. Intenta con otro correo."),
                            backgroundColor: AppTheme.emergencyRed,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("Registrarse"),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
