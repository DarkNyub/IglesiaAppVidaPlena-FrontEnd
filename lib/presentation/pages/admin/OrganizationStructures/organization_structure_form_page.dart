import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';
import '../../../widgets/ui_components/organization_structure_selector.dart';

class OrganizationStructureFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingStructure;
  const OrganizationStructureFormPage({super.key, this.existingStructure});

  @override
  State<OrganizationStructureFormPage> createState() =>
      _OrganizationStructureFormPageState();
}

class _OrganizationStructureFormPageState
    extends State<OrganizationStructureFormPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int? _selectedTypeId;
  int? _selectedParentId;

  List<dynamic> _orgTypes = [];
  List<dynamic> _flatStructures = [];
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  // 🔥 VARIABLES PARA LA FOTO
  File? _imageFile;
  String? _photoBase64;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final responses = await Future.wait([
        _api.get(ApiConstants.organizationTypes),
        _api.get(ApiConstants.organizationStructures),
      ]);

      if (mounted) {
        setState(() {
          final currentType =
              widget.existingStructure?['organizationTypeId'] ??
              widget.existingStructure?['organization_type_id'];
          _orgTypes = responses[0] is List
              ? (responses[0] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          (currentType != null && e['id'] == currentType),
                    )
                    .toList()
              : [];

          final currentParent =
              widget.existingStructure?['parentId'] ??
              widget.existingStructure?['parent_id'];
          _flatStructures = responses[1] is List
              ? (responses[1] as List)
                    .where(
                      (e) =>
                          e['isDeleted'] != true ||
                          (currentParent != null && e['id'] == currentParent),
                    )
                    .toList()
              : [];

          if (widget.existingStructure != null) {
            final myId = widget.existingStructure!['id'];
            _flatStructures.removeWhere((p) => p['id'] == myId);
            _initFormData();
          }

          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  void _initFormData() {
    final e = widget.existingStructure!;
    _nameCtrl.text = e['name'] ?? '';
    _descCtrl.text = e['description'] ?? '';

    _selectedTypeId = e['organizationTypeId'] ?? e['organization_type_id'];
    _selectedParentId = e['parentId'] ?? e['parent_id'];

    // 🔥 RECUPERAMOS LA URL SI EXISTE
    _currentPhotoUrl = e['photoUrl'];
  }

  // 🔥 LÓGICA DE SELECCIÓN Y RECORTE DE IMAGEN
  Future<void> _pickAndCropImage() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 70, // Calidad del 70% para mantenerlo bajo 1MB
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Encuadrar Logotipo',
              toolbarColor: colors.cardBackground,
              toolbarWidgetColor: colors.text,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true, // Obliga a que sea cuadrado 1:1
              hideBottomControls: true,
            ),
            IOSUiSettings(
              title: 'Encuadrar Logotipo',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          final file = File(croppedFile.path);
          final bytes = await file.readAsBytes();

          setState(() {
            _imageFile = file;
            _photoBase64 = base64Encode(bytes); // Listo para irse a GitHub
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error al procesar la imagen: $e",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final payload = {
      "id": widget.existingStructure?['id'],
      "name": _nameCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "organizationTypeId": _selectedTypeId,
      "parentId": _selectedParentId,
    };

    // 🔥 INYECTAMOS EL BASE64 SI EL USUARIO SELECCIONÓ UNA FOTO NUEVA
    if (_photoBase64 != null) {
      payload['photoBase64'] = _photoBase64;
    }

    try {
      if (widget.existingStructure == null) {
        await _api.post(ApiConstants.organizationStructures, payload);
      } else {
        await _api.put(
          '${ApiConstants.organizationStructures}/${widget.existingStructure!['id']}',
          payload,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Estructura guardada",
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
      title: widget.existingStructure != null
          ? "Editar Estructura"
          : "Nueva Estructura",
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
                    // 🔥 SECCIÓN DE FOTO O LOGO
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickAndCropImage,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.iconBackground.withValues(
                                  alpha: 0.1,
                                ),
                                border: Border.all(
                                  color: colors.iconBorder,
                                  width: 2,
                                ),
                                image: _imageFile != null
                                    ? DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : (_currentPhotoUrl != null &&
                                          _currentPhotoUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(_currentPhotoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child:
                                  (_imageFile == null &&
                                      (_currentPhotoUrl == null ||
                                          _currentPhotoUrl!.isEmpty))
                                  ? Icon(
                                      Icons.business,
                                      size: 60,
                                      color: colors.iconBackground.withValues(
                                        alpha: 0.5,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndCropImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.iconBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.cardBackground,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: colors.iconColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: colors.iconColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Define una unidad (Red, Grupo, Ministerio) y de quién depende jerárquicamente.",
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    AppTextField(
                      controller: _nameCtrl,
                      label: "Nombre",
                      prefixIcon: Icons.business,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),

                    AppDropdown<int>(
                      value: _selectedTypeId,
                      label: "Tipo de Organización",
                      items: _orgTypes
                          .map(
                            (t) => DropdownMenuItem<int>(
                              value: t['id'],
                              child: Text(t['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedTypeId = val),
                      validator: (v) => v == null ? "Requerido" : null,
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        OrganizationStructureSelector(
                          value: _selectedParentId,
                          structures: _flatStructures,
                          label: "Pertenece a (Padre)",
                          allowNull: true,
                          nullLabel: "(Sin Padre - Raíz)",
                          onChanged: (val) =>
                              setState(() => _selectedParentId = val),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                    AppTextField(
                      controller: _descCtrl,
                      label: "Descripción",
                      prefixIcon: Icons.description,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
