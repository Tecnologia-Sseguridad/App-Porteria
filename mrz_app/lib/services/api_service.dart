import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';
import '../config/app_config.dart';

class SessionData {
  final String accessToken;
  final int usuarioId;
  final int organizacionId;
  final List<OrganizacionData> organizaciones;
  final String cryptoKey;

  SessionData({
    required this.accessToken,
    required this.usuarioId,
    required this.organizacionId,
    required this.organizaciones,
    required this.cryptoKey,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'usuarioId': usuarioId,
    'organizacionId': organizacionId,
    'cryptoKey': cryptoKey,
  };

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      accessToken: json['accessToken'],
      usuarioId: json['usuarioId'],
      organizacionId: json['organizacionId'],
      organizaciones: [],
      cryptoKey: json['cryptoKey'],
    );
  }
}

class OrganizacionData {
  final int id;
  final String nombre;

  OrganizacionData({required this.id, required this.nombre});

  factory OrganizacionData.fromJson(Map<String, dynamic> json) {
    return OrganizacionData(
      id: json['id'],
      nombre: json['nombre'],
    );
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal();

  String get baseUrl => AppConfig.apiBaseUrl;
  String get scanUrl => AppConfig.apiBaseUrl;
  String get loginUrl => AppConfig.loginUrl;
  String get registerUrl => AppConfig.registerUrl;

  static const int MAX_SESSION_MINUTES = 470; // 7 horas 50 min (backup local)

  SessionData? _session;
  DateTime? _loginTime;

  VoidCallback? onSessionExpired;

  SessionData? get session => _session;
  int get usuarioId => _session?.usuarioId ?? 0;
  int get organizacionId => _session?.organizacionId ?? 0;
  String get accessToken => _session?.accessToken ?? '';
  List<OrganizacionData> get organizaciones => _session?.organizaciones ?? [];

  bool get isLoggedIn => _session != null;

  bool get isSessionExpiredLocal {
    if (_loginTime == null) return true;
    final now = DateTime.now();
    final diff = now.difference(_loginTime!).inMinutes;
    return diff >= MAX_SESSION_MINUTES;
  }

  Future<void> saveLoginTime() async {
    _loginTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('login_timestamp', _loginTime!.millisecondsSinceEpoch);
  }

  Future<void> loadLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('login_timestamp');
    if (timestamp != null) {
      _loginTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  Future<bool> validateSession({bool triggerCallback = true}) async {
    if (_session == null) return false;

    // Primero: verificar expiración local
    if (isSessionExpiredLocal) {
      print('[ApiService] Sesión expirada localmente (${MAX_SESSION_MINUTES} min)');
      await _handleSessionExpired(triggerCallback: triggerCallback);
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$registerUrl/verificar-acceso/$_session!.usuarioId'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        print('[ApiService] Token expirado o inválido (servidor)');
        await _handleSessionExpired(triggerCallback: triggerCallback);
        return false;
      }

      // Error del servidor pero no 401 - permitir por ahora
      return true;
    } catch (e) {
      print('[ApiService] validateSession error: $e');
      // Si hay error de conexión, permitir retry (no expirar localmente aún)
      return true;
    }
  }

  Future<bool> validateSessionSimple() async {
    // Sin callback, solo para verificaciones background
    if (_session == null) return false;

    if (isSessionExpiredLocal) {
      await _handleSessionExpiredLocal();
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$registerUrl/verificar-acceso/$_session!.usuarioId'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) return true;
      if (response.statusCode == 401) {
        await _handleSessionExpiredLocal();
        return false;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _handleSessionExpiredLocal() async {
    _session = null;
    _loginTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('session_uid');
      await prefs.remove('session_org_id');
      await prefs.remove('session_crypto');
      await prefs.remove('login_timestamp');
    } catch (_) {}

    if (onSessionExpired != null) {
      onSessionExpired!();
    }
  }

  Future<void> _handleSessionExpired({bool triggerCallback = true}) async {
    _session = null;
    _loginTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('session_uid');
      await prefs.remove('session_org_id');
      await prefs.remove('session_crypto');
      await prefs.remove('login_timestamp');
    } catch (_) {}

    if (triggerCallback && onSessionExpired != null) {
      onSessionExpired!();
    }
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      print('[ApiService] Error 401 - Sesión expirada');
      await _handleSessionExpired(triggerCallback: false);
      return {'success': false, 'session_expired': true, 'message': 'Sesión expirada'};
    }
    
    return null;
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      final uid = prefs.getInt('session_uid');
      final orgId = prefs.getInt('session_org_id');
      final crypto = prefs.getString('session_crypto');
      
      if (token != null && uid != null && orgId != null) {
        _session = SessionData(
          accessToken: token,
          usuarioId: uid,
          organizacionId: orgId,
          organizaciones: [],
          cryptoKey: crypto ?? '',
        );
        print('[ApiService] Sesión restaurada: uid=$uid, org=$orgId');
        await loadLoginTime();
      }
    } catch (e) {
      print('[ApiService] Error restaurando sesión: $e');
    }
  }

  Future<void> persistSession() async {
    if (_session == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', _session!.accessToken);
      await prefs.setInt('session_uid', _session!.usuarioId);
      await prefs.setInt('session_org_id', _session!.organizacionId);
      await prefs.setString('session_crypto', _session!.cryptoKey);
      print('[ApiService] Sesión persistida');
    } catch (e) {
      print('[ApiService] Error persistiendo sesión: $e');
    }
  }

  Future<void> clearSession() async {
    _session = null;
    _loginTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('session_uid');
      await prefs.remove('session_org_id');
      await prefs.remove('session_crypto');
      await prefs.remove('login_timestamp');
      print('[ApiService] Sesión limpiada');
    } catch (e) {
      print('[ApiService] Error limpiando sesión: $e');
    }
  }

  Future<bool> checkSessionBeforeOperation() async {
    // Verifica si la sesión es válida ANTES de una operación crítica (como escanear)
    if (_session == null) return false;

    // Verificar expiración local
    if (isSessionExpiredLocal) {
      print('[ApiService] Sesión expirada localmente antes de operación');
      await _handleSessionExpiredLocal();
      return false;
    }

    return true;
  }

  Future<dynamic> login(String email, String password) async {
    print('[ApiService] Intentando login con: $email');
    try {
      final response = await http.post(
        Uri.parse('$loginUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ApiService] Respuesta login: $data');
        if (data['status'] == 'success') {
          final userData = data['user'];
          
          _session = SessionData(
            accessToken: data['access_token'],
            usuarioId: userData['id'],
            organizacionId: userData['organizacion_id'] ?? 0,
            organizaciones: (userData['organizaciones'] as List?)
                ?.map((o) => OrganizacionData.fromJson(o))
                .toList() ?? [],
            cryptoKey: data['session_crypto_key'] ?? '',
          );

          print('[ApiService] Sesión guardada. Token: ${_session!.accessToken.substring(0, 20)}...');
          await persistSession();
          await saveLoginTime();

          return {
            'success': true,
            'id': userData['id'],
            'email': userData['email'],
            'name': userData['email'].toString().split('@').first,
            'organizacion_id': userData['organizacion_id'] ?? 0,
            'organizaciones': userData['organizaciones'] ?? [],
          };
        }
      }
      return {'success': false, 'message': 'Credenciales inválidas'};
    } catch (e) {
      print('[ApiService] Error login: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<dynamic> scanMRZ(File imageFile, {Function(double, String)? onProgress}) async {
    print('[ApiService] scanMRZ - Session: ${_session != null}');
    print('[ApiService] scanMRZ - UsuarioId: ${_session?.usuarioId}');
    
    if (_session == null) return {'success': false, 'message': 'Sesión no iniciada'};

    try {
      onProgress?.call(0.1, 'Preparando imagen...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$scanUrl/api/scan'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      request.headers['Authorization'] = 'Bearer ${_session!.accessToken}';

      onProgress?.call(0.3, 'Enviando al servidor...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      onProgress?.call(0.6, 'Procesando datos...');

      final response = await http.Response.fromStream(streamedResponse);

      final sessionError = await _handleResponse(response);
      if (sessionError != null) return sessionError;

      if (response.statusCode == 200) {
        onProgress?.call(0.85, 'Analizando resultado...');
        final data = jsonDecode(response.body);
        print('[ApiService] scanMRZ - Respuesta: $data');
        
        if (data['success'] == true) {
          onProgress?.call(1.0, 'Completado');
          final mrzData = data['data'] ?? {};
          
          final nombreCompleto = '${mrzData['nombres'] ?? ''} ${mrzData['apellidos'] ?? ''}'.trim();
          
          return {
            'success': true,
            'rut': mrzData['rut'] ?? '',
            'nombre': nombreCompleto,
            'serie': mrzData['numero_carnet'] ?? '',
            'sexo': mrzData['sexo'] ?? 'M',
            'nacionalidad': mrzData['nacionalidad'] ?? 'CHILENA',
          };
        }
        
        return {'success': false, 'message': data['error'] ?? 'Error al procesar'};
      }
      return {'success': false, 'message': 'Error del servidor: ${response.statusCode}'};
    } catch (e) {
      print('[ApiService] scanMRZ - Error: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> checkBlacklist({
    required String rut,
    required int usuarioId,
  }) async {
    print('[ApiService] checkBlacklist - RUT: $rut, Usuario: $usuarioId');

    try {
      final response = await http.post(
        Uri.parse('$scanUrl/api/check-blacklist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rut': rut,
          'usuario_id': usuarioId,
        }),
      ).timeout(const Duration(seconds: 30));

      final sessionError = await _handleResponse(response);
      if (sessionError != null) return {...sessionError, 'is_blacklist': false};

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ApiService] checkBlacklist - Respuesta: $data');
        return {
          'success': true,
          'is_blacklist': data['is_blacklist'] == true,
          'motivo': data['motivo'] ?? '',
          'message': data['message'] ?? '',
        };
      }
      return {'success': false, 'is_blacklist': false, 'message': 'Error del servidor'};
    } catch (e) {
      print('[ApiService] checkBlacklist - Error: $e');
      return {'success': false, 'is_blacklist': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> registrarVisita({
    required String rut,
    required String nombre,
    required String sexo,
    required String serie,
    required String nacionalidad,
    required String destino,
    String? patente,
    String? comentario,
    bool esBlacklist = false,
  }) async {
    print('DEBUG registrarVisita - INICIO, _session null: ${_session == null}');
    if (_session == null) {
      print('DEBUG registrarVisita - Session es NULL!');
      return {'success': false, 'message': 'Sesión no iniciada'};
    }

    try {
      final bodyJson = jsonEncode({
        'organizacion_id': _session!.organizacionId,
        'usuario_id': _session!.usuarioId,
        'rut_visita': rut,
        'nombre_visita': nombre,
        'sexo': sexo,
        'serie_carnet': serie,
        'nacionalidad': nacionalidad,
        'destino': destino,
        'patente': patente ?? '',
        'comentario': comentario ?? '',
        'es_blacklist': esBlacklist,
      });
      print('DEBUG registrarVisita - Body: $bodyJson');
      print('DEBUG registrarVisita - Token: ${_session!.accessToken.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse('$registerUrl/registrar-visita'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
        body: bodyJson,
      ).timeout(const Duration(seconds: 30));

      final sessionError = await _handleResponse(response);
      if (sessionError != null) return sessionError;

      print('DEBUG registrarVisita - Status: ${response.statusCode}');
      print('DEBUG registrarVisita - Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return {'success': true, 'message': 'Visita registrada correctamente'};
        }
        return {'success': false, 'message': data['detail'] ?? 'Error al registrar'};
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getVisitasActivas({int? organizacionId}) async {
    if (_session == null) return [];
    
    final orgId = organizacionId ?? _session!.organizacionId;

    try {
      final response = await http.get(
        Uri.parse('$registerUrl/visitas-activas?org_id=$orgId'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['iv'] != null && data['data'] != null) {
          return [];
        }
        
        final sessionError = await _handleResponse(response);
        if (sessionError != null) return [];
        
        return [];
      }
      
      final sessionError = await _handleResponse(response);
      if (sessionError != null) return [];
      
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getMisVisitasHoy() async {
    if (_session == null) return {'success': false, 'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};

    try {
      final response = await http.get(
        Uri.parse('$registerUrl/mis-visitas-hoy?raw=true'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('[ApiService] getMisVisitasHoy Response: ${response.body}');
        
        final sessionError = await _handleResponse(response);
        if (sessionError != null) {
          return {'success': false, ...sessionError, 'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};
        }
        
        final data = jsonDecode(response.body);
        print('[ApiService] getMisVisitasHoy Data: $data');
        print('[ApiService] contadores: ${data['contadores']}');
        print('[ApiService] visitas: ${data['visitas']}');
        return {'success': true, ...data};
      }
      print('[ApiService] getMisVisitasHoy Status: ${response.statusCode}');
      
      final sessionError = await _handleResponse(response);
      if (sessionError != null) {
        return {'success': false, ...sessionError, 'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};
      }
      
      return {'success': false, 'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};
    } catch (e) {
      return {'success': false, 'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};
    }
  }

  Map<String, dynamic> _decryptPayload(Map<String, dynamic> encrypted, int userId) {
    try {
      final dataStr = encrypted['data'] as String;
      final decryptedBytes = base64.decode(dataStr);
      final decrypted = utf8.decode(decryptedBytes);
      return jsonDecode(decrypted);
    } catch (e) {
      return {'contadores': {'total_hoy': 0, 'dentro_edificio': 0, 'salieron_hoy': 0}, 'visitas': []};
    }
  }

  Future<bool> marcarSalida(int visitaId) async {
    if (_session == null) return false;

    try {
      final response = await http.patch(
        Uri.parse('$registerUrl/marcar-salida/$visitaId'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final sessionError = await _handleResponse(response);
        if (sessionError != null) return false;

        final data = jsonDecode(response.body);
        return data['status'] == 'success';
      }
      
      final sessionError = await _handleResponse(response);
      if (sessionError != null) return false;
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> eliminarVisita(int visitaId, {String? motivo}) async {
    if (_session == null) return {'success': false, 'message': 'Sesión no iniciada'};

    try {
      final uri = Uri.parse('$registerUrl/lecturas/$visitaId${motivo != null ? '?motivo=$motivo' : ''}');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getDestinos(int organizacionId) async {
    if (_session == null) {
      print('[ApiService] getDestinos - _session es null');
      return [];
    }
    
    print('[ApiService] getDestinos - orgId: $organizacionId');
    
    try {
      final response = await http.get(
        Uri.parse('$registerUrl/destinos?org_id=$organizacionId'),
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));

      print('[ApiService] getDestinos - status: ${response.statusCode}');

      final sessionError = await _handleResponse(response);
      if (sessionError != null) return [];

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('[ApiService] getDestinos - decoded: $decoded');
        
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
        return [];
      }
      return [];
    } catch (e) {
      print('[ApiService] getDestinos Error: $e');
      return [];
    }
  }

  void logout() {
    clearSession();
  }
}