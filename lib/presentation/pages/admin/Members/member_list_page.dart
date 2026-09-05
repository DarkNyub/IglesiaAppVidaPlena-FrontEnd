import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/user_session.dart';
import '../../../../core/system_role_manager.dart';
import '../../../../core/app_theme_colors.dart';
import '../Users/user_form_page.dart';
import 'member_form_page.dart';

class MemberListPage extends StatefulWidget {
  const MemberListPage({super.key});

  @override
  State<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends State<MemberListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.members);
  final _session = UserSession();

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];

  bool _isLoading = true;
  String _currentQuery = '';
  String _sortBy = 'name';
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _repo.getAll();
      if (mounted) {
        setState(() {
          _allItems = (data is List) ? data : [];
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<dynamic> temp = _allItems;
    if (_currentQuery.isNotEmpty) {
      final lower = _currentQuery.toLowerCase();
      temp = _allItems.where((item) {
        final fname = (item['firstName'] ?? '').toString().toLowerCase();
        final lname = (item['lastName'] ?? '').toString().toLowerCase();
        final email = (item['email'] ?? '').toString().toLowerCase();
        final phone = (item['phone'] ?? '').toString().toLowerCase();
        return fname.contains(lower) ||
            lname.contains(lower) ||
            email.contains(lower) ||
            phone.contains(lower);
      }).toList();
    }
    temp.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'email':
          cmp = (a['email'] ?? "").toString().compareTo(b['email'] ?? "");
          break;
        case 'status':
          final delA = (a['isDeleted'] == true) ? 1 : 0;
          final delB = (b['isDeleted'] == true) ? 1 : 0;
          cmp = delA.compareTo(delB);
          break;
        case 'name':
        default:
          final nameA = "${a['firstName']} ${a['lastName']}";
          final nameB = "${b['firstName']} ${b['lastName']}";
          cmp = nameA.compareTo(nameB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });
    setState(() => _filteredItems = temp);
  }

  Future<void> _navigateToForm([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberFormPage(existingMember: item)),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToUser(Map<String, dynamic> userSimple) async {
    final userRepo = GenericRepository(endpoint: ApiConstants.users);
    try {
      final userFull = await userRepo.getById(userSimple['id']);
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

  void _showSnackbar(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    Color bg = colors.successColor;
    if (isError) bg = colors.errorColor;
    if (isWarning) bg = colors.warningColor;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colors.text)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleMemberStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    final linkedUser = item['linkedUser'];

    final normalizedRole = SystemRoles.normalize(_session.role);
    if (normalizedRole != SystemRoles.superAdmin &&
        normalizedRole != SystemRoles.admin) {
      _showSnackbar(
        "No tienes permisos para dar de baja a miembros.",
        isError: true,
      );
      return;
    }

    if (linkedUser != null && linkedUser['id'] == _session.currentUser?.id) {
      _showSnackbar("No puedes darte de baja a ti mismo.", isWarning: true);
      return;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          isDeleted ? "Reactivar Miembro" : "Dar de Baja",
          style: TextStyle(color: colors.text),
        ),
        content: Text(
          isDeleted
              ? "El miembro pasará a estado ACTIVO nuevamente."
              : "El miembro pasará a estado INACTIVO.",
          style: TextStyle(color: colors.text.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: TextStyle(color: colors.text)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDeleted
                  ? colors.successColor
                  : colors.errorColor,
            ),
            child: Text(
              isDeleted ? "Reactivar" : "Dar de Baja",
              style: TextStyle(color: colors.buttonText),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _repo.customPost(item['id'], 'toggle-status');
      await _loadData();
      _showSnackbar(isDeleted ? "Miembro reactivado" : "Miembro dado de baja");
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackbar("Error: $e", isError: true);
    }
  }

  void _copyToClipboard(String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackbar("$type copiado al portapapeles");
  }

  void _showRolesPopup(List<dynamic> roles, AppThemeColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text("Cargos y Roles", style: TextStyle(color: colors.text)),
        content: roles.isEmpty
            ? Text("Sin roles asignados.", style: TextStyle(color: colors.text))
            : SizedBox(
                width: double.maxFinite,
                height: 250,
                child: ListView.builder(
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.text.withValues(alpha: 0.05),
                        border: Border.all(color: colors.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roles[index].toString(),
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cerrar", style: TextStyle(color: colors.text)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARGA MASIVA DE MIEMBROS (EXCEL)
  // ==========================================
  void _showExcelHelpDialog() {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          "Formato del Excel",
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Asegúrate de que la Hoja 1 de tu Excel tenga este orden exacto de columnas. La fila 1 se asume que son títulos y será ignorada.",
                style: TextStyle(color: colors.text.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 15),
              _excelCol("A", "Nombres (Obligatorio)", colors),
              _excelCol("B", "Apellidos (Obligatorio)", colors),
              _excelCol("C", "Documento/Cédula", colors),
              _excelCol("D", "Teléfono", colors),
              _excelCol("E", "Email", colors),
              _excelCol("F", "Dirección", colors),
              _excelCol("G", "ID de la Estructura (Red/Min)", colors),
              _excelCol("H", "ID del Rol/Cargo", colors),
              const SizedBox(height: 15),
              Text(
                "Nota: Para asignar rol (G y H), debes poner el número de ID correspondiente según tus catálogos. Si dejas G y H en blanco, se creará el miembro sin cargo.",
                style: TextStyle(
                  color: colors.warningColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleBulkUpload();
            },
            child: Text(
              "Entendido, Seleccionar Archivo",
              style: TextStyle(
                color: colors.iconBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _excelCol(String letter, String desc, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.iconBackground.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.iconBackground,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc, style: TextStyle(color: colors.text)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBulkUpload() async {
    try {
      List<PlatformFile> result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result.isEmpty) return;

      setState(() => _isLoading = true);

      Uint8List? bytes = await result.first.readAsBytes();
      if (bytes == null) {
        throw Exception("No se pudieron leer los datos del archivo.");
      }

      var excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> membersToUpload = [];

      String firstTable = excel.tables.keys.first;
      var rows = excel.tables[firstTable]!.rows;

      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty ||
            row[0]?.value == null ||
            row[0]!.value.toString().trim().isEmpty) {
          continue;
        }

        // Parseo seguro de números (IDs)
        int? structureId;
        int? roleId;
        if (row.length > 6 && row[6]?.value != null) {
          structureId = int.tryParse(
            row[6]!.value.toString().replaceAll('.0', ''),
          );
        }
        if (row.length > 7 && row[7]?.value != null) {
          roleId = int.tryParse(row[7]!.value.toString().replaceAll('.0', ''));
        }

        Map<String, dynamic> memberPayload = {
          "firstName": row[0]?.value?.toString().trim() ?? "",
          "lastName":
              (row.length > 1 ? row[1]?.value?.toString().trim() : "") ?? "",
          "document":
              (row.length > 2 ? row[2]?.value?.toString().trim() : "") ?? "",
          "phone":
              (row.length > 3 ? row[3]?.value?.toString().trim() : "") ?? "",
          "email":
              (row.length > 4 ? row[4]?.value?.toString().trim() : "") ?? "",
          "address":
              (row.length > 5 ? row[5]?.value?.toString().trim() : "") ?? "",
        };

        if (structureId != null &&
            structureId > 0 &&
            roleId != null &&
            roleId > 0) {
          memberPayload["roles"] = [
            {"structureId": structureId, "roleId": roleId},
          ];
        } else {
          memberPayload["roles"] = [];
        }

        membersToUpload.add(memberPayload);
      }

      if (membersToUpload.isEmpty) {
        _showSnackbar(
          "El archivo está vacío o sin nombres válidos.",
          isError: true,
        );
        return;
      }

      final response = await _repo.customPost(0, 'bulk-upload', {
        "members": membersToUpload,
      });
      await _loadData();
      final count = response['count'] ?? membersToUpload.length;
      _showSnackbar("¡Se cargaron $count miembros exitosamente!");
    } catch (e) {
      _showSnackbar("Error al procesar el Excel: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedRole = SystemRoles.normalize(_session.role);
    final canManageStatus =
        normalizedRole == SystemRoles.superAdmin ||
        normalizedRole == SystemRoles.admin;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Directorio de Miembros",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Nombre Completo", "name"),
        SortOption("Email", "email"),
        SortOption("Estado", "status"),
      ],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      onAdd: () => _navigateToForm(),

      // 🔥 AGREGAMOS EL BOTÓN EXTRA AQUÍ AL MASTER LAYOUT
      actions: [
        if (canManageStatus)
          IconButton(
            icon: Icon(Icons.file_upload, color: colors.text),
            tooltip: "Carga Masiva (Excel)",
            onPressed: _isLoading ? null : _showExcelHelpDialog,
          ),
      ],

      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No se encontraron miembros",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                return _MemberCardItem(
                  item: _filteredItems[index],
                  colors: colors,
                  canManageStatus: canManageStatus,
                  onEdit: () => _navigateToForm(_filteredItems[index]),
                  onToggle: () => _toggleMemberStatus(_filteredItems[index]),
                  onUser: () {
                    final linkedUser = _filteredItems[index]['linkedUser'];
                    if (linkedUser != null) _navigateToUser(linkedUser);
                  },
                  onShowRoles: () => _showRolesPopup(
                    _filteredItems[index]['rolesSummary'] ?? [],
                    colors,
                  ),
                  onCopy: (text, type) => _copyToClipboard(text, type),
                );
              },
            ),
    );
  }
}

class _MemberCardItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final AppThemeColors colors;
  final bool canManageStatus;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onUser;
  final VoidCallback onShowRoles;
  final Function(String, String) onCopy;

  const _MemberCardItem({
    required this.item,
    required this.colors,
    required this.canManageStatus,
    required this.onEdit,
    required this.onToggle,
    required this.onUser,
    required this.onShowRoles,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final idItem = item['id'] ?? '';
    final fullName = "${item['firstName'] ?? ''} ${item['lastName'] ?? ''}"
        .trim();
    final email = item['email'] ?? '';
    final phone = item['phone'] ?? '';
    final bool isDeleted = item['isDeleted'] ?? false;
    final bool isActive = !isDeleted;
    final linkedUser = item['linkedUser'];
    final List<dynamic> rolesSummary = item['rolesSummary'] ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDeleted ? colors.errorColor : colors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.iconBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.iconBorder),
                  ),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : "?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isActive ? colors.successColor : colors.errorColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          (isActive ? colors.successColor : colors.errorColor)
                              .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isActive ? "ACTIVO" : "INACT.",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isActive ? colors.successColor : colors.errorColor,
                    ),
                  ),
                ),
                if (linkedUser != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onUser,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.iconBackground,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.iconBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 10, color: colors.iconColor),
                          const SizedBox(width: 2),
                          Text(
                            "USER",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: colors.iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                "Id: $idItem - $fullName",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isActive
                                      ? colors.text
                                      : colors.text.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.copy,
                                  size: 13,
                                  color: colors.text.withValues(alpha: 0.4),
                                ),
                                onPressed: () => onCopy(fullName, "Nombre"),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: PopupMenuButton<String>(
                          color: colors.cardBackground,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: colors.text.withValues(alpha: 0.7),
                          ),
                          onSelected: (val) {
                            if (val == 'edit') onEdit();
                            if (val == 'toggle') onToggle();
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.iconBackground,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.iconBorder,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: colors.iconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Editar",
                                    style: TextStyle(color: colors.text),
                                  ),
                                ],
                              ),
                            ),
                            if (canManageStatus)
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: colors.iconBackground,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.iconBorder,
                                        ),
                                      ),
                                      child: Icon(
                                        isActive
                                            ? Icons.person_off
                                            : Icons.person_add,
                                        size: 14,
                                        color: colors.iconColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isActive ? "Dar de Baja" : "Activar",
                                      style: TextStyle(color: colors.text),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      InkWell(
                        onTap: onShowRoles,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.text.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_ind_outlined,
                                size: 12,
                                color: colors.text.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${rolesSummary.length} Cargo(s)",
                                style: TextStyle(
                                  color: colors.text.withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (phone.isNotEmpty && phone != 'Sin teléfono')
                        Expanded(
                          child: _CopyableRow(
                            icon: Icons.phone_outlined,
                            text: phone,
                            type: "Teléfono",
                            textColor: colors.text,
                            onCopy: onCopy,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (email.isNotEmpty && email != 'Sin email')
                    _CopyableRow(
                      icon: Icons.email_outlined,
                      text: email,
                      type: "Email",
                      textColor: colors.text,
                      onCopy: onCopy,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String type;
  final Color textColor;
  final Function(String, String) onCopy;

  const _CopyableRow({
    required this.icon,
    required this.text,
    required this.type,
    required this.textColor,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 20,
          height: 20,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.copy,
              size: 12,
              color: textColor.withValues(alpha: 0.3),
            ),
            onPressed: () => onCopy(text, type),
          ),
        ),
      ],
    );
  }
}
