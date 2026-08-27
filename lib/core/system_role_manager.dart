import 'package:flutter/material.dart';
import 'user_session.dart';

/// 🛡️ DICCIONARIO DE ROLES DEL SISTEMA
class SystemRoles {
  // Claves maestras internas (siempre en minúscula y sin espacios)
  static const String superAdmin = 'superadmin';
  static const String admin = 'admin';
  static const String lider = 'lider';
  static const String user = 'user';
  static const String report = 'report';

  /// 🪄 MOTOR DE NORMALIZACIÓN ULTRA ROBUSTO:
  /// Limpia cualquier basura, espacio o tilde que venga de la Base de Datos.
  /// Ej: "Súper Admin" -> "superadmin"
  static String normalize(String? rawRole) {
    if (rawRole == null || rawRole.trim().isEmpty) return '';
    return rawRole
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(r'\s+'),
          '',
        ) // Elimina todos los espacios intermedios
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u');
  }
}

/// 🛡️ WIDGET GESTOR DE ACCESOS
class SystemRoleManager extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final Widget? fallback;
  final bool absorbPointer;

  const SystemRoleManager({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
    this.absorbPointer = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Obtenemos el rol en bruto desde la sesión
    final rawUserRole = UserSession().role;

    // Si no hay sesión activa, bloqueamos de inmediato
    if (rawUserRole == null) return _handleDenied();

    // 2. Pasamos el rol del usuario por la lavadora (Normalización)
    final normalizedUserRole = SystemRoles.normalize(rawUserRole);

    // 3. Verificamos si el rol normalizado hace match con la lista de permitidos
    final hasAccess = allowedRoles.any((role) {
      return SystemRoles.normalize(role) == normalizedUserRole;
    });

    // 4. Conceder o denegar acceso
    if (hasAccess) return child;
    return _handleDenied();
  }

  Widget _handleDenied() {
    // Si queremos mostrar el elemento pero bloqueado y grisáceo (Modo ReadOnly visual)
    if (absorbPointer) {
      return AbsorbPointer(child: Opacity(opacity: 0.5, child: child));
    }
    // Si queremos desaparecer el elemento por completo
    return fallback ?? const SizedBox.shrink();
  }
}
