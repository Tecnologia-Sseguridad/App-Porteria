import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';
import '../models/user.dart';

class StorageService {
  static const String _userKey = 'user_data';
  static const String _scansKey = 'local_scans';
  static const String _sessionKey = 'session_data';
  static const String _accessTokenKey = 'access_token';

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  Future<void> saveSession({
    required int usuarioId,
    required int organizacionId,
    required String accessToken,
    required String cryptoKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', usuarioId);
    await prefs.setInt('organizacion_id', organizacionId);
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString('crypto_key', cryptoKey);
  }

  Future<int> getUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('usuario_id') ?? 0;
  }

  Future<int> getOrganizacionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('organizacion_id') ?? 0;
  }

  Future<String> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey) ?? '';
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_sessionKey);
    await prefs.remove(_accessTokenKey);
  }

  Future<void> saveLocalScans(List<ScanResult> scans) async {
    final prefs = await SharedPreferences.getInstance();
    final scansJson = scans.map((s) => s.toJson()).toList();
    await prefs.setString(_scansKey, jsonEncode(scansJson));
  }

  Future<List<ScanResult>> getLocalScans() async {
    final prefs = await SharedPreferences.getInstance();
    final scansData = prefs.getString(_scansKey);
    if (scansData != null) {
      final List<dynamic> scansJson = jsonDecode(scansData);
      return scansJson.map((s) => ScanResult.fromJson(s)).toList();
    }
    return [];
  }

  Future<void> addLocalScan(ScanResult scan) async {
    final scans = await getLocalScans();
    scans.insert(0, scan);
    await saveLocalScans(scans);
  }

  Future<void> clearLocalScans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scansKey);
  }
}