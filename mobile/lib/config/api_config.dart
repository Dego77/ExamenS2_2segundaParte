// Configuración centralizada de APIs para la App Móvil Flutter
class ApiConfig {
  // Comenta/descomenta según el entorno en el que vayas a trabajar:

  // static const String baseUrl = 'http://10.0.2.2:8000'; // Desarrollo Local (Emulador Android)
  static const String baseUrl =
      'http://192.168.1.6:8001'; // Celular Físico (IP Real del PC)
  // static const String baseUrl = 'https://backend-fastapi-su7t.onrender.com'; // Producción en Render
}
