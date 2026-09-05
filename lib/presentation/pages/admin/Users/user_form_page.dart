import 'package:flutter/material.dart';
import '../../../../data/services/api_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../widgets/ui_components/app_inputs.dart';
import '../../../widgets/master_layout.dart';

class UserFormPage extends StatefulWidget {
  final Map<String, dynamic>? existingUser;
  final Map<String, dynamic>? memberToLink;

  const UserFormPage({super.key, this.existingUser, this.memberToLink});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  int? _selectedRoleId;
  int? _selectedMemberId;
  bool _lockMemberSelection = false;

  List<dynamic> _availableSystemRoles = [];
  List<dynamic> _availableMembers = [];

  bool _isSaving = false;
  bool _isLoadingInitial = true;

  bool _isActive = true;
  bool _isDeleted = false;

  String? _createdBy;
  String? _createdDate;
  String? _lastModifiedBy;
  String? _lastModifiedDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final responses = await Future.wait([
        _api.get(ApiConstants.systemRoles),
        _api.get(ApiConstants.members),
      ]);

      if (mounted) {
        setState(() {
          // --- 1. FILTRO PARA ROLES DE SISTEMA (Solo Activos) ---
          if (responses[0] is List) {
            _availableSystemRoles = (responses[0] as List)
                .where((role) => role['isDeleted'] != true)
                .toList();
          } else {
            _availableSystemRoles = [];
          }

          // --- 2. FILTRO PARA MIEMBROS (Sin cuenta y Activos) ---
          if (responses[1] is List) {
            final allMembers = responses[1] as List<dynamic>;
            final currentMemberId = widget.existingUser?['memberId'];

            _availableMembers =
                allMembers.where((m) {
                  final bool isDeleted = m['isDeleted'] == true;
                  final bool hasUserAssigned = m['hasUserAccount'] == true;
                  final bool isCurrentMember =
                      currentMemberId != null && m['id'] == currentMemberId;

                  return !isDeleted && (!hasUserAssigned || isCurrentMember);
                }).toList()..sort(
                  (a, b) => (a['firstName'] ?? '').toString().compareTo(
                    (b['firstName'] ?? '').toString(),
                  ),
                );
          } else {
            _availableMembers = [];
          }

          if (widget.existingUser != null) {
            _populateExistingUser(widget.existingUser!);
          } else if (widget.memberToLink != null) {
            _populateFromMember(widget.memberToLink!);
          } else {
            _setDefaultRole();
          }

          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  void _populateExistingUser(Map<String, dynamic> user) {
    _usernameCtrl.text = user['username'] ?? '';
    _selectedMemberId = user['memberId'];
    _isActive = user['isActive'] ?? true;
    _isDeleted = user['isDeleted'] ?? false;

    _createdBy = user['createdBy'];
    _createdDate = user['createdDate'];
    _lastModifiedBy = user['lastModifiedBy'];
    _lastModifiedDate = user['lastModifiedDate'];

    final currentRoles = user['systemRoles'];
    if (currentRoles is List && currentRoles.isNotEmpty) {
      final firstRole = currentRoles.first;
      if (firstRole is Map) {
        _selectedRoleId = firstRole['id'];
      }
    }
  }

  void _populateFromMember(Map<String, dynamic> member) {
    _usernameCtrl.text = member['email'] ?? '';
    _selectedMemberId = member['id'];
    _lockMemberSelection = true;
    _setDefaultRole();
  }

  void _setDefaultRole() {
    if (_availableSystemRoles.isNotEmpty) {
      final userRole = _availableSystemRoles.firstWhere(
        (r) => r['name'] == 'User',
        orElse: () => _availableSystemRoles.first,
      );
      _selectedRoleId = userRole['id'];
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      _showSnackbar("Debes seleccionar un rol de sistema", isError: true);
      return;
    }
    if (_selectedMemberId == null) {
      _showSnackbar("Debes vincular un miembro", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    Map<String, dynamic> payload = widget.existingUser != null
        ? Map<String, dynamic>.from(widget.existingUser!)
        : {};

    payload['username'] = _usernameCtrl.text.trim();
    payload['memberId'] = _selectedMemberId;
    payload['systemRoleIds'] = [_selectedRoleId];
    payload['isActive'] = _isActive;

    payload.remove('systemRoles');
    payload.remove('memberFullName');
    payload.remove('rolesSummary');

    if (widget.existingUser == null) {
      payload["password"] = _passwordCtrl.text.trim();
    } else {
      if (_passwordCtrl.text.isNotEmpty) {
        payload["password"] = _passwordCtrl.text.trim();
      } else {
        payload.remove("password");
      }
    }

    try {
      if (widget.existingUser == null) {
        await _api.post(ApiConstants.users, payload);
      } else {
        await _api.put(
          '${ApiConstants.users}/${widget.existingUser!['id']}',
          payload,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackbar("Usuario guardado correctamente");
      }
    } catch (e) {
      if (mounted) _showSnackbar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getMemberNameForReadOnly() {
    if (widget.existingUser?['memberFullName'] != null &&
        widget.existingUser!['memberFullName'].toString().isNotEmpty) {
      return widget.existingUser!['memberFullName'];
    }
    final found = _availableMembers
        .where((m) => m['id'] == _selectedMemberId)
        .toList();
    if (found.isNotEmpty) {
      return "${found.first['firstName'] ?? ''} ${found.first['lastName'] ?? ''}"
          .trim();
    }
    return "Miembro asociado";
  }

  // 🔥 MOSTRAR MODAL DE BÚSQUEDA DE MIEMBRO
  void _openMemberSearchDialog(AppThemeColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => _MemberSearchModal(
        members: _availableMembers,
        colors: colors,
        onSelected: (member) {
          setState(() {
            _selectedMemberId = member['id'];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEditing = widget.existingUser != null;
    final sectionTitleStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: colors.text.withValues(alpha: 0.8),
    );

    final selectedMember = _availableMembers.firstWhere(
      (m) => m['id'] == _selectedMemberId,
      orElse: () => null,
    );

    return MasterLayout(
      title: isEditing ? "Editar Usuario" : "Nuevo Usuario",
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
                    Text("Configuración de Acceso", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    // --- BUSCADOR CON LÍMITE DE RESULTADOS O MODO LECTURA ---
                    if (isEditing || _lockMemberSelection)
                      AppTextField(
                        controller: TextEditingController(
                          text: _getMemberNameForReadOnly(),
                        ),
                        label: "Miembro Asociado",
                        prefixIcon: Icons.lock_person,
                        readOnly: true,
                      )
                    else ...[
                      // TARJETA DE SELECCIÓN DE MIEMBRO CON BUSCADOR MODAL
                      InkWell(
                        onTap: () => _openMemberSearchDialog(colors),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedMemberId == null
                                  ? colors.cardBorder
                                  : colors.iconBackground,
                              width: _selectedMemberId == null ? 1 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_search,
                                color: colors.iconColor,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Vincular a Miembro",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.text.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedMember != null
                                          ? "${selectedMember['firstName']} ${selectedMember['lastName']}"
                                          : "Toca para buscar y seleccionar...",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: selectedMember != null
                                            ? colors.text
                                            : colors.text.withValues(
                                                alpha: 0.5,
                                              ),
                                        fontWeight: selectedMember != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: colors.text.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedMemberId == null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            "Requerido",
                            style: TextStyle(
                              color: colors.errorColor,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const SizedBox(height: 15),
                    ],

                    AppTextField(
                      controller: _usernameCtrl,
                      label: "Nombre de Usuario (Login)",
                      prefixIcon: Icons.account_circle,
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),

                    AppTextField(
                      controller: _passwordCtrl,
                      isPassword: true,
                      label: isEditing
                          ? "Nueva Contraseña (Opcional)"
                          : "Contraseña",
                      prefixIcon: Icons.lock,
                      validator: (v) {
                        if (!isEditing && (v == null || v.isEmpty)) {
                          return "Requerido";
                        }
                        if (v != null && v.isNotEmpty && v.length < 6) {
                          return "Mínimo 6 caracteres";
                        }
                        return null;
                      },
                    ),
                    if (isEditing)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, bottom: 10.0),
                        child: Text(
                          "Deje en blanco para mantener la contraseña actual.",
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    const Divider(height: 20),

                    Text("Nivel de Permisos", style: sectionTitleStyle),
                    const SizedBox(height: 15),

                    AppDropdown<int>(
                      value: _selectedRoleId,
                      label: "Rol del Sistema",
                      items: _availableSystemRoles.map<DropdownMenuItem<int>>((
                        roleItem,
                      ) {
                        return DropdownMenuItem<int>(
                          value: roleItem['id'],
                          child: Text(roleItem['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedRoleId = val),
                      validator: (v) => v == null ? "Requerido" : null,
                    ),

                    if (isEditing) ...[
                      const Divider(height: 20),

                      Text("Estado de la Cuenta", style: sectionTitleStyle),
                      const SizedBox(height: 15),

                      Card(
                        color: colors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: colors.cardBorder),
                        ),
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              _isActive ? Icons.check_circle : Icons.block,
                              color: colors.iconColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _isActive ? "Usuario Activo" : "Usuario Suspendido",
                            style: TextStyle(
                              color: colors.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? "Puede iniciar sesión en el sistema"
                                : "El acceso se encuentra bloqueado",
                            style: TextStyle(
                              color: colors.text.withValues(alpha: 0.7),
                            ),
                          ),
                          trailing: Switch(
                            value: _isActive,
                            activeThumbColor: colors.iconBackground,
                            inactiveThumbColor: colors.text.withValues(
                              alpha: 0.5,
                            ),
                            activeTrackColor: colors.iconBackground.withValues(
                              alpha: 0.5,
                            ),
                            inactiveTrackColor: colors.text.withValues(
                              alpha: 0.2,
                            ),
                            onChanged: (val) => setState(() => _isActive = val),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

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
                                "⚠️ ESTA CUENTA ESTÁ MARCADA COMO ELIMINADA",
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
                    ],
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }
}

// ============================================================================
// 🔥 COMPONENTE MODAL: BUSCADOR DE MIEMBROS CON LÍMITE DE 6 RESULTADOS
// ============================================================================
class _MemberSearchModal extends StatefulWidget {
  final List<dynamic> members;
  final AppThemeColors colors;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MemberSearchModal({
    required this.members,
    required this.colors,
    required this.onSelected,
  });

  @override
  State<_MemberSearchModal> createState() => _MemberSearchModalState();
}

class _MemberSearchModalState extends State<_MemberSearchModal> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 1. Filtrar por nombre / apellido
    final filtered = widget.members.where((m) {
      final name = "${m['firstName'] ?? ''} ${m['lastName'] ?? ''}"
          .toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    // 2. 🔥 REGLA DE ORO: Máximo 6 resultados a lo mucho
    final limitedResults = filtered.take(6).toList();

    return Dialog(
      backgroundColor: widget.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.colors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Buscar Miembro",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.colors.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.colors.text),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CAJA DE BÚSQUEDA
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: widget.colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Escribe un nombre...",
                hintStyle: TextStyle(
                  color: widget.colors.text.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: widget.colors.iconColor,
                  size: 20,
                ),
                filled: true,
                fillColor: widget.colors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.colors.iconBackground),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),

            // INDICADOR DE COINCIDENCIAS / AYUDA VISUAL
            Text(
              _query.isEmpty
                  ? "Escriba para filtrar los miembros disponibles:"
                  : "Mostrando ${limitedResults.length} de ${filtered.length} coincidencias:",
              style: TextStyle(
                fontSize: 11,
                color: widget.colors.text.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),

            // LISTA RESTRINGIDA (MÁXIMO 6)
            if (limitedResults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    "No se encontraron miembros.",
                    style: TextStyle(
                      color: widget.colors.text.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: limitedResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: widget.colors.cardBorder, height: 1),
                  itemBuilder: (ctx, idx) {
                    final member = limitedResults[idx];
                    final fullName =
                        "${member['firstName']} ${member['lastName']}";
                    final email = member['email'] ?? 'Sin correo';

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: widget.colors.iconBackground,
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.colors.iconColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        fullName,
                        style: TextStyle(
                          color: widget.colors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        email,
                        style: TextStyle(
                          color: widget.colors.text.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        widget.onSelected(member);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
