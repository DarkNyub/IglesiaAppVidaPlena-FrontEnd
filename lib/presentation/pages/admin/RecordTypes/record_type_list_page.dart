import 'package:flutter/material.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../../core/user_session.dart';
import 'record_type_form_page.dart';

class RecordTypeListPage extends StatefulWidget {
  const RecordTypeListPage({super.key});

  @override
  State<RecordTypeListPage> createState() => _RecordTypeListPageState();
}

class _RecordTypeListPageState extends State<RecordTypeListPage> {
  final _repository = GenericRepository(endpoint: 'record-types');
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
      final data = await _repository.getAll();
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
        case 'id':
          final idA = a['id'] as int;
          final idB = b['id'] as int;
          cmp = idA.compareTo(idB);
          break;
        case 'name':
        default:
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          cmp = nameA.compareTo(nameB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() => _filteredItems = temp);
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: colors.cardBackground,
            title: Text(
              isDeleted ? "¿Restaurar Formulario?" : "¿Eliminar Formulario?",
              style: TextStyle(color: colors.text),
            ),
            content: Text(
              isDeleted
                  ? "El formulario volverá a estar disponible."
                  : "Se marcará como inactivo.",
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
      if (isDeleted)
        await _repository.customPost(id, 'restore');
      else
        await _repository.delete(id);
      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToForm([Map<String, dynamic>? item]) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecordTypeFormPage(existingRecordType: item),
      ),
    );
    if (res == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // 🔥 NORMALIZACIÓN
    final normalizedRole = SystemRoles.normalize(UserSession().role);
    final isAdmin =
        normalizedRole == SystemRoles.superAdmin ||
        normalizedRole == SystemRoles.admin;

    return MasterLayout(
      title: "Tipos de Reporte",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [SortOption("Nombre", "name"), SortOption("ID", "id")],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      onAdd: isAdmin
          ? () => _navigateToForm()
          : null, // Ocultar agregar si no es admin

      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No hay formularios diseñados",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final bool isDeleted = item['isDeleted'] ?? false;
                final bool isActive = !isDeleted;
                final String? targetOrg = item['targetOrganizationTypeName'];
                final String? targetRole = item['targetFunctionRoleName'];

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
                                Icons.assignment_outlined,
                                color: colors.iconColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isActive
                                            ? colors.successColor
                                            : colors.errorColor)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      (isActive
                                              ? colors.successColor
                                              : colors.errorColor)
                                          .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isActive ? "ACTIVO" : "INACT.",
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? colors.successColor
                                      : colors.errorColor,
                                ),
                              ),
                            ),
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
                                      item['name'] ?? 'Sin Nombre',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isActive
                                            ? colors.text
                                            : colors.text.withValues(
                                                alpha: 0.5,
                                              ),
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (isAdmin) // Ocultar menú si no es admin
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
                                          if (val == 'edit')
                                            _navigateToForm(item);
                                          if (val == 'toggle')
                                            _toggleDeleteStatus(item);
                                        },
                                        itemBuilder: (ctx) => [
                                          if (isActive)
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
                                                      size: 12,
                                                      color: colors.iconColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    "Diseñar",
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
                                                        ? Icons.restore
                                                        : Icons.delete_outline,
                                                    size: 12,
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
                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 14,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Visible para: ${targetOrg ?? 'Global'}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.security,
                                    size: 14,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Llenado por: ${targetRole ?? 'Todos'}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (item['description'] != null &&
                                  item['description']
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  item['description'],
                                  style: TextStyle(
                                    color: colors.text.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
