import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';

class ReportViewerPage extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const ReportViewerPage({super.key, required this.reportData});

  @override
  State<ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends State<ReportViewerPage> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _chartPoints = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final id = widget.reportData['id'];
      final result = await _api.get('${ApiConstants.reports}/$id/data');

      if (mounted) {
        setState(() {
          _chartPoints = (result is List) ? result : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: widget.reportData['name'] ?? "Reporte",
      mode: PageMode.form,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Registros",
                              style: TextStyle(
                                color: colors.text.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "${_chartPoints.length}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Total Sumado",
                              style: TextStyle(
                                color: colors.text.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _calculateTotal(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: colors.successColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Expanded(
                    child: _buildChart(widget.reportData['type'] ?? 1, colors),
                  ),
                ],
              ),
            ),
    );
  }

  String _calculateTotal() {
    double sum = 0;
    for (var p in _chartPoints) {
      sum += (p['value'] ?? 0);
    }
    return sum.toStringAsFixed(0);
  }

  Widget _buildChart(int typeId, AppThemeColors colors) {
    if (_chartPoints.isEmpty) {
      return Center(
        child: Text(
          "No hay datos para mostrar",
          style: TextStyle(color: colors.text),
        ),
      );
    }

    switch (typeId) {
      case 1:
        return BarChart(
          BarChartData(
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final index = val.toInt();
                    if (index >= 0 && index < _chartPoints.length) {
                      String label = _chartPoints[index]['label'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          label.length > 5
                              ? '${label.substring(0, 4)}..'
                              : label,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.text.withValues(alpha: 0.8),
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, m) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                      color: colors.text.withValues(alpha: 0.6),
                      fontSize: 10,
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
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: colors.cardBorder, strokeWidth: 1),
            ),
            barGroups: _chartPoints.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (e.value['value'] as num).toDouble(),
                    color: colors.iconBackground,
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }).toList(),
          ),
        );

      case 2:
        return PieChart(
          PieChartData(
            sections: _chartPoints.asMap().entries.map((e) {
              final val = (e.value['value'] as num).toDouble();
              final pieColors = [
                colors.iconBackground,
                colors.successColor,
                colors.warningColor,
                colors.errorColor,
                colors.buttonBackground,
              ];
              return PieChartSectionData(
                value: val,
                color: pieColors[e.key % pieColors.length],
                title: val.toStringAsFixed(0),
                radius: 60,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
            centerSpaceRadius: 40,
          ),
        );

      default:
        return Center(
          child: Text(
            "Gráfico no implementado",
            style: TextStyle(color: colors.text),
          ),
        );
    }
  }
}
