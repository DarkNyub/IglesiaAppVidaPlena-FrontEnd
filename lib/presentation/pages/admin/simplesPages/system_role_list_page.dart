import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../widgets/ui_components/app_inputs.dart';

class SystemRoleListPage extends StatefulWidget {
  const SystemRoleListPage({super.key});

  @override
  State<SystemRoleListPage> createState() => _SystemRoleListPageState();
}

class _SystemRoleListPageState extends State<SystemRoleListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.systemRoles);

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
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(lower);
      }).toList();
    }

    temp.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'status':
          final delA = (a['isDeleted'] == true) ? 1 : 0;
          final delB = (b['isDeleted'] == true) ? 1 : 0;
          cmp = delA.compareTo(delB);
          break;
        case 'name':
        default:
          cmp = (a['name'] ?? '').toString().compareTo(b['name'] ?? '');
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() => _filteredItems = temp);
  }

  void _showForm([Map<String, dynamic>? item]) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final descCtrl = TextEditingController(text: item?['description'] ?? '');
    final isEditing = item != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.cardBorder),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.iconBackground,
                shape: BoxShape.circle,
                border: Border.all(color: colors.iconBorder),
              ),
              child: Icon(
                isEditing ? Icons.edit_note : Icons.add_moderator,
                color: colors.iconColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isEditing ? "Editar Rol" : "Nuevo Rol",
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              AppTextField(
                controller: nameCtrl,
                label: "Nombre del Rol",
                prefixIcon: Icons.security,
              ),
              AppTextField(
                controller: descCtrl,
                label: "Descripción (Opcional)",
                prefixIcon: Icons.description,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: colors.text)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _save(nameCtrl.text.trim(), descCtrl.text.trim(), item?['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.buttonBackground,
            ),
            child: Text("Guardar", style: TextStyle(color: colors.buttonText)),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String name, String desc, int? id) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    setState(() => _isLoading = true);
    try {
      final payload = {"id": id, "name": name, "description": desc};
      await _repo.save(payload);
      _loadData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Rol guardado", style: TextStyle(color: colors.text)),
            backgroundColor: colors.successColor,
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e", style: TextStyle(color: colors.text)),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // 🔥 MAGIA DE NORMALIZACIÓN APLICADA AQUÍ
    final normalizedName = SystemRoles.normalize(item['name']);

    if (normalizedName == SystemRoles.superAdmin ||
        normalizedName == SystemRoles.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Seguridad: No puedes modificar ni eliminar roles críticos del sistema.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }

    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final String title = isDeleted ? "¿Restaurar Rol?" : "¿Eliminar Rol?";
    final String content = isDeleted
        ? "El rol volverá a estar activo."
        : "Usuarios con este rol podrían perder acceso.";

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
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonBackground,
                ),
                child: Text(
                  isDeleted ? "Restaurar" : "Eliminar",
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeleted ? "Rol restaurado" : "Rol eliminado",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.successColor,
          ),
        );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Roles del Sistema",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Nombre", "name"),
        SortOption("Estado", "status"),
      ],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      onAdd: () => _showForm(),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No hay roles registrados",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final name = item['name'] ?? '---';
                final desc = item['description'] ?? '';
                final bool isDeleted = item['isDeleted'] ?? false;

                // 🔥 MAGIA DE NORMALIZACIÓN APLICADA AQUÍ
                final normalizedName = SystemRoles.normalize(name);
                final isCriticalRole =
                    normalizedName == SystemRoles.superAdmin ||
                    normalizedName == SystemRoles.admin;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: colors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.cardBorder, width: 1.5),
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
                              child: Icon(
                                Icons.security,
                                color: colors.iconColor,
                                size: 20,
                              ),
                            ),
                            if (isDeleted) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.text.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colors.text.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  "ELIMINADO",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: colors.text.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
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
                                        color: colors.text.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      onSelected: (val) {
                                        if (val == 'edit') _showForm(item);
                                        if (val == 'toggle')
                                          _toggleDeleteStatus(item);
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
                                        if (!isCriticalRole) // <--- OCULTAR BOTÓN PELIGROSO
                                          PopupMenuItem(
                                            value: 'toggle',
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
                                                    isDeleted
                                                        ? Icons
                                                              .restore_from_trash
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

                              if (desc.isNotEmpty)
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.text.withValues(alpha: 0.7),
                                  ),
                                )
                              else
                                Text(
                                  "Sin descripción",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: colors.text.withValues(alpha: 0.5),
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
