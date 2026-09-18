import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';
import '../../../widgets/master_layout.dart';
import '../Users/user_form_page.dart';
import '../../../widgets/ui_components/organization_structure_selector.dart';

class MemberFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingMember;
  const MemberFormPage({super.key, this.existingMember});

  @override
  State<MemberFormPage> createState() => _MemberFormPageState();
}

class _MemberFormPageState extends State<MemberFormPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _fnameCtrl = TextEditingController();
  final _lnameCtrl = TextEditingController();
  final _docCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  DateTime? _selectedBirthDate;
  bool _isLoadingInitial = true;
  bool _isSaving = false;

  List<dynamic> _structures = [];
  List<dynamic> _churchRoles = [];
  final List<Map<String, dynamic>> _assignedRoles = [];
  final List<Map<String, String>> _extraDataList = [];

  Map<String, dynamic>? _linkedUserObj;
  String? _createdBy;
  String? _createdDate;
  String? _lastModifiedBy;
  String? _lastModifiedDate;
  bool _isDeleted = false;

  // 🔥 VARIABLES PARA LA FOTO
  File? _imageFile;
  String? _photoBase64;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadCatalogsAndData();
  }

  Future<void> _loadCatalogsAndData() async {
    try {
      final responses = await Future.wait([
        _api.get(ApiConstants.organizationStructures),
        _api.get(ApiConstants.churchRoles),
      ]);

      if (mounted) {
        setState(() {
          _structures = (responses[0] is List)
              ? (responses[0] as List)
                    .where((e) => e['isDeleted'] != true)
                    .toList()
              : [];
          _churchRoles = (responses[1] is List)
              ? (responses[1] as List)
                    .where((e) => e['isDeleted'] != true)
                    .toList()
              : [];
        });

        if (widget.existingMember != null) {
          final id = widget.existingMember!['id'];
          final freshData = await _api.get('${ApiConstants.members}/$id');
          _populateData(freshData);
        }

        setState(() => _isLoadingInitial = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        _showSnackbar("Error cargando datos: $e", isError: true);
      }
    }
  }

  void _populateData(Map<String, dynamic> e) {
    _fnameCtrl.text = e['firstName'] ?? '';
    _lnameCtrl.text = e['lastName'] ?? '';
    _docCtrl.text = e['document'] ?? '';
    _emailCtrl.text = e['email'] ?? '';
    _phoneCtrl.text = e['phone'] ?? '';
    _addressCtrl.text = e['address'] ?? '';
    _isDeleted = e['isDeleted'] ?? false;
    _currentPhotoUrl = e['photoUrl']; // 🔥 RECUPERAMOS LA URL SI EXISTE

    if (e['birthDate'] != null &&
        !e['birthDate'].toString().startsWith("0001")) {
      try {
        _selectedBirthDate = DateTime.parse(e['birthDate']);
        _birthDateCtrl.text = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedBirthDate!);
      } catch (_) {}
    }

    _linkedUserObj = e['linkedUser'];
    _createdBy = e['createdBy'];
    _createdDate = e['createdDate'];
    _lastModifiedBy = e['lastModifiedBy'];
    _lastModifiedDate = e['lastModifiedDate'];

    if (e['extraData'] != null && e['extraData']['items'] is List) {
      for (var item in e['extraData']['items']) {
        if (item != null) {
          _extraDataList.add({
            "category": item['category']?.toString() ?? "",
            "key": item['key']?.toString() ?? "",
            "value": item['value']?.toString() ?? "",
          });
        }
      }
    }

    final rawRoles = e['roles'] ?? [];
    if (rawRoles is List) {
      for (var r in rawRoles) {
        _assignedRoles.add({
          "structureId": r['organizationStructureId'],
          "roleId": r['churchFunctionRoleId'],
          "structureName":
              r['organizationName'] ??
              "Estructura ID ${r['organizationStructureId']}",
          "roleName": r['roleName'] ?? "Rol ID ${r['churchFunctionRoleId']}",
        });
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: colors.text)),
        backgroundColor: isError ? colors.errorColor : colors.successColor,
      ),
    );
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
              toolbarTitle: 'Encuadrar Foto',
              toolbarColor: colors.cardBackground,
              toolbarWidgetColor: colors.text,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true, // Obliga a que sea cuadrado 1:1
              hideBottomControls: true,
            ),
            IOSUiSettings(
              title: 'Encuadrar Foto',
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
      _showSnackbar("Error al procesar la imagen: $e", isError: true);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colors.iconColor,
              onPrimary: colors.iconBackground,
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
        _selectedBirthDate = date;
        _birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  void _removeRole(int index) => setState(() => _assignedRoles.removeAt(index));

  void _showAddRoleDialog() {
    int? selectedStruct;
    int? selectedRole;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: colors.cardBackground,
          title: Text("Asignar Cargo", style: TextStyle(color: colors.text)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrganizationStructureSelector(
                value: selectedStruct,
                structures: _structures,
                label: "Estructura Organizacional",
                onChanged: (v) => setModalState(() => selectedStruct = v),
              ),
              AppDropdown<int>(
                value: selectedRole,
                label: "Rol",
                items: _churchRoles
                    .map(
                      (r) => DropdownMenuItem<int>(
                        value: r['id'],
                        child: Text(r['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setModalState(() => selectedRole = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar", style: TextStyle(color: colors.text)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStruct != null && selectedRole != null) {
                  final exists = _assignedRoles.any(
                    (x) =>
                        x['structureId'] == selectedStruct &&
                        x['roleId'] == selectedRole,
                  );
                  if (exists) {
                    Navigator.pop(ctx);
                    return;
                  }

                  setState(() {
                    _assignedRoles.add({
                      "structureId": selectedStruct,
                      "roleId": selectedRole,
                      "structureName": _structures.firstWhere(
                        (s) => s['id'] == selectedStruct,
                      )['name'],
                      "roleName": _churchRoles.firstWhere(
                        (r) => r['id'] == selectedRole,
                      )['name'],
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.buttonBackground,
              ),
              child: Text(
                "Agregar",
                style: TextStyle(color: colors.buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addExtraDataField() => setState(
    () => _extraDataList.add({"category": "", "key": "", "value": ""}),
  );
  void _removeExtraDataField(int index) =>
      setState(() => _extraDataList.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    Map<String, dynamic> payload = {
      'firstName': _fnameCtrl.text.trim(),
      'lastName': _lnameCtrl.text.trim(),
      'document': _docCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'isDeleted': _isDeleted,
      'birthDate': _selectedBirthDate?.toIso8601String(),
      'extraData': {"items": _extraDataList},
      'roles': _assignedRoles
          .map((r) => {"structureId": r['structureId'], "roleId": r['roleId']})
          .toList(),
    };

    // 🔥 INYECTAMOS EL BASE64 SI EL USUARIO SELECCIONÓ UNA FOTO NUEVA
    if (_photoBase64 != null) {
      payload['photoBase64'] = _photoBase64;
    }

    try {
      if (widget.existingMember == null) {
        await _api.post(ApiConstants.members, payload);
      } else {
        await _api.put(
          '${ApiConstants.members}/${widget.existingMember!['id']}',
          payload,
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        _showSnackbar("Guardado correctamente");
      }
    } catch (e) {
      if (mounted) _showSnackbar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _navigateToUser(Map<String, dynamic> userSimple) async {
    try {
      final userFull = await GenericRepository(
        endpoint: ApiConstants.users,
      ).getById(userSimple['id']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserFormPage(existingUser: userFull),
          ),
        );
      }
    } catch (e) {
      _showSnackbar("Error cargando usuario: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final sectionTitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: colors.text.withValues(alpha: 0.8),
    );

    return MasterLayout(
      title: widget.existingMember != null ? "Editar Miembro" : "Nuevo Miembro",
      mode: PageMode.form,
      onSave: _save,
      isSaving: _isSaving,
      child: _isLoadingInitial
          ? Center(child: CircularProgressIndicator(color: colors.iconColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 SECCIÓN DE FOTO DE PERFIL
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
                                      Icons.person,
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

                    if (_linkedUserObj != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(8),
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
                                Icons.account_circle,
                                color: colors.iconColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Usuario Vinculado:",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.text.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    _linkedUserObj!['username'] ?? 'Usuario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: colors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _navigateToUser(_linkedUserObj!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.buttonBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                "Ver Usuario",
                                style: TextStyle(
                                  color: colors.buttonText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text("Datos Personales", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _fnameCtrl,
                            label: "Nombres",
                            validator: (v) => v!.isEmpty ? "*" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: _lnameCtrl,
                            label: "Apellidos",
                            validator: (v) => v!.isEmpty ? "*" : null,
                          ),
                        ),
                      ],
                    ),

                    AppTextField(
                      controller: _docCtrl,
                      label: "Documento de Identidad / Cédula",
                      prefixIcon: Icons.badge_outlined,
                    ),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: "Teléfono",
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone,
                    ),
                    AppTextField(
                      controller: _emailCtrl,
                      label: "Email",
                      prefixIcon: Icons.email,
                    ),
                    AppTextField(
                      controller: _birthDateCtrl,
                      label: "Fecha Nacimiento",
                      prefixIcon: Icons.cake,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    AppTextField(
                      controller: _addressCtrl,
                      label: "Dirección",
                      prefixIcon: Icons.home,
                    ),

                    const Divider(height: 40),

                    // ==========================================
                    // ROLES Y CARGOS
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Roles y Cargos", style: sectionTitleStyle),
                        InkWell(
                          onTap: _showAddRoleDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.add,
                              color: colors.iconColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_assignedRoles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Sin roles asignados",
                          style: TextStyle(
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    ..._assignedRoles.asMap().entries.map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: colors.cardBackground,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: colors.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.verified_user,
                              color: colors.iconColor,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            entry.value['roleName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.text,
                            ),
                          ),
                          subtitle: Text(
                            "En: ${entry.value['structureName']}",
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.7),
                            ),
                          ),
                          trailing: InkWell(
                            onTap: () => _removeRole(entry.key),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.iconBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.iconBorder),
                              ),
                              child: Icon(
                                Icons.close,
                                color: colors.iconColor,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 40),

                    // ==========================================
                    // DATOS EXTRA
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Datos Extra", style: sectionTitleStyle),
                        InkWell(
                          onTap: _addExtraDataField,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.add,
                              color: colors.iconColor,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_extraDataList.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Sin datos adicionales",
                          style: TextStyle(
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    ..._extraDataList.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: entry.value['category'],
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Categoría",
                                  labelStyle: TextStyle(
                                    color: colors.text.withValues(alpha: 0.6),
                                  ),
                                  isDense: true,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: colors.inputBorder,
                                    ),
                                  ),
                                ),
                                onChanged: (v) => entry.value['category'] = v,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextFormField(
                                initialValue: entry.value['key'],
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Clave",
                                  labelStyle: TextStyle(
                                    color: colors.text.withValues(alpha: 0.6),
                                  ),
                                  isDense: true,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: colors.inputBorder,
                                    ),
                                  ),
                                ),
                                onChanged: (v) => entry.value['key'] = v,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextFormField(
                                initialValue: entry.value['value'],
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Valor",
                                  labelStyle: TextStyle(
                                    color: colors.text.withValues(alpha: 0.6),
                                  ),
                                  isDense: true,
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: colors.inputBorder,
                                    ),
                                  ),
                                ),
                                onChanged: (v) => entry.value['value'] = v,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              child: InkWell(
                                onTap: () => _removeExtraDataField(entry.key),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colors.iconBackground,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.iconBorder,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: colors.iconColor,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    if (widget.existingMember != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          border: Border.all(color: colors.cardBorder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Información de Auditoría",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: colors.text.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (_isDeleted)
                              Text(
                                "⚠️ ESTE REGISTRO ESTÁ MARCADO COMO ELIMINADO",
                                style: TextStyle(
                                  color: colors.errorColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              "Creado por: ${_createdBy ?? '-'} el ${_createdDate ?? '-'}",
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.text.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              "Modificado por: ${_lastModifiedBy ?? '-'} el ${_lastModifiedDate ?? '-'}",
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.text.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }
}
