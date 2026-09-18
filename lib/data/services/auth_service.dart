import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/user_session.dart'; // <--- IMPORTAR
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final _storage = const FlutterSecureStorage();

  // Ya no necesitamos guardar _currentUser aquí, usamos el Session

  Future<User> login(String username, String password) async {
    try {
      final response = await _api.post('auth/login', {
        'username': username,
        'password': password,
      });

      final user = User.fromJson(response);

      // 1. GUARDAR EN DISCO (Persistencia)
      await _storage.write(key: 'jwt_token', value: user.token);
      await _storage.write(key: 'memberId', value: user.memberId.toString());
      await _storage.write(key: 'systemRole', value: user.systemRole);
      await _storage.write(key: 'username', value: user.username);
      await _storage.write(key: 'userId', value: user.id.toString());
      await _storage.write(key: 'FirstName', value: user.FirstName);
      await _storage.write(key: 'LastName', value: user.LastName);
      await _storage.write(
        key: 'photoUrl',
        value: user.photoUrl ?? '../assets/images/logo.png',
      );

      // 2. GUARDAR EN MEMORIA (Tu idea)
      UserSession().setSession(user);

      return user;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    UserSession().clearSession(); // Limpiamos memoria
    await _storage.deleteAll(); // Limpiamos disco
  }

  // Método extra: Intentar recuperar sesión si cierras y abres la app
  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return false;

    // Recuperamos datos guardados
    final role = await _storage.read(key: 'systemRole');
    final username = await _storage.read(key: 'username');
    final userId = await _storage.read(key: 'userId');
    final memberId = await _storage.read(key: 'memberId');
    final firstName = await _storage.read(key: 'FirstName');
    final lastName = await _storage.read(key: 'LastName');
    final photoUrl = await _storage.read(key: 'photoUrl');

    if (role != null && username != null) {
      final user = User(
        id: int.parse(userId!),
        memberId: int.parse(memberId!),
        username: username,
        systemRole: role,
        token: token,
        expiresAt: DateTime.now().add(
          const Duration(hours: 12),
        ), // O ajusta según tu token
        FirstName: firstName ?? '',
        LastName: lastName ?? '',
        photoUrl: photoUrl ?? '../assets/images/logo.png',
      );
      UserSession().setSession(user);
      return true;
    }
    return false;
  }
}
