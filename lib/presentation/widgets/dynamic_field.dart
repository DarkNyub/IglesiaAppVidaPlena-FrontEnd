import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/generic_repository.dart';
import '../../core/constants/api_constants.dart';
import '../../core/app_theme_colors.dart'; // <--- LA MOCHILA

class DynamicFieldWidget extends StatefulWidget {
  final Map<String, dynamic> fieldConfig;
  final Function(String, dynamic) onValueChanged;

  const DynamicFieldWidget({
    super.key,
    required this.fieldConfig,
    required this.onValueChanged,
  });

  @override
  State<DynamicFieldWidget> createState() => _DynamicFieldWidgetState();
}

class _DynamicFieldWidgetState extends State<DynamicFieldWidget> {
  final TextEditingController _controller = TextEditingController();
  late GenericRepository _memberRepo;
  Future<List<dynamic>>? _membersFuture;
  int? _selectedMemberId;

  @override
  void initState() {
    super.initState();
    _memberRepo = GenericRepository(endpoint: ApiConstants.members);

    final String dataType = (widget.fieldConfig['dataType'] ?? 'TEXT')
        .toString()
        .toUpperCase();
    if (dataType == 'MEMBER_SELECTION') {
      _loadMembers();
    }
  }

  void _loadMembers() {
    setState(() {
      _membersFuture = _memberRepo.getAll();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- HELPER DE DISEÑO UNIFICADO ---
  InputDecoration _getSharedDecoration(
    String label,
    IconData prefix,
    AppThemeColors colors, {
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.text.withValues(alpha: 0.7)),
      helperText: helper,
      helperStyle: TextStyle(color: colors.text.withValues(alpha: 0.5)),
      filled: true,
      fillColor: colors.inputBackground,
      prefixIcon: Icon(prefix, color: colors.text.withValues(alpha: 0.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.inputBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.errorColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final String dataType = (widget.fieldConfig['dataType'] ?? 'TEXT')
        .toString()
        .toUpperCase();

    String? labelRaw = widget.fieldConfig['label'];
    if (labelRaw == null || labelRaw.trim().isEmpty) {
      labelRaw = widget.fieldConfig['name'];
    }

    final String label = labelRaw ?? 'Campo';
    final String keyName = widget.fieldConfig['name'];
    final bool isRequired = widget.fieldConfig['isRequired'] ?? false;
    final String? memberLogic = widget.fieldConfig['memberSelectionLogic'];

    switch (dataType) {
      case 'INT':
      case 'NUMBER':
      case 'INTEGER':
        return _buildEnhancedNumberField(
          label,
          keyName,
          colors,
          isDecimal: false,
        );
      case 'DECIMAL':
      case 'FLOAT':
      case 'MONEY':
        return _buildEnhancedNumberField(
          label,
          keyName,
          colors,
          isDecimal: true,
        );
      case 'BOOL':
      case 'BOOLEAN':
        return _buildCheckbox(label, keyName, colors);
      case 'DATE':
      case 'DATETIME':
        return _buildDateField(label, keyName, isRequired, colors);
      case 'MEMBER_SELECTION':
        return _buildMemberSelector(
          label,
          keyName,
          isRequired,
          memberLogic,
          colors,
        );
      case 'TEXT':
      case 'STRING':
      default:
        return _buildTextField(label, keyName, isRequired, colors);
    }
  }

  // --- 1. TEXTO ---
  Widget _buildTextField(
    String label,
    String key,
    bool required,
    AppThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controller,
        style: TextStyle(color: colors.text),
        decoration: _getSharedDecoration(
          label + (required ? ' *' : ''),
          Icons.text_fields,
          colors,
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Requerido' : null
            : null,
        onChanged: (val) => widget.onValueChanged(key, val),
      ),
    );
  }

  // --- 2. FECHA ---
  Widget _buildDateField(
    String label,
    String key,
    bool required,
    AppThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controller,
        readOnly: true,
        style: TextStyle(color: colors.text),
        decoration:
            _getSharedDecoration(
              label + (required ? ' *' : ''),
              Icons.calendar_today,
              colors,
            ).copyWith(
              suffixIcon: Icon(
                Icons.arrow_drop_down,
                color: colors.text.withValues(alpha: 0.5),
              ),
            ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Requerido' : null
            : null,
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: colors.iconBackground,
                  onPrimary: colors.iconColor,
                  surface: colors.cardBackground,
                  onSurface: colors.text,
                ),
              ),
              child: child!,
            ),
          );
          if (pickedDate != null) {
            String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
            setState(() => _controller.text = formattedDate);
            widget.onValueChanged(key, formattedDate);
          }
        },
      ),
    );
  }

  // --- 3. BOOLEANO ---
  Widget _buildCheckbox(String label, String key, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(unselectedWidgetColor: colors.inputBorder),
        child: CheckboxListTile(
          title: Text(label, style: TextStyle(color: colors.text)),
          value: _controller.text == 'true',
          activeColor: colors.iconBackground,
          checkColor: colors.iconColor,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool? val) {
            setState(() => _controller.text = val.toString());
            widget.onValueChanged(key, val ?? false);
          },
        ),
      ),
    );
  }

  // --- 4. NUMÉRICO MEJORADO ---
  Widget _buildEnhancedNumberField(
    String label,
    String key,
    AppThemeColors colors, {
    bool isDecimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _controller,
              style: TextStyle(color: colors.text),
              keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
              inputFormatters: [
                isDecimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))
                    : FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: _getSharedDecoration(label, Icons.numbers, colors),
              onChanged: (val) {
                final numVal = isDecimal
                    ? double.tryParse(val)
                    : int.tryParse(val);
                if (numVal != null) widget.onValueChanged(key, numVal);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 55, // Alineado con el input
            decoration: BoxDecoration(
              color: colors.inputBackground,
              border: Border.all(color: colors.inputBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: colors.iconBackground),
                  onPressed: () => _modifyValue(-1, key, isDecimal),
                ),
                Container(width: 1, color: colors.inputBorder),
                IconButton(
                  icon: Icon(Icons.add, color: colors.iconBackground),
                  onPressed: () => _modifyValue(1, key, isDecimal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _modifyValue(int sign, String key, bool isDecimal) {
    double current = double.tryParse(_controller.text) ?? 0;
    double newVal = current + (sign * 1);
    if (newVal < 0) newVal = 0;

    setState(() {
      _controller.text = isDecimal
          ? newVal.toStringAsFixed(2)
          : newVal.toInt().toString();
    });
    widget.onValueChanged(key, isDecimal ? newVal : newVal.toInt());
  }

  // --- 5. SELECTOR DE MIEMBROS DINÁMICO ---
  Widget _buildMemberSelector(
    String label,
    String key,
    bool required,
    String? logic,
    AppThemeColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FutureBuilder<List<dynamic>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return InputDecorator(
              decoration: _getSharedDecoration(
                label,
                Icons.hourglass_empty,
                colors,
              ),
              child: Text(
                "Cargando miembros...",
                style: TextStyle(color: colors.text.withValues(alpha: 0.5)),
              ),
            );
          }

          if (snapshot.hasError) {
            return InputDecorator(
              decoration: _getSharedDecoration(label, Icons.error, colors),
              child: Text(
                "Error al cargar datos",
                style: TextStyle(color: colors.errorColor),
              ),
            );
          }

          // --- 🧟‍♂️ FILTRO ANTI-ZOMBIES APLICADO AQUÍ ---
          final members =
              (snapshot.data ?? [])
                  .where((m) => m['isDeleted'] != true) // Solo activos
                  .toList()
                ..sort(
                  (a, b) => (a['firstName'] ?? '').toString().compareTo(
                    (b['firstName'] ?? '').toString(),
                  ),
                ); // Ordenados

          if (members.isEmpty) {
            return InputDecorator(
              decoration: _getSharedDecoration(label, Icons.person_off, colors),
              child: Text(
                "No hay miembros activos disponibles",
                style: TextStyle(color: colors.text.withValues(alpha: 0.5)),
              ),
            );
          }

          return DropdownButtonFormField<int>(
            value: _selectedMemberId,
            dropdownColor: colors.cardBackground,
            style: TextStyle(color: colors.text),
            decoration: _getSharedDecoration(
              label + (required ? ' *' : ''),
              Icons.person_search,
              colors,
              helper: logic != null ? "Filtro: $logic" : null,
            ),
            items: members.map((m) {
              final name = "${m['firstName']} ${m['lastName']}";
              return DropdownMenuItem<int>(
                value: m['id'] as int,
                child: Text(
                  name.length > 30 ? "${name.substring(0, 27)}..." : name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedMemberId = val);
              if (val != null) widget.onValueChanged(key, val);
            },
            validator: required
                ? (v) => v == null ? 'Seleccione un miembro' : null
                : null,
          );
        },
      ),
    );
  }
}
