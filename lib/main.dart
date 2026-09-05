import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/services/auth_service.dart';
import 'core/user_session.dart';
import 'core/ui_provider.dart';
import 'core/connection_manager.dart';
import 'core/system_role_manager.dart';
import 'core/app_theme_colors.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/RegistryEvents/registry_event_pending_list_page.dart';
import 'presentation/pages/admin/admin_dashboard_page.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es', null);
    runApp(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => UiProvider())],
        child: const IglesiaApp(),
      ),
    );
  } catch (e) {
    print("🔥 ERROR FATAL EN MAIN: $e");
  }
}

class IglesiaApp extends StatelessWidget {
  const IglesiaApp({super.key});

  ThemeMode _getMaterialThemeMode(String mode) {
    if (mode == 'dark') return ThemeMode.dark;
    if (mode == 'light' || mode == 'custom') return ThemeMode.light;
    return ThemeMode.system;
  }

  ThemeData _buildDynamicTheme(UiProvider uiProvider, bool isSystemDark) {
    String themeMode = uiProvider.themeMode;
    if (themeMode == 'system') {
      themeMode = isSystemDark ? 'dark' : 'light';
    }

    final customColors = uiProvider.customColors;
    AppThemeColors appColors;
    if (themeMode == 'custom' && customColors != null) {
      appColors = AppThemeColors.custom(customColors);
    } else if (themeMode == 'dark') {
      appColors = AppThemeColors.dark();
    } else {
      appColors = AppThemeColors.light();
    }

    return ThemeData(
      useMaterial3: true,
      visualDensity: uiProvider.visualDensity,
      brightness: appColors.brightness,
      scaffoldBackgroundColor: appColors.background,
      extensions: [appColors],
      colorScheme: ColorScheme.fromSeed(
        seedColor: appColors.iconBackground,
        primary: appColors.iconBackground,
        secondary: appColors.buttonBackground,
        surface: appColors.background,
        onSurface: appColors.text,
        brightness: appColors.brightness,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: appColors.text),
        bodyMedium: TextStyle(color: appColors.text),
        bodySmall: TextStyle(color: appColors.text),
        titleLarge: TextStyle(
          color: appColors.text,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: appColors.text,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: TextStyle(
          color: appColors.text,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: appColors.cardBackground,
        foregroundColor: appColors.text,
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.inputBackground,
        labelStyle: TextStyle(color: appColors.text.withValues(alpha: 0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appColors.iconBackground, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: appColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: appColors.cardBorder, width: 1.5),
        ),
        elevation: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UiProvider>(
      builder: (context, uiProvider, child) {
        return MaterialApp(
          navigatorKey: ConnectionManager().navigatorKey,
          title: 'Vida Plena Internacional',
          debugShowCheckedModeBanner: false,
          themeMode: _getMaterialThemeMode(uiProvider.themeMode),
          theme: _buildDynamicTheme(uiProvider, false),
          darkTheme: _buildDynamicTheme(uiProvider, true),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(uiProvider.textScaleFactor),
              ),
              child: child!,
            );
          },
          home: const SessionGuard(),
        );
      },
    );
  }
}

class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key});
  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLogged = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final success = await _authService.tryAutoLogin();
    if (success) {
      if (mounted) {
        Provider.of<UiProvider>(
          context,
          listen: false,
        ).loadFromUserSession(UserSession().currentUser?.extraData);
      }
    }
    if (mounted) {
      setState(() {
        _isLogged = success;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if (_isLogged) {
      if (!UserSession().isLogged) return const LoginPage();

      // 🔥 APLICAMOS LA MAGIA DE LA NORMALIZACIÓN AQUÍ
      final rawRole = UserSession().role;
      final normalizedRole = SystemRoles.normalize(rawRole);

      // Si es superadmin o admin (independientemente de cómo esté escrito), lo mandamos al Dashboard
      if (normalizedRole == SystemRoles.superAdmin ||
          normalizedRole == SystemRoles.admin) {
        return const AdminDashboardPage();
      }
      return const RegistryEventPendingListPage();
    }
    return const LoginPage();
  }
}
