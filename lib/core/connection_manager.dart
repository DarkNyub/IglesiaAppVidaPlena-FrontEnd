import 'dart:async';
import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';
import '../presentation/pages/login_page.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  // Necesitamos acceso al contexto global para mostrar dialogos sin importar donde estemos
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isShowingDialog = false;

  void handleConnectionError() {
    if (_isShowingDialog) return; // Si ya se muestra, no hacer nada
    _isShowingDialog = true;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Mostrar Diálogo Bloqueante
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando afuera
      builder: (ctx) => _CountdownDialog(
        onTimeout: () async {
          _isShowingDialog = false;
          Navigator.of(ctx).pop(); // Cerrar diálogo

          // Cerrar sesión y mandar al Login
          final auth = AuthService();
          await auth.logout();

          // Redirigir al Login limpiando historial
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
      ),
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  final VoidCallback onTimeout;
  const _CountdownDialog({required this.onTimeout});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _seconds = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 1) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Bloquear botón atrás físico
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 10),
            Text("Conexión Perdida"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "No se puede conectar con el servidor.\nPor seguridad, se cerrará la sesión en:",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              "$_seconds",
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Text("segundos", style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Opción de "Salir Ya"
              _timer?.cancel();
              widget.onTimeout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Salir Ahora",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
