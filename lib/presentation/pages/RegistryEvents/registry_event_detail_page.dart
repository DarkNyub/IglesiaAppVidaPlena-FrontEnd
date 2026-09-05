import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/user_session.dart';

class RegistryEventDetailPage extends StatelessWidget {
  final String weekTitle;
  final String eventName;
  final List<dynamic> reportsList;

  const RegistryEventDetailPage({
    super.key,
    required this.weekTitle,
    required this.eventName,
    required this.reportsList,
  });

  // 🔥 CÁLCULO DEL CONSOLIDADO MATEMÁTICO ORDENADO
  Map<String, num> _calculateTotals() {
    Map<String, num> totals = {};
    List<String> masterFieldOrder = [];

    // 1. Buscamos el orden maestro tomando la primera lista de campos `_field_order` disponible
    for (var report in reportsList) {
      var rawJson = report['dataJson'];
      if (rawJson is String) {
        try {
          rawJson = jsonDecode(rawJson);
        } catch (_) {
          rawJson = null;
        }
      }

      if (rawJson is Map<String, dynamic> &&
          rawJson.containsKey('_field_order')) {
        final List<dynamic> order = rawJson['_field_order'];
        masterFieldOrder = order.map((e) => e.toString()).toList();
        break; // Encontramos el orden del formulario maestro, podemos salir
      }
    }

    // 2. Acumulamos los valores numéricos de todos los reportes
    for (var report in reportsList) {
      if (report['isDeleted'] == true)
        continue; // Ignoramos anulados en la sumatoria

      var rawJson = report['dataJson'];
      if (rawJson is String) {
        try {
          rawJson = jsonDecode(rawJson);
        } catch (_) {
          rawJson = null;
        }
      }

      if (rawJson is Map<String, dynamic>) {
        rawJson.forEach((key, value) {
          if (key == '_field_order') return;

          num? numericValue;
          if (value is num) {
            numericValue = value;
          } else if (value is String) {
            numericValue = num.tryParse(value);
          }

          if (numericValue != null) {
            totals[key] = (totals[key] ?? 0) + numericValue;
          }
        });
      }
    }

    // 3. Si no encontramos un `_field_order` maestro, devolvemos los totales tal cual
    if (masterFieldOrder.isEmpty) return totals;

    // 4. Reordenamos el resultado basándonos estrictamente en la lista maestra
    Map<String, num> orderedTotals = {};
    for (var fieldKey in masterFieldOrder) {
      if (totals.containsKey(fieldKey)) {
        orderedTotals[fieldKey] = totals[fieldKey]!;
      }
    }

    // Agregamos cualquier variable numérica extra que no haya estado en el arreglo maestro
    totals.forEach((key, value) {
      if (!orderedTotals.containsKey(key)) {
        orderedTotals[key] = value;
      }
    });

    return orderedTotals;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final currentMemberId = UserSession().currentUser?.memberId;
    final totals = _calculateTotals();

    return MasterLayout(
      title: eventName,
      mode: PageMode.view,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TARJETA CABECERA DE LA SEMANA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range,
                    color: colors.iconBackground,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    weekTitle,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // LISTADO DE REPORTES RECIBIDOS PARA ESTE EVENTO
            ...reportsList.map((report) {
              final formName = report['recordTypeName'] ?? 'Formulario';
              final rawLeaderName = report['leaderName'] ?? 'Sin líder';
              final leaderId = report['leaderId'];
              final isDeleted = report['isDeleted'] ?? false;

              final bool isMyOwn =
                  (leaderId != null &&
                  currentMemberId != null &&
                  leaderId == currentMemberId);
              final String displayLeader = isMyOwn ? "Mí (Yo)" : rawLeaderName;

              final dateStr = report['registryDate'];
              final DateTime? date = dateStr != null
                  ? DateTime.tryParse(dateStr)?.toLocal()
                  : null;
              final String formattedTime = date != null
                  ? DateFormat('HH:mm').format(date)
                  : '--:--';
              final String formattedFullDate = date != null
                  ? DateFormat('dd/MM/yyyy - HH:mm').format(date)
                  : 'N/A';

              var rawJson = report['dataJson'];
              if (rawJson is String) {
                try {
                  rawJson = jsonDecode(rawJson);
                } catch (_) {
                  rawJson = null;
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                color: colors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDeleted ? colors.errorColor : colors.cardBorder,
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // RESPONSABLE, HORA Y ESTADO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: colors.iconBackground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayLeader,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 13,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text.withValues(alpha: 0.7),
                                ),
                              ),
                              if (isDeleted) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "ANULADO",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colors.errorColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // FORMULARIO Y FECHA COMPLETA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Formulario: $formName",
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.text.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            formattedFullDate,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.text.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      Divider(color: colors.cardBorder, height: 20),

                      // DATOS JSON
                      rawJson == null
                          ? Text(
                              "Sin datos registrados",
                              style: TextStyle(color: colors.text),
                            )
                          : _buildDynamicJsonViewer(rawJson, colors),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 10),

            // 🔥 PANEL DE CONSOLIDADO FINAL (TOTALIZADOR MATEMÁTICO)
            if (totals.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(top: 10, bottom: 30),
                decoration: BoxDecoration(
                  color: colors.iconBackground.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.iconBackground.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.functions,
                          color: colors.iconBackground,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "CONSOLIDADO TOTAL DE LA SEMANA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colors.text,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: colors.cardBorder, height: 20),

                    ...totals.entries.map((e) {
                      final label = e.key.replaceAll('_', ' ').toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: colors.text.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              e.value.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colors.iconBackground,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicJsonViewer(dynamic json, AppThemeColors colors) {
    if (json is! Map) return const SizedBox.shrink();

    final Map<String, dynamic> dataMap = Map<String, dynamic>.from(json);
    List<Widget> widgets = [];

    List<dynamic> order =
        dataMap['_field_order'] ??
        dataMap.keys.where((k) => k != '_field_order').toList();

    for (var key in order) {
      if (key == '_field_order' || !dataMap.containsKey(key)) continue;

      final value = dataMap[key];
      String label = key.toString().replaceAll('_', ' ').toUpperCase();

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.text.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value.toString(),
                  style: TextStyle(color: colors.text, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: widgets);
  }
}
