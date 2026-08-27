import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/environment.dart'; // <--- Importamos la config central
import '../../core/connection_manager.dart'; // <--- IMPORTAR

class ApiService {
  // Lógica inteligente para determinar la URL
  static String get _baseUrl {
    // Si quisieras forzar producción, descomenta:
    return Environment.baseUrl;

    // if (kIsWeb) return Environment.devUrl;

    // Truco para Android Emulator (localhost no funciona, se usa 10.0.2.2)
    // if (Platform.isAndroid) {
    //   return Environment.devUrl.replaceFirst("localhost", "10.0.2.2");
    // }

    // return Environment.devUrl; // iOS y otros
  }

  final _storage = const FlutterSecureStorage();

  // --- LOGS ---
  void _log(String title, dynamic data) {
    if (kDebugMode) {
      print('--- $title ---');
      print(data);
      print('----------------');
    }
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Método centralizado para manejar errores HTTP
  void _checkConnectionError(dynamic error) {
    final e = error.toString().toLowerCase();
    // Detectar errores típicos de servidor caído o sin internet
    if (e.contains("socketexception") ||
        e.contains("connection refused") ||
        e.contains("network is unreachable") ||
        e.contains("clientexception")) {
      // DISPARAR EL KILL SWITCH
      ConnectionManager().handleConnectionError();
    }
  }
  // --- MÉTODOS HTTP ---

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final token = await _getToken();
    _log('GET REQ', url);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      _log('GET RES (${response.statusCode})', response.body);
      return _handleResponse(response);
    } catch (e) {
      _log('GET ERR', e);
      _checkConnectionError(e); // <--- AGREGAR ESTO
      throw Exception('Error de conexión: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final token = await _getToken();
    _log('POST REQ', data);

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      _log('POST RES (${response.statusCode})', response.body);
      return _handleResponse(response);
    } catch (e) {
      _log('POST ERR', e);
      _checkConnectionError(e); // <--- AGREGAR ESTO
      throw Exception('Error de conexión: $e');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final token = await _getToken();
    _log('PUT REQ', data);

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      _log('PUT RES (${response.statusCode})', response.body);
      return _handleResponse(response);
    } catch (e) {
      _log('PUT ERR', e);
      _checkConnectionError(e); // <--- AGREGAR ESTO
      throw Exception('Error: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final token = await _getToken();
    _log('DEL REQ', url);

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      _log('DEL RES (${response.statusCode})', response.body);
      return _handleResponse(response);
    } catch (e) {
      _log('DEL ERR', e);

      throw Exception('Error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return true;
      // Decodificación segura UTF-8
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      String msg = 'Error ${response.statusCode}';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['message'] != null)
          msg = body['message'];
        else if (body['title'] != null)
          msg = body['title'];
      } catch (e) {
        _checkConnectionError(e); // <--- AGREGAR ESTO
      }
      throw Exception(msg);
    }
  }
}
