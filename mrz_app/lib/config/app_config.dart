// CONFIGURACIÓN DE CONEXIÓN AL SERVIDOR
class AppConfig {
  // Servidor Node.js (app.js) - Para escanear MRZ (SIN SSL)
  static const String apiBaseUrl = 'http://control.sseguridad.cl:3001';
  
  // Servidor Python (main.py) - Para registrar visitas (CON SSL)
  // Sin puerto = usa nginx en 443 que hace proxy al servidor interno
  static const String registerUrl = 'https://control.sseguridad.cl';
  
  // Servidor para login (CON SSL)
  static const String loginUrl = 'https://control.sseguridad.cl';

  static const String appName = 'MRZ Scanner';
  
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}