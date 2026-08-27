import 'package:flutter/material.dart';
import '../../data/services/auth_service.dart';
import '../../core/system_role_manager.dart';
import '../../core/app_theme_colors.dart';
import 'RegistryEvents/registry_event_pending_list_page.dart';
import 'admin/admin_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  bool loading = false;
  String? errorMessage;

  Future<void> login() async {
    if (userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      setState(() => errorMessage = "Por favor ingresa usuario y contraseña");
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final user = await _auth.login(
        userCtrl.text.trim(),
        passCtrl.text.trim(),
      );
      if (!mounted) return;

      // 🔥 APLICAMOS LA NORMALIZACIÓN AQUÍ TAMBIÉN
      final normalizedRole = SystemRoles.normalize(user.systemRole);

      if (normalizedRole == SystemRoles.superAdmin ||
          normalizedRole == SystemRoles.admin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const RegistryEventPendingListPage(),
          ),
        );
      }
    } catch (e) {
      setState(() => errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/logoRojo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  "Vida Plena Internacional",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: userCtrl,
                  style: TextStyle(color: colors.text),
                  cursorColor: colors.text,
                  decoration: InputDecoration(
                    labelText: "Usuario",
                    labelStyle: TextStyle(color: colors.text),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.iconBackground,
                          border: Border.all(
                            color: colors.iconBorder,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: colors.iconColor,
                          size: 20,
                        ),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.text),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: TextStyle(color: colors.text),
                  cursorColor: colors.text,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    labelStyle: TextStyle(color: colors.text),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.iconBackground,
                          border: Border.all(
                            color: colors.iconBorder,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: colors.iconColor,
                          size: 20,
                        ),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.text),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        color: colors.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.buttonBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.cardBorder, width: 1.5),
                      ),
                    ),
                    child: loading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colors.buttonText,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "INGRESAR",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.buttonText,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
