import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';
import '../../../widgets/ui_components/organization_structure_selector.dart';

class ReportViewerPage extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportViewerPage({super.key, required this.reportData});

  @override
  State<ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends State<ReportViewerPage> {
  final _api = ApiService();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedStructureId;

  List<dynamic> _structures = [];
  bool _isLoading = false;
  List<dynamic> _chartData = [];
  List<String> _uniqueMetrics = [];

  // Paleta de colores para las barras (Métricas)
  final List<Color> _barColors = [
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.greenAccent,
    Colors.redAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
  ];

  @override
  void initState() {
    super.initState();
    _loadStructures();
  }

  Future<void> _loadStructures() async {
    try {
      final res = await _api.get(ApiConstants.organizationStructures);
      if (mounted) {
        setState(() {
          _structures = (res is List)
              ? res.where((e) => e['isDeleted'] != true).toList()
              : [];
        });
      }
    } catch (_) {}
  }

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

  Future<void> _fetchChartData() async {
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
            "Plantilla incompleta.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _chartData.clear();
      _uniqueMetrics.clear();
    });

    try {
      final payload = {
        "recordTypeId": recordTypeId,
        "startDate": _startDate?.toIso8601String(),
        "endDate": _endDate?.toIso8601String(),
        "structureId": _selectedStructureId,
        "selectedColumns": selectedColumns,
      };

      final response = await _api.post(
        '${ApiConstants.reports}/generate-chart',
        payload,
      );
      final List<dynamic> data = (response is List) ? response : [];

      if (data.isNotEmpty) {
        final Set<String> metricKeys = {};
        for (var group in data) {
          final Map<String, dynamic> metrics = group['metrics'] ?? {};
          metricKeys.addAll(metrics.keys);
        }
        _uniqueMetrics = metricKeys.toList();
      }

      setState(() => _chartData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error cargando gráfica: $e",
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Tendencias de Crecimiento",
      mode: PageMode.form,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTROS
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
                      widget.reportData['name'] ?? 'Reporte Gráfico',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrganizationStructureSelector(
                      value: _selectedStructureId,
                      structures: _structures,
                      label: "Filtrar por Red / Ministerio",
                      allowNull: true,
                      nullLabel: "(Todas las Estructuras)",
                      onChanged: (val) =>
                          setState(() => _selectedStructureId = val),
                    ),
                    const SizedBox(height: 10),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchChartData,
                        icon: const Icon(Icons.show_chart, size: 18),
                        label: const Text("VER TENDENCIA SEMANAL"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonBackground,
                          foregroundColor: colors.buttonText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // LEYENDA Y GRÁFICO
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colors.iconBackground,
                      ),
                    )
                  : _chartData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 60,
                            color: colors.text.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Seleccione un rango y presione generar para ver las tendencias.",
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // LEYENDA DINÁMICA
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: _uniqueMetrics.asMap().entries.map((entry) {
                            final color =
                                _barColors[entry.key % _barColors.length];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 12, height: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                        Expanded(child: _buildGroupedBarChart(colors)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedBarChart(AppThemeColors colors) {
    // Calculamos el valor máximo del eje Y para escalar correctamente
    double maxY = 0;
    for (var group in _chartData) {
      final Map<String, dynamic> metrics = group['metrics'] ?? {};
      for (var val in metrics.values) {
        final dVal = (val as num).toDouble();
        if (dVal > maxY) maxY = dVal;
      }
    }
    // Damos un 20% de aire arriba para que las barras no toquen el techo
    maxY = maxY + (maxY * 0.2);
    if (maxY == 0) maxY = 10;

    return BarChart(
      BarChartData(
        maxY: maxY,
        titlesData: FlTitlesData(
          // EJE X (Las Semanas)
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (val, meta) {
                final index = val.toInt();
                if (index >= 0 && index < _chartData.length) {
                  // El label viene con un salto de línea desde el backend (ej. 05/01\n11/01)
                  String label = _chartData[index]['groupName'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.text.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          // EJE Y (Las Cantidades)
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (v, m) => Text(
                NumberFormat.compact().format(v), // Formatea ej: 1500 -> 1.5K
                style: TextStyle(
                  color: colors.text.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: colors.cardBorder.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        barGroups: _chartData.asMap().entries.map((e) {
          final groupIndex = e.key;
          final Map<String, dynamic> metrics = e.value['metrics'] ?? {};

          List<BarChartRodData> rods = [];
          for (int i = 0; i < _uniqueMetrics.length; i++) {
            final metricName = _uniqueMetrics[i];
            final val = (metrics[metricName] as num?)?.toDouble() ?? 0.0;
            rods.add(
              BarChartRodData(
                toY: val,
                color: _barColors[i % _barColors.length],
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }

          return BarChartGroupData(x: groupIndex, barsSpace: 4, barRods: rods);
        }).toList(),
      ),
    );
  }
}
