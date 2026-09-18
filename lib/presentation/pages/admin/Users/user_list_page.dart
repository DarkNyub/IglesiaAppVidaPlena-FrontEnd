// ... [MANTÉN TUS IMPORTS Y LA CLASE STATEFUL WIDGET IGUAL] ...
import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/user_session.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../Members/member_form_page.dart';
import 'user_form_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.users);
  final _memberRepo = GenericRepository(endpoint: ApiConstants.members);
  final _session = UserSession();

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  String _currentQuery = '';
  String _sortBy = 'username';
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
        final username = (item['username'] ?? '').toString().toLowerCase();
        final memberName = (item['memberFullName'] ?? '')
            .toString()
            .toLowerCase();
        final roles =
            (item['systemRoles'] as List?)
                ?.map((r) => r['name'].toString().toLowerCase())
                .join(" ") ??
            "";

        return username.contains(lower) ||
            memberName.contains(lower) ||
            roles.contains(lower);
      }).toList();
    }

    temp.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'active':
          final actA = (a['isActive'] == true && a['isDeleted'] == false)
              ? 1
              : 0;
          final actB = (b['isActive'] == true && b['isDeleted'] == false)
              ? 1
              : 0;
          cmp = actA.compareTo(actB);
          break;
        case 'member':
          final mA = (a['memberFullName'] ?? "").toString();
          final mB = (b['memberFullName'] ?? "").toString();
          cmp = mA.compareTo(mB);
          break;
        case 'username':
        default:
          final uA = (a['username'] ?? "").toString().toLowerCase();
          final uB = (b['username'] ?? "").toString().toLowerCase();
          cmp = uA.compareTo(uB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() {
      _filteredItems = temp;
    });
  }

  Future<void> _navigateToForm([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserFormPage(existingUser: item)),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToMember(int memberId) async {
    setState(() => _isLoading = true);
    try {
      final memberData = await _memberRepo.getById(memberId);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberFormPage(existingMember: memberData),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar("Error cargando miembro: $e", isError: true);
      }
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

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    if (item['id'] == _session.currentUser?.id) {
      _showSnackbar("No puedes desactivar tu propio usuario.", isWarning: true);
      return;
    }

    // 🔥 MAGIA DE NORMALIZACIÓN APLICADA (Protección de SuperAdmin)
    final targetRoles = item['systemRoles'] as List<dynamic>? ?? [];
    final isTargetSuperAdmin = targetRoles.any(
      (r) => SystemRoles.normalize(r['name']) == SystemRoles.superAdmin,
    );
    final currentUserRole = SystemRoles.normalize(_session.role);

    if (isTargetSuperAdmin && currentUserRole != SystemRoles.superAdmin) {
      _showSnackbar(
        "Solo un SuperAdmin puede modificar a otro SuperAdmin.",
        isWarning: true,
      );
      return;
    }

    final bool isActive = item['isActive'] ?? true;
    setState(() => _isLoading = true);

    try {
      await _repo.customPost(item['id'], 'toggle-active');
      await _loadData();
      _showSnackbar(
        isActive ? "Usuario SUSPENDIDO" : "Usuario ACTIVADO",
        isWarning: isActive,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar("Error: $e", isError: true);
      }
    }
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // 🔥 MAGIA DE NORMALIZACIÓN APLICADA (Protección de SuperAdmin)
    final targetRoles = item['systemRoles'] as List<dynamic>? ?? [];
    final isTargetSuperAdmin = targetRoles.any(
      (r) => SystemRoles.normalize(r['name']) == SystemRoles.superAdmin,
    );
    final currentUserRole = SystemRoles.normalize(_session.role);

    if (isTargetSuperAdmin && currentUserRole != SystemRoles.superAdmin) {
      _showSnackbar(
        "Solo un SuperAdmin puede modificar a otro SuperAdmin.",
        isWarning: true,
      );
      return;
    }

    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final String title = isDeleted
        ? "¿Restaurar Usuario?"
        : "¿Eliminar Usuario?";
    final String content = isDeleted
        ? "El usuario volverá a estar ACTIVO y podrá acceder al sistema."
        : "El usuario pasará a la papelera (Soft Delete).";
    final String actionLabel = isDeleted ? "Restaurar" : "Eliminar";
    final Color actionColor = isDeleted
        ? colors.successColor
        : colors.errorColor;

    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: colors.cardBackground,
            title: Text(title, style: TextStyle(color: colors.text)),
            content: Text(
              content,
              style: TextStyle(color: colors.text.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text("Cancelar", style: TextStyle(color: colors.text)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(backgroundColor: actionColor),
                child: Text(
                  actionLabel,
                  style: TextStyle(color: colors.buttonText),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    setState(() => _isLoading = true);

    try {
      if (isDeleted) {
        await _repo.customPost(id, 'restore');
      } else {
        await _repo.delete(id);
      }
      await _loadData();
      _showSnackbar(isDeleted ? "Usuario restaurado" : "Usuario eliminado");
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackbar("Error: $e", isError: true);
      }
    }
  }

  // ... [COPIA AQUÍ EL RESTO DEL ARCHIVO user_list_page.dart DESDE @override Widget build(BuildContext context) HACIA ABAJO EXACTAMENTE COMO ESTÁ] ...
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Gestión de Usuarios",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Usuario", "username"),
        SortOption("Estado", "active"),
        SortOption("Miembro", "member"),
      ],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      onAdd: () => _navigateToForm(),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No se encontraron usuarios",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];

                final username = item['username'] ?? '---';
                final memberName = item['memberFullName'] ?? 'Desconocido';
                final int memberId = item['memberId'] ?? 0;

                final bool isDeleted = item['isDeleted'] ?? false;
                final bool isActive = item['isActive'] ?? true;
                final List<dynamic> roles = item['systemRoles'] ?? [];

                Color statusColor;
                String statusText;
                IconData statusIcon;

                if (isDeleted) {
                  statusColor = colors.errorColor;
                  statusText = "ELIMINADO";
                  statusIcon = Icons.delete_forever;
                } else if (!isActive) {
                  statusColor = colors.warningColor;
                  statusText = "SUSPENDIDO";
                  statusIcon = Icons.lock_clock;
                } else {
                  statusColor = colors.successColor;
                  statusText = "ACTIVO";
                  statusIcon = Icons.verified_user;
                }

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
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
                        // ==========================================
                        // COLUMNA IZQUIERDA: AVATAR + BADGE
                        // ==========================================
                        Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.iconBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.iconBorder,
                                  width: 1.5,
                                ),
                                image:
                                    (item['memberPhotoUrl'] != null &&
                                        item['memberPhotoUrl']
                                            .toString()
                                            .isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(
                                          item['memberPhotoUrl'],
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child:
                                  (item['memberPhotoUrl'] == null ||
                                      item['memberPhotoUrl'].toString().isEmpty)
                                  ? Icon(
                                      statusIcon,
                                      size: 20,
                                      color: colors.iconColor,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // ==========================================
                        // COLUMNA DERECHA: INFO Y CONTACTOS
                        // ==========================================
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FILA 1: NOMBRE Y MENÚ 3 PUNTOS
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDeleted
                                            ? colors.text.withValues(alpha: 0.5)
                                            : colors.text,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // MENÚ DE 3 PUNTOS (Unificado)
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PopupMenuButton<String>(
                                      color: colors.cardBackground,
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 20,
                                        color: colors.text.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _navigateToForm(item);
                                        }
                                        if (val == 'toggle_active') {
                                          _toggleActive(item);
                                        }
                                        if (val == 'toggle_delete') {
                                          _toggleDeleteStatus(item);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        if (!isDeleted)
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colors.iconBackground,
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
                                                  style: TextStyle(
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!isDeleted)
                                          PopupMenuItem(
                                            value: 'toggle_active',
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colors.iconBackground,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: colors.iconBorder,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    isActive
                                                        ? Icons.block
                                                        : Icons.check_circle,
                                                    size: 14,
                                                    color: colors.iconColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isActive
                                                      ? "Suspender"
                                                      : "Activar",
                                                  style: TextStyle(
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: 'toggle_delete',
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.iconBackground,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: colors.iconBorder,
                                                  ),
                                                ),
                                                child: Icon(
                                                  isDeleted
                                                      ? Icons.restore_from_trash
                                                      : Icons.delete_outline,
                                                  size: 14,
                                                  color: colors.iconColor,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isDeleted
                                                    ? "Restaurar"
                                                    : "Eliminar",
                                                style: TextStyle(
                                                  color: colors.text,
                                                ),
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

                              // FILA 2: ROLES (Chips parametrizados)
                              if (roles.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: roles
                                      .map(
                                        (r) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.text.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: colors.cardBorder,
                                            ),
                                          ),
                                          child: Text(
                                            "ROL: ${r['name'] ?? '?'}",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colors.text.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),

                              const SizedBox(height: 10),

                              // FILA 3: VÍNCULO AL MIEMBRO
                              InkWell(
                                onTap: () => _navigateToMember(memberId),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.iconBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colors.iconBorder,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_pin,
                                        size: 12,
                                        color: colors.iconColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          "MIEMBRO: $memberName",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.iconColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 10,
                                        color: colors.iconColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
