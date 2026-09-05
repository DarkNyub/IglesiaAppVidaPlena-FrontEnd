import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../../core/user_session.dart';
import 'church_role_form_page.dart';

class ChurchRoleListPage extends StatefulWidget {
  const ChurchRoleListPage({super.key});

  @override
  State<ChurchRoleListPage> createState() => _ChurchRoleListPageState();
}

class _ChurchRoleListPageState extends State<ChurchRoleListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.churchRoles);

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  String _currentQuery = '';
  String _sortBy = 'authority';
  bool _ascending = false;

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
        case 'name':
          cmp = (a['name'] ?? "").toString().compareTo(b['name'] ?? "");
          break;
        case 'authority':
        default:
          final authA = (a['authorityLevel'] as num?)?.toInt() ?? 0;
          final authB = (b['authorityLevel'] as num?)?.toInt() ?? 0;
          cmp = authA.compareTo(authB);
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
      MaterialPageRoute(builder: (_) => ChurchRoleFormPage(existingRole: item)),
    );
    if (result == true) _loadData();
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final String title = isDeleted ? "¿Restaurar Cargo?" : "¿Eliminar Cargo?";
    final String content = isDeleted
        ? "El cargo volverá a estar disponible para asignación."
        : "Se marcará como eliminado. Los miembros con este cargo lo mantendrán como histórico.";

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeleted ? "Cargo restaurado" : "Cargo eliminado",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.successColor,
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // 🔥 NORMALIZACIÓN (Ocultar botones si no es admin)
    final normalizedRole = SystemRoles.normalize(UserSession().role);
    final isAdmin =
        normalizedRole == SystemRoles.superAdmin ||
        normalizedRole == SystemRoles.admin;

    return MasterLayout(
      title: "Cargos Eclesiásticos",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Nivel de Autoridad", "authority"),
        SortOption("Nombre", "name"),
      ],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      onAdd: isAdmin ? () => _navigateToForm() : null, // Ocultar si no es admin

      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No hay cargos definidos",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final idItem = item['id'] ?? '';
                final name = item['name'] ?? 'Sin Nombre';
                final desc = item['description'] ?? '';
                final int authority =
                    (item['authorityLevel'] as num?)?.toInt() ?? 0;
                final bool isDeleted = item['isDeleted'] ?? false;

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
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                color: colors.iconBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.iconBorder),
                              ),
                              child: Center(
                                child: Text(
                                  "$authority",
                                  style: TextStyle(
                                    color: colors.iconColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Id: $idItem - $name",
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
                                  if (isAdmin) // Ocultar si no es admin
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
                                          if (val == 'toggle') {
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
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          colors.iconBackground,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            colors.iconBorder,
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
