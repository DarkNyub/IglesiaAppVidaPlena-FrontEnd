import 'package:flutter/material.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA
import '../../../widgets/ui_components/app_inputs.dart'; // <--- LOS LEGOS

class ChurchRoleFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingRole;
  const ChurchRoleFormPage({super.key, this.existingRole});

  @override
  State<ChurchRoleFormPage> createState() => _ChurchRoleFormPageState();
}

class _ChurchRoleFormPageState extends State<ChurchRoleFormPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  double _authorityLevel = 10;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRole != null) {
      _nameCtrl.text = widget.existingRole!['name'];
      _descCtrl.text = widget.existingRole!['description'] ?? '';
      _authorityLevel = (widget.existingRole!['authorityLevel'] ?? 10)
          .toDouble();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final colors = Theme.of(
      context,
    ).extension<AppThemeColors>()!; // <-- Para el snackbar

    final payload = {
      "id": widget.existingRole?['id'],
      "name": _nameCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "authorityLevel": _authorityLevel.toInt(),
    };

    try {
      if (widget.existingRole == null) {
        await _api.post(ApiConstants.churchRoles, payload);
      } else {
        await _api.put(
          '${ApiConstants.churchRoles}/${widget.existingRole!['id']}',
          payload,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cargo guardado",
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

    return MasterLayout(
      title: widget.existingRole == null ? "Nuevo Cargo" : "Editar Cargo",
      mode: PageMode.form,
      onSave: _save,
      isSaving: _isSaving,

      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // HEADER ICON ARMONIZADO
              // Container(
              //   padding: const EdgeInsets.all(20),
              //   decoration: BoxDecoration(
              //     color: colors.iconBackground,
              //     shape: BoxShape.circle,
              //     border: Border.all(color: colors.iconBorder, width: 2),
              //   ),
              //   child: Icon(
              //     Icons.workspace_premium,
              //     size: 40,
              //     color: colors.iconColor,
              //   ),
              // ),
              // const SizedBox(height: 30),
              AppTextField(
                controller: _nameCtrl,
                label: "Nombre del Cargo",
                prefixIcon: Icons.badge,
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),

              AppTextField(
                controller: _descCtrl,
                label: "Descripción (Opcional)",
                prefixIcon: Icons.description,
                maxLines: 2,
              ),
              const SizedBox(height: 10),

              // SLIDER DE AUTORIDAD PARAMETRIZADO
              Card(
                elevation: 0,
                color: colors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.iconBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.iconBorder),
                                ),
                                child: Icon(
                                  Icons.leaderboard,
                                  size: 14,
                                  color: colors.iconColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Nivel de Autoridad",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.inputBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.inputBorder),
                            ),
                            child: Text(
                              "${_authorityLevel.toInt()}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: colors.iconBackground,
                          inactiveTrackColor: colors.text.withValues(
                            alpha: 0.1,
                          ),
                          thumbColor: colors.iconBackground,
                          overlayColor: colors.iconBackground.withValues(
                            alpha: 0.2,
                          ),
                          valueIndicatorColor: colors.iconBackground,
                        ),
                        child: Slider(
                          value: _authorityLevel,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: _authorityLevel.round().toString(),
                          onChanged: (double value) {
                            setState(() => _authorityLevel = value);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Baja",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              "Media",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              "Alta",
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
