import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA
import '../../../widgets/ui_components/app_inputs.dart'; // <--- LOS LEGOS

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
          _isLoadingColumns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingColumns = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_selectedRecordTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Seleccione un Formulario Base",
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
              "Plantilla Guardada",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e", style: TextStyle(color: colors.text)),
            backgroundColor: colors.errorColor,
          ),
        );
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
      color: colors.text.withValues(alpha: 0.8),
    );

    return MasterLayout(
      title: widget.existingReport != null
          ? "Editar Plantilla Excel"
          : "Nueva Plantilla Excel",
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
                    // Center(
                    //   child: Container(
                    //     padding: const EdgeInsets.all(20),
                    //     decoration: BoxDecoration(
                    //       color: colors.iconBackground,
                    //       shape: BoxShape.circle,
                    //       border: Border.all(
                    //         color: colors.iconBorder,
                    //         width: 2,
                    //       ),
                    //     ),
                    //     child: Icon(
                    //       Icons.design_services,
                    //       size: 40,
                    //       color: colors.iconColor,
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 30),
                    AppTextField(
                      controller: _nameCtrl,
                      label: "Nombre del Reporte",
                      prefixIcon: Icons.table_chart,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                    AppTextField(
                      controller: _descCtrl,
                      label: "Descripción (Opcional)",
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),

                    const Divider(height: 40),

                    Text(
                      "1. Seleccione Origen de Datos",
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 15),

                    AppDropdown<int>(
                      value: _selectedRecordTypeId,
                      label: "Formulario Base",
                      items: _availableRecordTypes.map<DropdownMenuItem<int>>((
                        item,
                      ) {
                        return DropdownMenuItem<int>(
                          value: item['id'],
                          child: Text(item['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedRecordTypeId) {
                          setState(() {
                            _selectedRecordTypeId = val;
                            _selectedColumns.clear();
                          });
                          _fetchColumns(val);
                        }
                      },
                      validator: (v) => v == null ? "Requerido" : null,
                    ),

                    const SizedBox(height: 25),
                    Text(
                      "2. Seleccione Columnas para Exportar",
                      style: sectionTitleStyle,
                    ),
                    const SizedBox(height: 15),

                    if (_selectedRecordTypeId == null)
                      Text(
                        "Seleccione un formulario arriba para ver las columnas.",
                        style: TextStyle(
                          color: colors.text.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    if (_isLoadingColumns)
                      Padding(
                        padding: const EdgeInsets.all(20),
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
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableColumns.length,
                          itemBuilder: (ctx, i) {
                            final col = _availableColumns[i];
                            final key = col['key'] as String;
                            final label = col['label'] as String;
                            final isDynamic = col['isDynamic'] == true;

                            return Theme(
                              data: Theme.of(context).copyWith(
                                unselectedWidgetColor: colors.inputBorder,
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.text,
                                  ),
                                ),
                                subtitle: Text(
                                  "Columna: $key ${isDynamic ? '(Campo dinámico)' : '(Fijo)'}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.text.withValues(alpha: 0.6),
                                  ),
                                ),
                                value: _selectedColumns.contains(key),
                                activeColor: colors.iconBackground,
                                checkColor: colors.iconColor,
                                onChanged: (bool? checked) {
                                  setState(() {
                                    if (checked == true)
                                      _selectedColumns.add(key);
                                    else
                                      _selectedColumns.remove(key);
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
