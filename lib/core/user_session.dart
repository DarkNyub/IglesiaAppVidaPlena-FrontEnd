import '../data/models/user.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  User? _currentUser;

  User? get currentUser => _currentUser;
  String? get role => _currentUser?.systemRole;
  bool get isLogged => _currentUser != null;

  void setSession(User user) {
    _currentUser = user;
    print("✅ Sesión activa: ${user.username} (Rol: ${user.systemRole})");
  }

  void clearSession() {
    _currentUser = null;
    print("🔒 Sesión cerrada");
  }
}
