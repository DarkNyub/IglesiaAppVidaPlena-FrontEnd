import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/models/user.dart';
import 'connection_manager.dart';
import '../presentation/pages/login_page.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  User? _currentUser;
  final _storage = const FlutterSecureStorage(); // Agregamos acceso al storage

  User? get currentUser => _currentUser;
  String? get role => _currentUser?.systemRole;
  bool get isLogged => _currentUser != null;

  void setSession(User user) {
    _currentUser = user;
    print("✅ Sesión activa: ${user.username} (Rol: ${user.systemRole})");
  }

  void clearSession() {
    _currentUser = null;
    print("🔒 Sesión en memoria borrada");
  }

  // 🔥 KILL SWITCH: Limpia todo y redirige al Login
  Future<void> forceLogout() async {
    clearSession();

    // 1. Destruimos el token caducado del almacenamiento seguro
    await _storage.delete(key: 'jwt_token');
    print("🗑️ Token expirado eliminado del dispositivo");

    // 2. Usamos el navigator global para expulsar al usuario a la fuerza
    final context = ConnectionManager().navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false, // Destruye todo el historial de pantallas hacia atrás
      );
    }
  }
}
