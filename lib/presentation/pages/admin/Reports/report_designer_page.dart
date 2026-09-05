import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';

class ReportDesignerPage extends StatefulWidget {
  final Map<String, dynamic>? existingReport;
  const ReportDesignerPage({super.key, this.existingReport});

  @override
  State<ReportDesignerPage> createState() => _ReportDesignerPageState();
}

class _ReportDesignerPageState extends State<ReportDesignerPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedRecordTypeId;
  String? _selectedRecordTypeName;
  List<dynamic> _availableRecordTypes = [];

  List<dynamic> _availableColumns = [];
  List<String> _selectedColumns = [];

  bool _isSaving = false;
  bool _isLoadingInitial = true;
  bool _isLoadingColumns = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final rtData = await _api.get(ApiConstants.recordTypes);
      _availableRecordTypes = (rtData is List) ? rtData : [];

      if (widget.existingReport != null) {
        final e = widget.existingReport!;
        _nameCtrl.text = e['name'] ?? '';
        _descCtrl.text = e['description'] ?? '';

        dynamic configRaw = e['configuration'];
        if (configRaw is String) {
          try {
            configRaw = jsonDecode(configRaw);
          } catch (_) {}
        }

        if (configRaw is Map) {
          _selectedRecordTypeId = configRaw['recordTypeId'];
          if (configRaw['selectedColumns'] != null) {
            _selectedColumns = List<String>.from(configRaw['selectedColumns']);
          }
          if (_selectedRecordTypeId != null) {
            final found = _availableRecordTypes.firstWhere(
              (rt) => rt['id'] == _selectedRecordTypeId,
              orElse: () => null,
            );
            if (found != null) _selectedRecordTypeName = found['name'];
            await _fetchColumns(_selectedRecordTypeId!);
          }
        }
      }

      if (mounted) setState(() => _isLoadingInitial = false);
    } catch (e) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _fetchColumns(int recordTypeId) async {
    setState(() => _isLoadingColumns = true);
    try {
      final cols = await _api.get(
        '${ApiConstants.reports}/available-columns/$recordTypeId',
      );
      if (mounted) {
        setState(() {
          _availableColumns = (cols is List) ? cols : [];

          // Preseleccionamos por defecto las columnas fijas obligatorias
          for (var col in _availableColumns) {
            if (col['isRequired'] == true &&
                !_selectedColumns.contains(col['key'])) {
              _selectedColumns.add(col['key']);
            }
          }
          _isLoadingColumns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingColumns = false);
    }
  }

  void _openRecordTypeSearchModal(AppThemeColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => _RecordTypeSearchModal(
        recordTypes: _availableRecordTypes,
        colors: colors,
        onSelected: (selected) {
          setState(() {
            _selectedRecordTypeId = selected['id'];
            _selectedRecordTypeName = selected['name'];
            _selectedColumns.clear();
          });
          _fetchColumns(selected['id']);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_selectedRecordTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Seleccione el Origen de Datos (Formulario/Evento)",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Seleccione al menos una columna para exportar",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final configPayload = {
      "recordTypeId": _selectedRecordTypeId,
      "selectedColumns": _selectedColumns,
    };

    final payload = {
      "name": _nameCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "typeReport": 4,
      "configuration": configPayload,
    };

    try {
      if (widget.existingReport == null) {
        await _api.post(ApiConstants.reports, payload);
      } else {
        await _api.put(
          '${ApiConstants.reports}/${widget.existingReport!['id']}',
          payload,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Plantilla de Reporte Guardada",
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
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: colors.text.withValues(alpha: 0.9),
    );

    return MasterLayout(
      title: widget.existingReport != null
          ? "Editar Reporte Excel"
          : "Nuevo Reporte Excel",
      mode: PageMode.form,
      onSave: _save,
      isSaving: _isSaving,
      child: _isLoadingInitial
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
                    AppTextField(
                      controller: _nameCtrl,
                      label: "Nombre de la Plantilla",
                      prefixIcon: Icons.table_chart,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                    AppTextField(
                      controller: _descCtrl,
                      label: "Descripción (Opcional)",
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),

                    const Divider(height: 35),

                    Text(
                      "1. Seleccione Origen de Datos",
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 12),

                    // TARJETA DE BÚSQUEDA DE ORIGEN DE DATOS
                    InkWell(
                      onTap: () => _openRecordTypeSearchModal(colors),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedRecordTypeId == null
                                ? colors.cardBorder
                                : colors.iconBackground,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              color: colors.iconColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Formulario / Tipo de Evento",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.text.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedRecordTypeName ??
                                        "Toca para buscar origen de datos...",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _selectedRecordTypeName != null
                                          ? colors.text
                                          : colors.text.withValues(alpha: 0.5),
                                      fontWeight:
                                          _selectedRecordTypeName != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.search,
                              color: colors.text.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text(
                      "2. Seleccione Columnas para Exportar",
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Las columnas de auditoría vienen fijas. Marque las variables de datos que desea extraer a Excel:",
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.text.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 15),

                    if (_selectedRecordTypeId == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            "Seleccione un origen de datos arriba para cargar los campos disponibles.",
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),

                    if (_isLoadingColumns)
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.iconBackground,
                          ),
                        ),
                      ),

                    if (!_isLoadingColumns && _availableColumns.isNotEmpty)
                      Card(
                        elevation: 0,
                        color: colors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: colors.cardBorder),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableColumns.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: colors.cardBorder, height: 1),
                          itemBuilder: (ctx, i) {
                            final col = _availableColumns[i];
                            final key = col['key'] as String;
                            final label = col['label'] as String;
                            final isDynamic = col['isDynamic'] == true;
                            final isRequired = col['isRequired'] == true;
                            final dataType = col['dataType'] ?? 'STRING';

                            return Theme(
                              data: Theme.of(context).copyWith(
                                unselectedWidgetColor: colors.inputBorder,
                              ),
                              child: CheckboxListTile(
                                enabled: !isRequired,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colors.text,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isDynamic)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.iconBackground
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          dataType,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: colors.iconBackground,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  isRequired
                                      ? "Columna obligatoria de auditoría"
                                      : "Variable de datos ($key)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.text.withValues(alpha: 0.6),
                                  ),
                                ),
                                value: _selectedColumns.contains(key),
                                activeColor: colors.iconBackground,
                                checkColor: colors.iconColor,
                                onChanged: isRequired
                                    ? null
                                    : (bool? checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedColumns.add(key);
                                          } else {
                                            _selectedColumns.remove(key);
                                          }
                                        });
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// MODAL BUSCADOR
class _RecordTypeSearchModal extends StatefulWidget {
  final List<dynamic> recordTypes;
  final AppThemeColors colors;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _RecordTypeSearchModal({
    required this.recordTypes,
    required this.colors,
    required this.onSelected,
  });

  @override
  State<_RecordTypeSearchModal> createState() => _RecordTypeSearchModalState();
}

class _RecordTypeSearchModalState extends State<_RecordTypeSearchModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.recordTypes.where((rt) {
      final name = (rt['name'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: widget.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.colors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Buscar Origen de Datos",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.colors.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.colors.text),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              style: TextStyle(color: widget.colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Ej. Dominical, Célula, Asistencia...",
                hintStyle: TextStyle(
                  color: widget.colors.text.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: widget.colors.iconColor,
                  size: 20,
                ),
                filled: true,
                fillColor: widget.colors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          "No se encontraron coincidencias.",
                          style: TextStyle(
                            color: widget.colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: widget.colors.cardBorder, height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = filtered[idx];
                        return ListTile(
                          title: Text(
                            item['name'] ?? '',
                            style: TextStyle(
                              color: widget.colors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            item['description'] ?? 'Formulario Activo',
                            style: TextStyle(
                              color: widget.colors.text.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          onTap: () {
                            widget.onSelected(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
