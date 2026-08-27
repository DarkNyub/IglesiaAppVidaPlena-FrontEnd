import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ui_provider.dart';
import '../../core/user_session.dart';
import '../../core/app_theme_colors.dart';
import '../../data/services/api_service.dart'; // <--- IMPORTACIÓN FALTANTE AGREGADA
import '../../data/repositories/generic_repository.dart';
import '../widgets/master_layout.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;

  String _selectedThemeMode = 'dark';
  double _sizeLevel = 3.0;

  // LAS 13 VARIABLES CUSTOMIZABLES
  Color _customBg = const Color(0xFF2C2C2C);
  Color _customText = Colors.white;
  Color _customCardBg = const Color(0xFF1E1E1E);
  Color _customCardBorder = Colors.white;
  Color _customIcon = Colors.orange;
  Color _customIconBg = Colors.white;
  Color _customIconBorder = Colors.white;
  Color _customInputColor = Colors.blueAccent;
  Color _customBtnBg = const Color(0xFF1565C0);

  // Semánticos
  Color _customSuccess = Colors.green;
  Color _customError = Colors.red;
  Color _customWarning = Colors.orange;
  Color _customInfo = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
  }

  void _loadInitialValues() {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);

    setState(() {
      // Leemos primero de lo que ya tiene cargado la memoria local
      _selectedThemeMode = uiProvider.themeMode == 'system'
          ? 'dark'
          : uiProvider.themeMode;

      // Calculamos a qué "nivel" (1 a 5) corresponde el textScaleFactor actual
      _sizeLevel = ((uiProvider.textScaleFactor - 0.7) / 0.15)
          .clamp(1.0, 5.0)
          .toDouble();

      final c = uiProvider.customColors;
      if (c != null) {
        _customBg = Color(c['bg'] ?? _customBg.value);
        _customText = Color(c['text'] ?? _customText.value);
        _customCardBg = Color(c['cardBg'] ?? _customCardBg.value);
        _customCardBorder = Color(c['cardBorder'] ?? _customCardBorder.value);
        _customIcon = Color(c['icon'] ?? _customIcon.value);
        _customIconBg = Color(c['iconBg'] ?? _customIconBg.value);
        _customIconBorder = Color(c['iconBorder'] ?? _customIconBorder.value);
        _customInputColor = Color(c['input'] ?? _customInputColor.value);
        _customBtnBg = Color(c['btnBg'] ?? _customBtnBg.value);
        _customSuccess = Color(c['success'] ?? _customSuccess.value);
        _customError = Color(c['error'] ?? _customError.value);
        _customWarning = Color(c['warning'] ?? _customWarning.value);
        _customInfo = Color(c['info'] ?? _customInfo.value);
      }
    });
  }

  AppThemeColors get _previewColors {
    if (_selectedThemeMode == 'light') return AppThemeColors.light();
    if (_selectedThemeMode == 'dark') return AppThemeColors.dark();

    return AppThemeColors.custom({
      "bg": _customBg.value,
      "text": _customText.value,
      "cardBg": _customCardBg.value,
      "cardBorder": _customCardBorder.value,
      "icon": _customIcon.value,
      "iconBg": _customIconBg.value,
      "iconBorder": _customIconBorder.value,
      "input": _customInputColor.value,
      "btnBg": _customBtnBg.value,
      "success": _customSuccess.value,
      "error": _customError.value,
      "warning": _customWarning.value,
      "info": _customInfo.value,
    });
  }

  Future<void> _saveSettings() async {
    final user = UserSession().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final uiConfig = {
        "theme_mode": _selectedThemeMode,
        "size_level": _sizeLevel,
      };

      Map<String, dynamic>? customColorsPayload;

      if (_selectedThemeMode == 'custom') {
        customColorsPayload = {
          "bg": _customBg.value,
          "text": _customText.value,
          "cardBg": _customCardBg.value,
          "cardBorder": _customCardBorder.value,
          "icon": _customIcon.value,
          "iconBg": _customIconBg.value,
          "iconBorder": _customIconBorder.value,
          "input": _customInputColor.value,
          "btnBg": _customBtnBg.value,
          "success": _customSuccess.value,
          "error": _customError.value,
          "warning": _customWarning.value,
          "info": _customInfo.value,
        };
        uiConfig["colors"] = customColorsPayload;
      }

      // ========================================================
      // SOLUCIÓN AL FANTASMA BORRA-DATOS (Ahora con API SERVICE importado)
      // ========================================================
      final api = ApiService();

      // 1. Traemos al miembro COMPLETO de la base de datos
      final currentMemberFromDb = await api.get('members/${user.memberId}');

      if (currentMemberFromDb is Map<String, dynamic>) {
        // 2. Modificamos SOLO su extra_data
        Map<String, dynamic> currentExtra = Map.from(
          currentMemberFromDb['extraData'] ?? {},
        );
        currentExtra['ui_config'] = uiConfig;

        // 3. Se lo reasignamos al objeto completo
        currentMemberFromDb['extraData'] = currentExtra;

        // 4. Mandamos a guardar TODO el miembro intacto (con sus nombres y apellidos)
        await api.put('members/${user.memberId}', currentMemberFromDb);

        // Actualizamos la sesión en memoria
        user.extraData = currentExtra;
      }
      // ========================================================

      if (mounted) {
        final provider = Provider.of<UiProvider>(context, listen: false);
        provider.setSizeFromLevel(_sizeLevel);
        await provider.updateThemeSettings(
          themeMode: _selectedThemeMode,
          customColors: customColorsPayload,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "¡Configuración guardada exitosamente!",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _previewColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error al guardar: $e",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _previewColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final previewScale = 0.7 + (_sizeLevel * 0.15);
    final preview = _previewColors;

    return MasterLayout(
      title: "Configuración Visual",
      mode: PageMode.form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Apariencia",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),

          SegmentedButton<String>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return colors.iconBackground.withValues(alpha: 0.2);
                }
                return colors.cardBackground;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return colors.iconBackground;
                }
                return colors.text.withValues(alpha: 0.7);
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: colors.cardBorder),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: 'light',
                label: Text('Claro'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: 'dark',
                label: Text('Oscuro'),
                icon: Icon(Icons.dark_mode),
              ),
              ButtonSegment(
                value: 'custom',
                label: Text('Custom'),
                icon: Icon(Icons.palette),
              ),
            ],
            selected: {_selectedThemeMode},
            onSelectionChanged: (set) =>
                setState(() => _selectedThemeMode = set.first),
          ),

          if (_selectedThemeMode == 'custom') ...[
            const SizedBox(height: 25),
            Text(
              "Personalización Avanzada",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 15),

            Text(
              "Estructura y Textos",
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorRow(
              "Fondo General",
              _customBg,
              (c) => setState(() => _customBg = c),
              colors,
            ),
            _buildColorRow(
              "Textos Principales",
              _customText,
              (c) => setState(() => _customText = c),
              colors,
            ),
            _buildColorRow(
              "Fondo de Tarjetas",
              _customCardBg,
              (c) => setState(() => _customCardBg = c),
              colors,
            ),
            _buildColorRow(
              "Borde de Tarjetas",
              _customCardBorder,
              (c) => setState(() => _customCardBorder = c),
              colors,
            ),

            Divider(height: 30, color: colors.cardBorder),
            Text(
              "Íconos",
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorRow(
              "Color de Íconos",
              _customIcon,
              (c) => setState(() => _customIcon = c),
              colors,
            ),
            _buildColorRow(
              "Fondo de Íconos",
              _customIconBg,
              (c) => setState(() => _customIconBg = c),
              colors,
            ),
            _buildColorRow(
              "Borde de Íconos",
              _customIconBorder,
              (c) => setState(() => _customIconBorder = c),
              colors,
            ),

            Divider(height: 30, color: colors.cardBorder),
            Text(
              "Formularios y Botones",
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorRow(
              "Acento en Inputs",
              _customInputColor,
              (c) => setState(() => _customInputColor = c),
              colors,
            ),
            _buildColorRow(
              "Fondo de Botones",
              _customBtnBg,
              (c) => setState(() => _customBtnBg = c),
              colors,
            ),

            Divider(height: 30, color: colors.cardBorder),
            Text(
              "Colores Semánticos (Estados)",
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildColorRow(
              "Éxito (Activo)",
              _customSuccess,
              (c) => setState(() => _customSuccess = c),
              colors,
            ),
            _buildColorRow(
              "Error (Inactivo)",
              _customError,
              (c) => setState(() => _customError = c),
              colors,
            ),
            _buildColorRow(
              "Advertencia",
              _customWarning,
              (c) => setState(() => _customWarning = c),
              colors,
            ),
            _buildColorRow(
              "Información",
              _customInfo,
              (c) => setState(() => _customInfo = c),
              colors,
            ),
          ],

          const SizedBox(height: 40),
          Text(
            "Tamaño y Densidad (Nivel 1-5)",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          Slider(
            value: _sizeLevel,
            min: 1,
            max: 5,
            divisions: 4,
            label: "Nivel ${_sizeLevel.toInt()}",
            activeColor: colors.iconBackground,
            inactiveColor: colors.iconBackground.withValues(alpha: 0.2),
            onChanged: (v) => setState(() => _sizeLevel = v),
          ),

          Divider(height: 40, color: colors.cardBorder),
          Text(
            "Vista Previa:",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),

          // --- VISTA PREVIA ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: preview.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: preview.text.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Card(
                  color: preview.cardBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: preview.cardBorder, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: preview.iconBackground,
                            border: Border.all(color: preview.iconBorder),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: preview.iconColor,
                            size: 24 * previewScale,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hermano Juan",
                                style: TextStyle(
                                  color: preview.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16 * previewScale,
                                ),
                              ),
                              Text(
                                "Líder de Red",
                                style: TextStyle(
                                  color: preview.text.withValues(alpha: 0.7),
                                  fontSize: 13 * previewScale,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: preview.successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: preview.successColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            "ACTIVO",
                            style: TextStyle(
                              fontSize: 10 * previewScale,
                              fontWeight: FontWeight.bold,
                              color: preview.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: preview.inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: preview.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        color: preview.text.withValues(alpha: 0.6),
                        size: 20 * previewScale,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Campo de ejemplo...",
                        style: TextStyle(
                          color: preview.text.withValues(alpha: 0.7),
                          fontSize: 14 * previewScale,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 45 * previewScale,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: preview.buttonBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "ACCIÓN DE PRUEBA",
                      style: TextStyle(
                        color: preview.buttonText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14 * previewScale,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // BOTÓN GUARDAR
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : Icon(Icons.cloud_upload, color: colors.buttonText),
              label: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: colors.buttonText,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "GUARDAR EN LA NUBE",
                      style: TextStyle(
                        color: colors.buttonText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.buttonBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.cardBorder),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorRow(
    String label,
    Color current,
    Function(Color) onSelect,
    AppThemeColors appColors,
  ) {
    final colorsList = [
      Colors.white,
      Colors.black,
      const Color(0xFF121212),
      const Color(0xFF1E1E1E),
      const Color(0xFFF9F6EE),
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.grey,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: appColors.text.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colorsList.map((c) {
              final isSelected = current.value == c.value;
              return GestureDetector(
                onTap: () => onSelect(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 12, bottom: 10),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? appColors.iconBackground
                          : appColors.text.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
