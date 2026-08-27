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
  bool _isGenerating = false;

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
        if (isStart)
          _startDate = date;
        else
          _endDate = date;
      });
    }
  }

  Future<void> _generateAndDownloadCsv() async {
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
            "La plantilla está corrupta. Edítela nuevamente.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "No hay datos en este rango de fechas.",
                style: TextStyle(color: colors.text),
              ),
              backgroundColor: colors.warningColor,
            ),
          );
        setState(() => _isGenerating = false);
        return;
      }

      List<List<dynamic>> csvData = [];
      final firstRow = data.first as Map<String, dynamic>;
      csvData.add(firstRow.keys.map((k) => k.toUpperCase()).toList());

      for (var row in data) {
        if (row is Map<String, dynamic>) csvData.add(row.values.toList());
      }

      String csvContent = const ListToCsvConverter().convert(csvData);
      List<int> bom = [0xEF, 0xBB, 0xBF];
      List<int> bytes = utf8.encode(csvContent);
      Uint8List finalBytes = Uint8List.fromList(bom + bytes);

      String fileName =
          "Reporte_${widget.reportData['name']}_${DateFormat('yyyyMMdd').format(DateTime.now())}";

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: finalBytes,
        fileExtension: "csv",
        mimeType: MimeType.csv,
      );

      if (mounted) {
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
                Icon(Icons.check_circle, color: colors.successColor),
                const SizedBox(width: 10),
                Text(
                  "¡Descarga Exitosa!",
                  style: TextStyle(color: colors.text),
                ),
              ],
            ),
            content: Text(
              "El archivo Excel (.csv) se ha guardado en tus descargas.",
              style: TextStyle(color: colors.text.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Entendido", style: TextStyle(color: colors.text)),
              ),
            ],
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
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Exportar a Excel",
      mode: PageMode.form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.successColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.table_view,
                size: 60,
                color: colors.successColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.reportData['name'] ?? 'Reporte',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Filtre por fecha y genere su archivo de datos planos listos para Business Intelligence.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: TextEditingController(
                      text: _startDate != null
                          ? DateFormat('yyyy-MM-dd').format(_startDate!)
                          : "Desde siempre",
                    ),
                    label: "Fecha Inicio",
                    readOnly: true,
                    onTap: () => _pickDate(true),
                    prefixIcon: Icons.calendar_today,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: AppTextField(
                    controller: TextEditingController(
                      text: _endDate != null
                          ? DateFormat('yyyy-MM-dd').format(_endDate!)
                          : "Hasta hoy",
                    ),
                    label: "Fecha Fin",
                    readOnly: true,
                    onTap: () => _pickDate(false),
                    prefixIcon: Icons.calendar_today,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndDownloadCsv,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                label: Text(
                  _isGenerating ? "Generando..." : "GENERAR CSV (EXCEL)",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.successColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
