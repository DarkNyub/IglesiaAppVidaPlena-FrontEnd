import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UiProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  double _textScaleFactor = 1.0;
  VisualDensity _visualDensity = VisualDensity.standard;

  // --- NUEVAS VARIABLES DE LA MOCHILA ---
  String _themeMode = 'system'; // 'light', 'dark', 'custom', 'system'
  Map<String, dynamic>? _customColors;

  double get textScaleFactor => _textScaleFactor;
  VisualDensity get visualDensity => _visualDensity;
  String get themeMode => _themeMode;
  Map<String, dynamic>? get customColors => _customColors;

  // Carga inicial desde el storage local (para el login y persistencia rápida)
  UiProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    // 1. Cargar tamaño de texto
    final scale = await _storage.read(key: 'ui_text_scale');
    if (scale != null) {
      _textScaleFactor = double.parse(scale);
    }

    // 2. Cargar modo de tema (Mochila)
    final theme = await _storage.read(key: 'theme_mode');
    if (theme != null) {
      _themeMode = theme;
    }

    // 3. Cargar colores personalizados (Mochila)
    final colorsString = await _storage.read(key: 'custom_colors');
    if (colorsString != null) {
      try {
        _customColors = jsonDecode(colorsString);
      } catch (_) {}
    }

    notifyListeners(); // ¡Avisa a la app para que se repinte de inmediato!
  }

  // Carga la configuración que viene de la NUBE (vía UserSession)
  void loadFromUserSession(Map<String, dynamic>? extraData) {
    if (extraData == null || extraData['ui_config'] == null) return;

    final config = extraData['ui_config'];

    // Sincronizar tamaño
    if (config['size_level'] != null) {
      _applySizeLevel(config['size_level'].toDouble());
    }

    // Sincronizar tema y guardarlo en local
    if (config['theme_mode'] != null) {
      _themeMode = config['theme_mode'];
      _storage.write(key: 'theme_mode', value: _themeMode);
    }

    if (config['colors'] != null) {
      _customColors = config['colors'];
      _storage.write(key: 'custom_colors', value: jsonEncode(_customColors));
    }

    notifyListeners();
  }

  // Guardar configuración desde la pantalla SettingsPage
  Future<void> updateThemeSettings({
    required String themeMode,
    Map<String, dynamic>? customColors,
  }) async {
    _themeMode = themeMode;
    await _storage.write(key: 'theme_mode', value: themeMode);

    if (customColors != null) {
      _customColors = customColors;
      await _storage.write(
        key: 'custom_colors',
        value: jsonEncode(customColors),
      );
    } else {
      _customColors = null;
      await _storage.delete(key: 'custom_colors');
    }

    notifyListeners();
  }

  // Lógica de 5 niveles para el Slider
  void setSizeFromLevel(double level) {
    _applySizeLevel(level);
    _storage.write(key: 'ui_text_scale', value: _textScaleFactor.toString());
    notifyListeners();
  }

  void _applySizeLevel(double level) {
    _textScaleFactor = 0.7 + (level * 0.15);

    if (level <= 2) {
      _visualDensity = VisualDensity.compact;
    } else if (level >= 4) {
      _visualDensity = const VisualDensity(horizontal: 0, vertical: 2);
    } else {
      _visualDensity = VisualDensity.standard;
    }
  }
}
