// ... [MANTÉN TUS IMPORTS Y LA CLASE STATEFUL WIDGET IGUAL] ...
import 'package:flutter/material.dart';
import '../../../../data/repositories/generic_repository.dart';
import 'package:intl/intl.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';
import '../../../widgets/ui_components/organization_structure_selector.dart';

class EventFormPage extends StatefulWidget {
  final Map<String, dynamic>? event;
  const EventFormPage({super.key, this.event});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.events);
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isInPerson = true;
  int? _structureId;
  bool _allowMultipleSubmissions = false;

  // --- MOTOR DE RECURRENCIA AVANZADO ---
  String _uiRecurrenceSelection = 'NONE';

  // Variables reales a enviar a BD
  String _recurrenceType = 'NONE';
  int _recurrenceInterval = 1;
  int _recurringDaysBitmask = 0;
  String _endType = 'NEVER';
  DateTime? _endDate;
  int? _maxOccurrences;

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _structures = [];
  List<dynamic> _availableRecordTypes = [];
  final List<int> _selectedRecordTypeIds = [];

  final List<Map<String, dynamic>> _weekDaysMap = [
    {"label": "D", "value": 64},
    {"label": "L", "value": 1},
    {"label": "M", "value": 2},
    {"label": "X", "value": 4},
    {"label": "J", "value": 8},
    {"label": "V", "value": 16},
    {"label": "S", "value": 32},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final responses = await Future.wait([
        _api.get(ApiConstants.organizationStructures),
        _api.get(ApiConstants.recordTypes),
      ]);

      if (mounted) {
        setState(() {
          final currentStructId = widget.event?['organizationStructureId'];
          _structures = (responses[0] is List)
              ? (responses[0] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          (currentStructId != null &&
                              e['id'] == currentStructId),
                    )
                    .toList()
              : [];

          final currentRecordTypes = List<int>.from(
            widget.event?['recordTypeIds'] ?? [],
          );
          _availableRecordTypes = (responses[1] is List)
              ? (responses[1] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          currentRecordTypes.contains(e['id']),
                    )
                    .toList()
              : [];

          if (widget.event != null) {
            final e = widget.event!;
            _nameCtrl.text = e['name'];
            _descCtrl.text = e['description'] ?? '';
            _isInPerson = e['isInPerson'] ?? true;
            _structureId = e['organizationStructureId'];
            _allowMultipleSubmissions =
                e['allowMultipleSubmissionsPerDay'] ?? false; // <--- AGREGAR

            _recurrenceType = e['recurrenceType'] ?? 'NONE';
            _recurrenceInterval = e['recurrenceInterval'] ?? 1;
            _recurringDaysBitmask = e['recurringDays'] ?? 0;
            _endType = e['endType'] ?? 'NEVER';
            if (e['endDate'] != null) _endDate = DateTime.parse(e['endDate']);
            _maxOccurrences = e['maxOccurrences'];

            if (_recurrenceType == 'NONE') {
              _uiRecurrenceSelection = 'NONE';
            } else if (_recurrenceInterval == 1 &&
                _endType == 'NEVER' &&
                (_recurrenceType == 'DAILY' ||
                    _recurrenceType == 'MONTHLY' ||
                    _recurrenceType == 'ANNUALLY')) {
              _uiRecurrenceSelection = _recurrenceType;
            } else if (_recurrenceType == 'WEEKLY' &&
                _recurrenceInterval == 1 &&
                _endType == 'NEVER') {
              _uiRecurrenceSelection = 'WEEKLY';
            } else {
              _uiRecurrenceSelection = 'CUSTOM';
            }

            if (e['date'] != null) {
              final dt = DateTime.parse(e['date']);
              _selectedDate = dt;
              _selectedTime = TimeOfDay.fromDateTime(dt);
            }

            if (e['recordTypeIds'] != null) {
              _selectedRecordTypeIds.addAll(List<int>.from(e['recordTypeIds']));
            }
          }
          _updateDateText();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateDateText() {
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    _dateCtrl.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  int _getBitmaskForDay(int weekday) {
    switch (weekday) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 4;
      case 4:
        return 8;
      case 5:
        return 16;
      case 6:
        return 32;
      case 7:
        return 64;
      default:
        return 1;
    }
  }

  Future<void> _pickDateTime() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => _themeWrapper(child!, colors),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => _themeWrapper(child!, colors),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = date;
      _selectedTime = time;
      _updateDateText();

      if (_uiRecurrenceSelection == 'WEEKLY') {
        _recurringDaysBitmask = _getBitmaskForDay(_selectedDate.weekday);
      }
    });
  }

  Widget _themeWrapper(Widget child, AppThemeColors colors) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: colors.iconBackground,
          onPrimary: colors.iconColor,
          surface: colors.cardBackground,
          onSurface: colors.text,
        ),
      ),
      child: child,
    );
  }

  // --- DIÁLOGO DE RECURRENCIA PERSONALIZADA ---
  Future<void> _showCustomRecurrenceDialog() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    String tempType = _recurrenceType == 'NONE' ? 'WEEKLY' : _recurrenceType;
    int tempInterval = _recurrenceInterval;
    int tempBitmask = _recurringDaysBitmask == 0
        ? _getBitmaskForDay(_selectedDate.weekday)
        : _recurringDaysBitmask;
    String tempEndType = _endType;
    DateTime? tempEndDate =
        _endDate ?? _selectedDate.add(const Duration(days: 30));
    int tempOccurrences = _maxOccurrences ?? 13;

    final occurrencesCtrl = TextEditingController(
      text: tempOccurrences.toString(),
    );

    bool confirmed =
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setStateModal) {
                return AlertDialog(
                  backgroundColor: colors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.cardBorder),
                  ),
                  title: Text(
                    "Recurrencia personalizada",
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Repetir cada X intervalo (SOLUCIÓN DE OVERFLOW AQUÍ USANDO WRAP)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Text(
                              "Repetir cada",
                              style: TextStyle(color: colors.text),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                initialValue: tempInterval.toString(),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.text,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: colors.inputBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: colors.inputBorder,
                                    ),
                                  ),
                                ),
                                onChanged: (v) =>
                                    tempInterval = int.tryParse(v) ?? 1,
                              ),
                            ),
                            // Se fija el ancho del dropdown para evitar overflow en pantallas muy pequeñas
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<String>(
                                initialValue: tempType,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: colors.inputBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: colors.inputBorder,
                                    ),
                                  ),
                                ),
                                dropdownColor: colors.cardBackground,
                                items: [
                                  DropdownMenuItem(
                                    value: 'DAILY',
                                    child: Text(
                                      "día(s)",
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'WEEKLY',
                                    child: Text(
                                      "semanas",
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'MONTHLY',
                                    child: Text(
                                      "mes(es)",
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ANNUALLY',
                                    child: Text(
                                      "año(s)",
                                      style: TextStyle(
                                        color: colors.text,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setStateModal(() => tempType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (tempType == 'WEEKLY') ...[
                          Text(
                            "Repetir el",
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _weekDaysMap.map((day) {
                              final isSelected =
                                  tempBitmask & day['value'] != 0;
                              return InkWell(
                                onTap: () {
                                  setStateModal(() {
                                    if (tempBitmask & day['value'] != 0) {
                                      tempBitmask &= ~(day['value'] as int);
                                    } else {
                                      tempBitmask |= (day['value'] as int);
                                    }
                                  });
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.iconBackground
                                        : colors.inputBackground,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.iconBorder
                                          : colors.inputBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      day['label'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? colors.iconColor
                                            : colors.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        const Divider(),
                        Text(
                          "Termina",
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        RadioListTile<String>(
                          title: Text(
                            "Nunca",
                            style: TextStyle(color: colors.text, fontSize: 14),
                          ),
                          value: 'NEVER',
                          groupValue: tempEndType,
                          activeColor: colors.iconBackground,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (v) =>
                              setStateModal(() => tempEndType = v!),
                        ),

                        RadioListTile<String>(
                          title: Row(
                            children: [
                              Text(
                                "El ",
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: ctx,
                                      initialDate: tempEndDate!,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100),
                                      builder: (c, w) =>
                                          _themeWrapper(w!, colors),
                                    );
                                    if (d != null) {
                                      setStateModal(() {
                                        tempEndType = 'UNTIL_DATE';
                                        tempEndDate = d;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.inputBackground,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.inputBorder,
                                      ),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(tempEndDate!),
                                      style: TextStyle(color: colors.text),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          value: 'UNTIL_DATE',
                          groupValue: tempEndType,
                          activeColor: colors.iconBackground,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (v) =>
                              setStateModal(() => tempEndType = v!),
                        ),

                        // DESPUÉS DE (Ocurrencias) - SOLUCIÓN DE OVERFLOW AQUÍ
                        RadioListTile<String>(
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Después de ",
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  controller: occurrencesCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.text),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: colors.inputBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: colors.inputBorder,
                                      ),
                                    ),
                                  ),
                                  onTap: () => setStateModal(
                                    () => tempEndType = 'AFTER_OCCURRENCES',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "repeticiones",
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          value: 'AFTER_OCCURRENCES',
                          groupValue: tempEndType,
                          activeColor: colors.iconBackground,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (v) =>
                              setStateModal(() => tempEndType = v!),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(color: colors.text),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        tempOccurrences =
                            int.tryParse(occurrencesCtrl.text) ?? 13;
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.buttonBackground,
                      ),
                      child: Text(
                        "Listo",
                        style: TextStyle(color: colors.buttonText),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (confirmed) {
      setState(() {
        _recurrenceType = tempType;
        _recurrenceInterval = tempInterval;
        _recurringDaysBitmask = tempBitmask;
        _endType = tempEndType;
        _endDate = tempEndDate;
        _maxOccurrences = tempOccurrences;
        _uiRecurrenceSelection = 'CUSTOM';
      });
    } else {
      if (_uiRecurrenceSelection == 'CUSTOM' && _recurrenceType == 'NONE') {
        setState(() => _uiRecurrenceSelection = 'NONE');
      }
    }
  }

  void _handleMainDropdownChange(String? val) {
    if (val == null) return;
    setState(() {
      _uiRecurrenceSelection = val;
      if (val == 'NONE') {
        _recurrenceType = 'NONE';
        _recurrenceInterval = 1;
      } else if (val == 'DAILY') {
        _recurrenceType = 'DAILY';
        _recurrenceInterval = 1;
        _endType = 'NEVER';
      } else if (val == 'WEEKLY') {
        _recurrenceType = 'WEEKLY';
        _recurrenceInterval = 1;
        _recurringDaysBitmask = _getBitmaskForDay(_selectedDate.weekday);
        _endType = 'NEVER';
      } else if (val == 'MONTHLY') {
        _recurrenceType = 'MONTHLY';
        _recurrenceInterval = 1;
        _endType = 'NEVER';
      } else if (val == 'ANNUALLY') {
        _recurrenceType = 'ANNUALLY';
        _recurrenceInterval = 1;
        _endType = 'NEVER';
      } else if (val == 'CUSTOM') {
        _showCustomRecurrenceDialog();
      }
    });
  }

  String _getCustomSummaryText() {
    if (_recurrenceType == 'NONE') return "";
    String freq = "";
    if (_recurrenceType == 'DAILY') {
      freq = _recurrenceInterval == 1
          ? "Todos los días"
          : "Cada $_recurrenceInterval días";
    }
    if (_recurrenceType == 'WEEKLY') {
      freq = _recurrenceInterval == 1
          ? "Semanalmente"
          : "Cada $_recurrenceInterval semanas";
    }
    if (_recurrenceType == 'MONTHLY') {
      freq = _recurrenceInterval == 1
          ? "Mensualmente"
          : "Cada $_recurrenceInterval meses";
    }
    if (_recurrenceType == 'ANNUALLY') {
      freq = _recurrenceInterval == 1
          ? "Anualmente"
          : "Cada $_recurrenceInterval años";
    }

    String endStr = "";
    if (_endType == 'UNTIL_DATE' && _endDate != null) {
      endStr = ", hasta el ${DateFormat('dd/MM/yyyy').format(_endDate!)}";
    }
    if (_endType == 'AFTER_OCCURRENCES') {
      endStr = ", termina después de $_maxOccurrences repeticiones";
    }

    return "$freq$endStr";
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_recurrenceType == 'WEEKLY' && _recurringDaysBitmask == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Seleccione al menos un día para la recurrencia.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final finalDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final payload = {
      "name": _nameCtrl.text.trim(),
      "date": finalDate.toIso8601String(),
      "description": _descCtrl.text.trim(),
      "isInPerson": _isInPerson,
      "allowMultipleSubmissionsPerDay":
          _allowMultipleSubmissions, // <--- AGREGAR
      "organizationStructureId": _structureId,
      "recordTypeIds": _selectedRecordTypeIds,
      "recurrenceType": _recurrenceType,
      "recurrenceInterval": _recurrenceInterval,
      "recurringDays": _recurrenceType == 'WEEKLY'
          ? _recurringDaysBitmask
          : null,
      "endType": _endType,
      "endDate": _endType == 'UNTIL_DATE' ? _endDate?.toIso8601String() : null,
      "maxOccurrences": _endType == 'AFTER_OCCURRENCES'
          ? _maxOccurrences
          : null,
    };

    try {
      payload['id'] = widget.event?['id'];
      await _repo.save(payload);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Evento guardado",
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
            content: Text("Error: $e", style: TextStyle(color: colors.text)),
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
      title: widget.event != null ? "Editar Evento" : "Nuevo Evento",
      mode: PageMode.form,
      onSave: _save,
      isSaving: _isSaving,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Información Principal", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    AppTextField(
                      controller: _nameCtrl,
                      label: "Nombre del Evento",
                      prefixIcon: Icons.festival,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),

                    OrganizationStructureSelector(
                      value: _structureId,
                      structures: _structures,
                      label: "Organizado por (Red/Grupo)",
                      allowNull: true,
                      nullLabel: "Evento Global (Iglesia)",
                      onChanged: (v) => setState(() => _structureId = v),
                    ),

                    AppTextField(
                      controller: _descCtrl,
                      label: "Descripción (Opcional)",
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),

                    // 🔥 NUEVO CHECKBOX
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(unselectedWidgetColor: colors.inputBorder),
                      child: CheckboxListTile(
                        title: Text(
                          "Permitir múltiples reportes diarios",
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Útil para reportar 'Nuevos Creyentes' o eventos continuos varias veces el mismo día.",
                          style: TextStyle(
                            color: colors.text.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        value: _allowMultipleSubmissions,
                        activeColor: colors.iconBackground,
                        checkColor: colors.iconColor,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) => setState(
                          () => _allowMultipleSubmissions = val ?? false,
                        ),
                      ),
                    ),

                    const Divider(height: 30),

                    Text("Tiempo y Modalidad", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    // PRESENCIAL / VIRTUAL
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isInPerson = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isInPerson
                                      ? colors.iconBackground
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "Presencial",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isInPerson
                                          ? colors.iconColor
                                          : colors.text.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isInPerson = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isInPerson
                                      ? colors.iconBackground
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "Virtual",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: !_isInPerson
                                          ? colors.iconColor
                                          : colors.text.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    AppTextField(
                      controller: _dateCtrl,
                      label: "Fecha y Hora del Evento",
                      prefixIcon: Icons.calendar_month,
                      readOnly: true,
                      onTap: _pickDateTime,
                    ),

                    // DROPDOWN RECURRENCIA (ESTILO GOOGLE CALENDAR)
                    AppDropdown<String>(
                      value: _uiRecurrenceSelection,
                      label: "Repetir",
                      items: const [
                        DropdownMenuItem(
                          value: 'NONE',
                          child: Text("No se repite"),
                        ),
                        DropdownMenuItem(
                          value: 'DAILY',
                          child: Text("Todos los días"),
                        ),
                        DropdownMenuItem(
                          value: 'WEEKLY',
                          child: Text("Cada semana"),
                        ),
                        DropdownMenuItem(
                          value: 'MONTHLY',
                          child: Text("Cada mes"),
                        ),
                        DropdownMenuItem(
                          value: 'ANNUALLY',
                          child: Text("Anualmente"),
                        ),
                        DropdownMenuItem(
                          value: 'CUSTOM',
                          child: Text("Personalizado..."),
                        ),
                      ],
                      onChanged: _handleMainDropdownChange,
                    ),

                    if (_uiRecurrenceSelection == 'CUSTOM')
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          top: 4,
                          bottom: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.repeat_on,
                              size: 14,
                              color: colors.text.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _getCustomSummaryText(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.text.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Divider(height: 40),

                    Text("Formularios a Llenar", style: sectionTitleStyle),
                    Text(
                      "Selecciona los reportes (ej. Asistencia, Ofrendas) que deben llenarse en este evento.",
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 15),

                    _availableRecordTypes.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "No hay formularios diseñados o activos",
                              style: TextStyle(
                                color: colors.text.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Material(
                            color: colors.inputBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colors.inputBorder),
                            ),
                            child: Column(
                              children: _availableRecordTypes.map((type) {
                                final id = type['id'];
                                final isSelected = _selectedRecordTypeIds
                                    .contains(id);
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    unselectedWidgetColor: colors.text
                                        .withValues(alpha: 0.4),
                                  ),
                                  child: CheckboxListTile(
                                    title: Text(
                                      type['name'],
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: isSelected,
                                    activeColor: colors.iconBackground,
                                    checkColor: colors.iconColor,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedRecordTypeIds.add(id);
                                        } else {
                                          _selectedRecordTypeIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }
}
