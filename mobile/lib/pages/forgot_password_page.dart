import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';

enum StepType { enterEmail, enterCode, enterNewPassword }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final ApiService _apiService = ApiService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  StepType _currentStep = StepType.enterEmail;
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _sendEmail() async {
    if (_emailController.text.isEmpty) {
      _showError("Por favor ingresa tu correo");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.recuperarPassword(_emailController.text);
      if (response.statusCode == 200) {
        _showSuccess("Código enviado al correo");
        setState(() => _currentStep = StepType.enterCode);
      }
    } catch (e) {
      _showError("Error: El correo no está registrado o hubo un fallo en el servidor");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyToken() async {
    if (_codeController.text.isEmpty) {
      _showError("Por favor ingresa el código");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.verificarToken(
        _emailController.text, 
        _codeController.text
      );
      if (response.statusCode == 200) {
        _showSuccess("Código verificado");
        setState(() => _currentStep = StepType.enterNewPassword);
      }
    } catch (e) {
      _showError("Código inválido o expirado");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_passwordController.text.isEmpty) {
      _showError("Ingresa tu nueva contraseña");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Las contraseñas no coinciden");
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.resetPassword(
        _emailController.text,
        _codeController.text,
        _passwordController.text
      );
      if (response.statusCode == 200) {
        _showSuccess("Contraseña actualizada con éxito");
        Navigator.pop(context);
      }
    } catch (e) {
      _showError("Error al actualizar la contraseña");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () {
            if (_currentStep == StepType.enterCode) {
              setState(() => _currentStep = StepType.enterEmail);
            } else if (_currentStep == StepType.enterNewPassword) {
              setState(() => _currentStep = StepType.enterCode);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          "Recuperar Contraseña",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: _buildStepUI(),
            ),
      ),
    );
  }

  Widget _buildStepUI() {
    switch (_currentStep) {
      case StepType.enterEmail:
        return _buildEmailStep();
      case StepType.enterCode:
        return _buildCodeStep();
      case StepType.enterNewPassword:
        return _buildNewPasswordStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        _buildIcon(Icons.restore_rounded),
        const SizedBox(height: 32),
        Text(
          "¿Olvidaste tu contraseña?",
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Ingresa tu correo electrónico y te enviaremos un código de verificación.",
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: "Correo Electrónico",
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textGray, size: 20),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sendEmail,
            child: const Text("Enviar Código"),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        _buildIcon(Icons.pin_rounded),
        const SizedBox(height: 32),
        Text(
          "Código de Seguridad",
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Ingresa el código de 6 dígitos enviado a ${_emailController.text}",
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            hintText: "Código de 6 dígitos",
            prefixIcon: Icon(Icons.lock_clock_outlined, color: AppTheme.textGray, size: 20),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyToken,
            child: const Text("Verificar Código"),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        _buildIcon(Icons.lock_reset_rounded),
        const SizedBox(height: 32),
        Text(
          "Nueva Contraseña",
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Escribe tu nueva contraseña de acceso.",
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            hintText: "Nueva Contraseña",
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textGray, size: 20),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            hintText: "Confirmar Contraseña",
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textGray, size: 20),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _resetPassword,
            child: const Text("Actualizar Contraseña"),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: AppTheme.primaryBlue,
        size: 40,
      ),
    );
  }
}
