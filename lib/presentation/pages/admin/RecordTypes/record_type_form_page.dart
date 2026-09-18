// ... [MANTÉN TUS IMPORTS Y LA CLASE STATEFUL WIDGET IGUAL] ...
import 'package:flutter/material.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';

class RecordTypeFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingRecordType;
  const RecordTypeFormPage({super.key, this.existingRecordType});

  @override
  State<RecordTypeFormPage> createState() => _RecordTypeFormPageState();
}

class _RecordTypeFormPageState extends State<RecordTypeFormPage> {
  // ... [MANTÉN TUS VARIABLES IGUAL HASTA EL MÉTODO _loadCatalogs] ...
  final _repository = GenericRepository(endpoint: ApiConstants.recordTypes);
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _targetOrgTypeId;
  int? _targetRoleId;

  List<dynamic> _orgTypes = [];
  List<dynamic> _churchRoles = [];
  List<Map<String, dynamic>> _fields = [];

  bool _isSaving = false;
  bool _isLoadingInitial = true;

  final List<String> _dataTypes = [
    'STRING',
    'INT',
    'DECIMAL',
    'BOOL',
    'DATE',
    'IMAGE_GALLERY',
    'MEMBER_SELECTION',
    'FORMULA',
  ];

  int _tempIdCounter = 0;
  String _generateUiId() {
    _tempIdCounter++;
    return "${DateTime.now().millisecondsSinceEpoch}_$_tempIdCounter";
  }

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final responses = await Future.wait([
        _api.get(ApiConstants.organizationTypes),
        _api.get(ApiConstants.churchRoles),
      ]);

      if (mounted) {
        setState(() {
          // --- 🧟‍♂️ FILTRO ANTI-ZOMBIES APLICADO ---
          final currentTargetOrg =
              widget.existingRecordType?['targetOrganizationTypeId'];
          _orgTypes = responses[0] is List
              ? (responses[0] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          (currentTargetOrg != null &&
                              e['id'] == currentTargetOrg),
                    )
                    .toList()
              : [];

          final currentTargetRole =
              widget.existingRecordType?['targetFunctionRoleId'];
          _churchRoles = responses[1] is List
              ? (responses[1] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          (currentTargetRole != null &&
                              e['id'] == currentTargetRole),
                    )
                    .toList()
              : [];

          if (widget.existingRecordType != null) {
            _initFormData();
          }
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  // ... [COPIA AQUÍ EL RESTO DEL ARCHIVO record_type_form_page.dart EXACTAMENTE COMO ESTABA DESDE _initFormData HACIA ABAJO] ...
  void _initFormData() {
    final e = widget.existingRecordType!;
    _nameCtrl.text = e['name'] ?? '';
    _descCtrl.text = e['description'] ?? '';
    _targetOrgTypeId = e['targetOrganizationTypeId'];
    _targetRoleId = e['targetFunctionRoleId'];

    final rawFields = e['fields'];
    if (rawFields != null && rawFields is List) {
      _fields = List<Map<String, dynamic>>.from(
        rawFields.map((x) => Map<String, dynamic>.from(x)),
      );
      for (var f in _fields) {
        f['uiId'] = _generateUiId();
        // Migración visual de IMAGE a IMAGE_GALLERY si ya existía
        if (f['dataType'] == 'IMAGE') f['dataType'] = 'IMAGE_GALLERY';
      }
    }
  }

  void _showFieldHelpDialog() {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.cardBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: colors.iconBackground),
            const SizedBox(width: 10),
            Text(
              "Guía de Campos",
              style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpItem(
                "Etiqueta Visual",
                "Es el nombre que verá el usuario al llenar el reporte. Ej: 'Fotos de la Evidencia'.",
                colors,
              ),
              _helpItem(
                "Variable BD",
                "Nombre técnico interno (sin espacios ni acentos). Ej: 'fotos_evidencia'. Se usa para exportar datos.",
                colors,
              ),
              _helpItem(
                "Tipo de Dato",
                "Define qué puede ingresar el usuario (Texto, Números, Fechas o una Galería de múltiples imágenes).",
                colors,
              ),
              _helpItem(
                "Obligatorio",
                "Si se marca, el usuario no podrá guardar el reporte sin haber completado este campo.",
                colors,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Entendido",
              style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String desc, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            desc,
            style: TextStyle(
              color: colors.text.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _addField() {
    setState(() {
      _fields.add({
        'uiId': _generateUiId(),
        'name': '',
        'label': '',
        'dataType': 'STRING',
        'isRequired': false,
        'memberSelectionLogic': null,
        'fieldOrder': _fields.length + 1,
      });
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Agrega al menos un campo al formulario",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    List<Map<String, dynamic>> cleanFields = [];
    for (int i = 0; i < _fields.length; i++) {
      var f = Map<String, dynamic>.from(_fields[i]);
      f['fieldOrder'] = i + 1;
      f.remove('uiId');
      if (widget.existingRecordType != null) {
        f['recordTypeId'] = widget.existingRecordType!['id'];
      }
      cleanFields.add(f);
    }

    final payload = {
      "id": widget.existingRecordType?['id'],
      "name": _nameCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "targetOrganizationTypeId": _targetOrgTypeId,
      "targetFunctionRoleId": _targetRoleId,
      "fields": cleanFields,
    };

    try {
      if (widget.existingRecordType == null) {
        await _api.post(ApiConstants.recordTypes, payload);
      } else {
        await _api.put(
          '${ApiConstants.recordTypes}/${widget.existingRecordType!['id']}',
          payload,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Formulario guardado",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: TextStyle(color: colors.text)),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final sectionTitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: colors.text.withValues(alpha: 0.8),
    );

    return MasterLayout(
      title: widget.existingRecordType != null
          ? "Editar Formulario"
          : "Nuevo Formulario",
      mode: PageMode.form,
      onSave: _save,
      isSaving: _isSaving,
      child: _isLoadingInitial
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Configuración General", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    AppTextField(
                      controller: _nameCtrl,
                      label: "Nombre del Formulario",
                      prefixIcon: Icons.assignment,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),

                    AppTextField(
                      controller: _descCtrl,
                      label: "Descripción",
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),

                    // TARGETING EN FILAS SEPARADAS
                    Row(
                      children: [
                        Expanded(
                          child: AppDropdown<int>(
                            value: _targetOrgTypeId,
                            label: "Aplica a (Tipo Org.)",
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text(
                                  "(Global)",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              ..._orgTypes.map(
                                (t) => DropdownMenuItem<int>(
                                  value: t['id'],
                                  child: Text(t['name']),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _targetOrgTypeId = val),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10), // Espacio entre rows

                    Row(
                      children: [
                        Expanded(
                          child: AppDropdown<int>(
                            value: _targetRoleId,
                            label: "Visible para (Rol)",
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text(
                                  "(Todos)",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              ..._churchRoles.map(
                                (r) => DropdownMenuItem<int>(
                                  value: r['id'],
                                  child: Text(r['name']),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _targetRoleId = val),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 40),

                    // --- CAMPOS ---
                    Row(
                      children: [
                        Text("Campos del Formulario", style: sectionTitleStyle),
                        const SizedBox(width: 8),
                        // BOTÓN AYUDA (?) DISCRETO
                        InkWell(
                          onTap: _showFieldHelpDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.iconBackground.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.help_outline,
                              color: colors.iconBackground,
                              size: 16,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _addField,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.add,
                              color: colors.iconColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _fields.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _fields.removeAt(oldIndex);
                          _fields.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final field = _fields[index];
                        final key = ValueKey(field['uiId']);

                        return Card(
                          key: key,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 15),
                          color: colors.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colors.cardBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: Icon(
                                          Icons.drag_indicator,
                                          color: colors.text.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "Campo #${index + 1}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colors.text.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => _removeField(index),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colors.iconBackground,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.iconBorder,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: colors.iconColor,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: AppTextField(
                                        controller:
                                            TextEditingController(
                                                text: field['label'],
                                              )
                                              ..selection =
                                                  TextSelection.collapsed(
                                                    offset:
                                                        field['label'].length,
                                                  ),
                                        label: "Etiqueta Visual",
                                        onChanged: (v) => field['label'] = v,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: AppTextField(
                                        controller:
                                            TextEditingController(
                                                text: field['name'],
                                              )
                                              ..selection =
                                                  TextSelection.collapsed(
                                                    offset:
                                                        field['name'].length,
                                                  ),
                                        label: "Variable BD",
                                        onChanged: (v) => field['name'] = v,
                                      ),
                                    ),
                                  ],
                                ),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: AppDropdown<String>(
                                        value:
                                            _dataTypes.contains(
                                              field['dataType'],
                                            )
                                            ? field['dataType']
                                            : 'STRING',
                                        label: "Tipo de Dato",
                                        items: _dataTypes
                                            .map(
                                              (t) => DropdownMenuItem(
                                                value: t,
                                                child: Text(
                                                  t,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(() {
                                          field['dataType'] = v;
                                          if (v != 'MEMBER_SELECTION') {
                                            field['memberSelectionLogic'] =
                                                null;
                                          }
                                        }),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            unselectedWidgetColor:
                                                colors.inputBorder,
                                          ),
                                          child: CheckboxListTile(
                                            title: Text(
                                              "Oblig.",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.text,
                                              ),
                                            ),
                                            value: field['isRequired'] == true,
                                            activeColor: colors.iconBackground,
                                            checkColor: colors.iconColor,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            onChanged: (v) => setState(
                                              () => field['isRequired'] = v,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (field['dataType'] == 'MEMBER_SELECTION')
                                  AppTextField(
                                    controller:
                                        TextEditingController(
                                            text: field['memberSelectionLogic'],
                                          )
                                          ..selection = TextSelection.collapsed(
                                            offset:
                                                (field['memberSelectionLogic'] ??
                                                        '')
                                                    .length,
                                          ),
                                    label: "Filtro de Miembros (Opcional)",
                                    prefixIcon: Icons.filter_list,
                                    onChanged: (v) =>
                                        field['memberSelectionLogic'] = v,
                                  ),
                                // --- MOTOR VISUAL DE FÓRMULAS ---
                                if (field['dataType'] == 'FORMULA')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: colors.iconBackground.withValues(
                                          alpha: 0.05,
                                        ),
                                        border: Border.all(
                                          color: colors.iconBackground
                                              .withValues(alpha: 0.3),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Ecuación Matemática:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colors.text,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: colors.cardBackground,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: colors.cardBorder,
                                              ),
                                            ),
                                            child: Text(
                                              (field['formulaExpression'] ==
                                                          null ||
                                                      field['formulaExpression']
                                                          .toString()
                                                          .isEmpty)
                                                  ? "Toca las variables y operadores para armar la fórmula..."
                                                  : field['formulaExpression']
                                                        .toString(),
                                              style: TextStyle(
                                                color: colors.iconBackground,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              ...[
                                                '+',
                                                '-',
                                                '*',
                                                '/',
                                                '(',
                                                ')',
                                              ].map(
                                                (op) => ActionChip(
                                                  label: Text(
                                                    op,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      colors.inputBackground,
                                                  onPressed: () {
                                                    setState(
                                                      () => field['formulaExpression'] =
                                                          "${field['formulaExpression'] ?? ''} $op"
                                                              .trim(),
                                                    );
                                                  },
                                                ),
                                              ),
                                              ActionChip(
                                                label: const Icon(
                                                  Icons.backspace,
                                                  size: 14,
                                                ),
                                                backgroundColor: colors
                                                    .errorColor
                                                    .withValues(alpha: 0.2),
                                                onPressed: () {
                                                  String current =
                                                      (field['formulaExpression'] ??
                                                              '')
                                                          .toString();
                                                  if (current.isNotEmpty) {
                                                    List<String> parts = current
                                                        .split(' ');
                                                    parts.removeLast();
                                                    setState(
                                                      () =>
                                                          field['formulaExpression'] =
                                                              parts.join(' '),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Variables Disponibles (Solo números):",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.text.withValues(
                                                alpha: 0.6,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: _fields
                                                .where(
                                                  (f) =>
                                                      f['dataType'] == 'INT' ||
                                                      f['dataType'] ==
                                                          'DECIMAL',
                                                )
                                                .map((f) {
                                                  return ActionChip(
                                                    label: Text(
                                                      f['name'] ?? 'sin_nombre',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    backgroundColor: colors
                                                        .iconBackground
                                                        .withValues(alpha: 0.2),
                                                    onPressed: () {
                                                      if (f['name'] != null &&
                                                          f['name']
                                                              .toString()
                                                              .isNotEmpty) {
                                                        setState(
                                                          () => field['formulaExpression'] =
                                                              "${field['formulaExpression'] ?? ''} [${f['name']}]"
                                                                  .trim(),
                                                        );
                                                      }
                                                    },
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
