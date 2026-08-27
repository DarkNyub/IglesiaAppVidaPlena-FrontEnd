import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA

class RegistryEventDetailPage extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const RegistryEventDetailPage({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final eventName = eventData['eventName'] ?? 'Detalle del Reporte';
    var rawJson = eventData['dataJson'];

    if (rawJson is String) {
      try {
        rawJson = jsonDecode(rawJson);
      } catch (e) {
        rawJson = null;
      }
    }

    return MasterLayout(
      title: eventName,
      mode: PageMode.form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(colors),
            const SizedBox(height: 30),

            Text(
              "Datos del Reporte",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 15),

            rawJson == null
                ? Center(
                    child: Text(
                      "Sin datos registrados o formato inválido",
                      style: TextStyle(color: colors.text),
                    ),
                  )
                : _buildDynamicJsonViewer(rawJson, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AppThemeColors colors) {
    final dateStr = eventData['eventDate'] ?? eventData['registryDate'];
    final date = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          _rowInfo(
            "Fecha:",
            DateFormat('yyyy-MM-dd HH:mm').format(date),
            colors,
          ),
          Divider(color: colors.cardBorder, height: 20),
          _rowInfo("Responsable:", eventData['leaderName'] ?? 'N/A', colors),
          Divider(color: colors.cardBorder, height: 20),
          _rowInfo("Formulario:", eventData['recordTypeName'] ?? 'N/A', colors),
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String value, AppThemeColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.text.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDynamicJsonViewer(dynamic json, AppThemeColors colors) {
    if (json is! Map)
      return Text(
        "Formato de datos no visualizable: $json",
        style: TextStyle(color: colors.text),
      );

    List<Widget> widgets = [];
    json.forEach((key, value) {
      String label = key.replaceAll('_', ' ').toUpperCase();
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: colors.inputBackground, // Parece un input bloqueado
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.text.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              _renderValue(value, colors),
            ],
          ),
        ),
      );
    });
    return Column(children: widgets);
  }

  Widget _renderValue(dynamic value, AppThemeColors colors) {
    if (value is List) {
      if (value.isEmpty) return Text("-", style: TextStyle(color: colors.text));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value
            .map(
              (item) => Text("• $item", style: TextStyle(color: colors.text)),
            )
            .toList(),
      );
    }
    if (value is num) {
      return Text(
        value.toString(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: colors.text,
        ),
      );
    }
    return Text(
      value.toString(),
      style: TextStyle(fontSize: 16, color: colors.text),
    );
  }
}
