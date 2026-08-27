import 'package:flutter/material.dart';
import '../../../data/services/api_service.dart';
import '../../../core/system_role_manager.dart';
import '../../../core/constants/api_constants.dart';
import '../../widgets/dynamic_field.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA

class RegistryFormPage extends StatefulWidget {
  final int eventId;
  final String eventName;

  const RegistryFormPage({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<RegistryFormPage> createState() => _RegistryFormState();
}

class _RegistryFormState extends State<RegistryFormPage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _formStructure;
  final Map<String, dynamic> _formData = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadFormStructure();
  }

  Future<void> _loadFormStructure() async {
    try {
      final data = await _api.get(ApiConstants.eventStructure(widget.eventId));

      if (mounted) {
        setState(() {
          _formStructure = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('404')
              ? 'Este evento no tiene un formulario de reporte asignado.'
              : e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_formStructure == null || _formStructure!['recordTypeId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: Estructura de formulario inválida",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.errorColor,
        ),
      );
      return;
    }

    final int recordTypeId = _formStructure!['recordTypeId'];
    setState(() => _isLoading = true);

    try {
      final payload = {
        "eventId": widget.eventId,
        "recordTypeId": recordTypeId,
        "dataJson": _formData,
      };

      await _api.post(ApiConstants.registryEvents, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reporte enviado exitosamente',
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: ${e.toString()}',
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
    return MasterLayout(
      title: widget.eventName,
      mode: PageMode.form,
      onSave: _submitForm,
      isSaving: _isLoading,
      child: _buildBody(), // Eliminado el Container(color: Colors.grey)
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: colors.iconBackground),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_late_outlined,
                size: 60,
                color: colors.text.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 16,
                  color: colors.text.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: colors.buttonText),
                label: Text(
                  "Volver",
                  style: TextStyle(color: colors.buttonText),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonBackground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_formStructure == null) {
      return Center(
        child: Text(
          "Error desconocido cargando el formulario.",
          style: TextStyle(color: colors.text),
        ),
      );
    }

    final List<dynamic> fields = _formStructure!['fields'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER DEL FORMULARIO
            Container(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formStructure!['formName'] ?? 'Reporte de Evento',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                  if (_formStructure!['formDescription'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _formStructure!['formDescription'],
                        style: TextStyle(
                          color: colors.text.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Divider(color: colors.cardBorder),
            const SizedBox(height: 10),

            // CAMPOS DINÁMICOS
            SystemRoleManager(
              allowedRoles: const [
                SystemRoles.superAdmin,
                SystemRoles.admin,
                SystemRoles.lider,
              ],
              absorbPointer: true,
              child: Column(
                children: fields.map((fieldConfig) {
                  return DynamicFieldWidget(
                    fieldConfig: fieldConfig,
                    onValueChanged: (key, value) {
                      _formData[key] = value;
                    },
                  );
                }).toList(),
              ),
            ),

            // AVISO SI NO TIENE PERMISOS (UNIFICADO A LA MOCHILA)
            SystemRoleManager(
              allowedRoles: const [
                SystemRoles.superAdmin,
                SystemRoles.admin,
                SystemRoles.lider,
              ],
              fallback: Container(
                margin: const EdgeInsets.only(top: 30),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.warningColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: colors.warningColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Modo Lectura: No tienes permisos para enviar este reporte.",
                        style: TextStyle(
                          color: colors.warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child: const SizedBox.shrink(),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
