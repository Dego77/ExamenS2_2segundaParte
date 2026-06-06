import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart';

class User {
  final int id;
  final String email;
  final String name;
  final String? token;

  User({required this.id, required this.email, required this.name, this.token});
}

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.loginCliente(email, password);
      if (response.statusCode == 200) {
        final data = response.data;
        _user = User(
          id: data['user_id'],
          email: email,
          name: data['user_name'],
          token: data['access_token'],
        );
        
        // Configurar Token Push (FCM)
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _apiService.actualizarFcmTokenCliente(_user!.id, fcmToken);
            debugPrint("Token FCM enviado: $fcmToken");
          }
        } catch (fcmError) {
          debugPrint("Error obteniendo FCM Token: $fcmError");
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Login error detailed: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String lastName,
    required String ciDni,
    required String email,
    required String password,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.registerCliente(
        nombres: name,
        apellidos: lastName,
        ciDni: ciDni,
        telefono: phone,
        correo: email,
        password: password,
      );

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Register error: $e");
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
