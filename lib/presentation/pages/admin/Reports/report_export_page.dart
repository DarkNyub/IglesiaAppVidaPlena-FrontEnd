import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';

class ReportExportPage extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportExportPage({super.key, required this.reportData});

  @override
  State<ReportExportPage> createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> {
  final _api = ApiService();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = false;
  List<Map<String, dynamic>> _previewData = [];
  List<String> _headers = [];

  Future<void> _pickDate(bool isStart) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colors.iconBackground,
              onPrimary: colors.iconColor,
              surface: colors.cardBackground,
              onSurface: colors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  // 1. CARGA LA DATA Y LA MUESTRA EN PANTALLA
  Future<void> _fetchPreviewData() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    dynamic configRaw = widget.reportData['configuration'];
    Map<String, dynamic> configMap = {};

    if (configRaw is String) {
      try {
        configMap = jsonDecode(configRaw);
      } catch (_) {}
    } else if (configRaw is Map) {
      configMap = Map<String, dynamic>.from(configRaw);
    }

    final int? recordTypeId = configMap['recordTypeId'];
    final List<String>? selectedColumns = configMap['selectedColumns'] != null
        ? List<String>.from(configMap['selectedColumns'])
        : null;

    if (recordTypeId == null ||
        selectedColumns == null ||
        selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "La plantilla está incompleta. Edítela e intente nuevamente.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _previewData.clear();
      _headers.clear();
    });

    try {
      final payload = {
        "recordTypeId": recordTypeId,
        "startDate": _startDate?.toIso8601String(),
        "endDate": _endDate?.toIso8601String(),
        "selectedColumns": selectedColumns,
      };

      final response = await _api.post(
        '${ApiConstants.reports}/generate-flat',
        payload,
      );
      final List<dynamic> data = (response is List) ? response : [];

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "No se encontraron registros en el rango de fechas seleccionado.",
                style: TextStyle(color: colors.text),
              ),
              backgroundColor: colors.warningColor,
            ),
          );
        }
        return;
      }

      final firstRow = Map<String, dynamic>.from(data.first);
      setState(() {
        _headers = firstRow.keys.toList();
        _previewData = data.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error cargando reporte: $e",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. EXPORTA A CSV CON SELECTOR NATIVO DE CARPETA (saveAs)
  Future<void> _exportToExcel() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    if (_previewData.isEmpty) {
      await _fetchPreviewData();
      if (_previewData.isEmpty) return;
    }

    try {
      List<List<dynamic>> csvData = [];

      // Fila de encabezados
      csvData.add(_headers);

      // Filas de contenido
      for (var row in _previewData) {
        csvData.add(row.values.toList());
      }

      String csvContent = const CsvEncoder().convert(csvData);
      List<int> bom = [0xEF, 0xBB, 0xBF]; // Marca UTF-8 para Excel
      List<int> bytes = utf8.encode(csvContent);
      Uint8List finalBytes = Uint8List.fromList(bom + bytes);

      String fileName =
          "Reporte_${widget.reportData['name']}_${DateFormat('yyyyMMdd').format(DateTime.now())}";

      // 🔥 saveAs ABRE LA VENTANA NATIVA DEL SISTEMA PARA ELEGIR LA CARPETA
      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: finalBytes,
        fileExtension: "csv",
        mimeType: MimeType.csv,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "¡Reporte exportado correctamente!",
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
            content: Text(
              "Error exportando: $e",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Consola de Reportes",
      mode: PageMode.form,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTROS SUPERIORES
            Card(
              color: colors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reportData['name'] ?? 'Reporte',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: TextEditingController(
                              text: _startDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_startDate!)
                                  : "Desde inicio",
                            ),
                            label: "Fecha Inicial",
                            readOnly: true,
                            onTap: () => _pickDate(true),
                            prefixIcon: Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: TextEditingController(
                              text: _endDate != null
                                  ? DateFormat('yyyy-MM-dd').format(_endDate!)
                                  : "Hasta hoy",
                            ),
                            label: "Fecha Final",
                            readOnly: true,
                            onTap: () => _pickDate(false),
                            prefixIcon: Icons.calendar_today,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _fetchPreviewData,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text("CONSULTAR"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.buttonBackground,
                              foregroundColor: colors.buttonText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _exportToExcel,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text("DESCARGAR EXCEL"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.successColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // VISOR DE TABLA DE DATOS
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colors.iconBackground,
                      ),
                    )
                  : _previewData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 60,
                            color: colors.text.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Seleccione un rango de fechas y toque 'CONSULTAR' para previsualizar los datos.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              "Vista Previa de Registros (${_previewData.length}):",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Divider(color: colors.cardBorder, height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    colors.inputBackground,
                                  ),
                                  columns: _headers
                                      .map(
                                        (h) => DataColumn(
                                          label: Text(
                                            h,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: colors.text,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: _previewData.map((row) {
                                    return DataRow(
                                      cells: _headers.map((h) {
                                        return DataCell(
                                          Text(
                                            row[h]?.toString() ?? '',
                                            style: TextStyle(
                                              color: colors.text,
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
