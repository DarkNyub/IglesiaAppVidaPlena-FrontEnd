import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../../core/user_session.dart';
import 'organization_structure_form_page.dart';

class OrganizationStructureListPage extends StatefulWidget {
  const OrganizationStructureListPage({super.key});

  @override
  State<OrganizationStructureListPage> createState() =>
      _OrganizationStructureListPageState();
}

class _OrganizationStructureListPageState
    extends State<OrganizationStructureListPage> {
  final _repo = GenericRepository(
    endpoint: ApiConstants.organizationStructures,
  );

  List<dynamic> _allItems = [];
  String _currentQuery = '';
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToForm([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationStructureFormPage(existingStructure: item),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final String title = isDeleted
        ? "¿Restaurar Estructura?"
        : "¿Eliminar Estructura?";
    final String msg = isDeleted
        ? "La estructura volverá a estar disponible."
        : "Se marcará como eliminada. Solo es posible si no tiene sub-estructuras ni miembros activos.";

    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: colors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.cardBorder),
            ),
            title: Text(title, style: TextStyle(color: colors.text)),
            content: Text(
              msg,
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
              isDeleted ? "Estructura restaurada" : "Estructura eliminada",
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

  Future<void> _showCloneDialog(Map<String, dynamic> originalNode) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final nameCtrl = TextEditingController(
      text: "${originalNode['name']} (Copia)",
    );
    final descCtrl = TextEditingController(
      text: originalNode['description'] ?? '',
    );

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.cardBorder),
        ),
        title: Text("Clonar Estructura", style: TextStyle(color: colors.text)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Se duplicará esta estructura y todos los grupos/ministerios que dependan de ella.",
                style: TextStyle(
                  fontSize: 12,
                  color: colors.text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Nuevo Nombre",
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: "Nueva Descripción",
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: TextStyle(color: colors.text)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.buttonBackground,
            ),
            child: Text(
              "Clonar Todo",
              style: TextStyle(color: colors.buttonText),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (nameCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _repo.customPost(originalNode['id'], 'clone', {
        "newName": nameCtrl.text.trim(),
        "newDescription": descCtrl.text.trim(),
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Estructura clonada con éxito",
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
            content: Text(
              "Error al clonar: $e",
              style: TextStyle(color: colors.text),
            ),
            backgroundColor: colors.errorColor,
          ),
        );
      }
    }
  }

  // --- RECURSIÓN PARA EL ÁRBOL ---
  List<Widget> _buildTreeNodes(
    int? parentId,
    AppThemeColors colors,
    bool isAdmin,
  ) {
    var children = _allItems
        .where((node) => node['parentId'] == parentId)
        .toList();

    if (children.isEmpty) return [];

    return children.map<Widget>((node) {
      final bool isDeleted = node['isDeleted'] ?? false;
      final hasGrandChildren = _allItems.any(
        (n) => n['parentId'] == node['id'],
      );

      final titleRow = Row(
        children: [
          Expanded(
            child: Text(
              "Id: ${node['id']} - ${node['name']}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDeleted
                    ? colors.text.withValues(alpha: 0.5)
                    : colors.text,
                decoration: isDeleted ? TextDecoration.lineThrough : null,
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
                  color: colors.text.withValues(alpha: 0.7),
                ),
                onSelected: (val) {
                  if (val == 'edit') _navigateToForm(node);
                  if (val == 'toggle') _toggleDeleteStatus(node);
                  if (val == 'clone') _showCloneDialog(node);
                },
                itemBuilder: (ctx) => [
                  // AGREGAR DEBAJO DE LA OPCIÓN "Editar"
                  if (!isDeleted)
                    PopupMenuItem(
                      value: 'clone',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: colors.iconColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Clonar (con hijos)",
                            style: TextStyle(color: colors.text),
                          ),
                        ],
                      ),
                    ),
                  if (!isDeleted)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colors.iconBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.iconBorder),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 14,
                              color: colors.iconColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("Editar", style: TextStyle(color: colors.text)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.iconBackground,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.iconBorder),
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
                          isDeleted ? "Restaurar" : "Eliminar",
                          style: TextStyle(color: colors.text),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

      final subtitleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDeleted)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: colors.text.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.text.withValues(alpha: 0.3)),
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
          if (node['description'] != null &&
              node['description'].toString().isNotEmpty)
            Text(
              node['description'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
        ],
      );

      if (hasGrandChildren) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.cardBorder),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              iconColor: colors.text,
              collapsedIconColor: colors.text.withValues(alpha: 0.5),
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.iconBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.iconBorder),
                ),
                child: Icon(
                  Icons.folder_open,
                  size: 16,
                  color: colors.iconColor,
                ),
              ),
              title: titleRow,
              subtitle: subtitleWidget,
              childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
              children: _buildTreeNodes(node['id'], colors, isAdmin),
            ),
          ),
        );
      } else {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.cardBorder),
          ),
          child: ListTile(
            leading: Icon(
              Icons.subdirectory_arrow_right,
              size: 20,
              color: colors.text.withValues(alpha: 0.3),
            ),
            title: titleRow,
            subtitle: subtitleWidget,
          ),
        );
      }
    }).toList();
  }

  // --- RESULTADOS DE BÚSQUEDA ---
  List<Widget> _buildSearchResults(AppThemeColors colors, bool isAdmin) {
    final lower = _currentQuery.toLowerCase();
    final results = _allItems.where((node) {
      final name = (node['name'] ?? '').toString().toLowerCase();
      return name.contains(lower);
    }).toList();

    if (results.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "No se encontraron resultados",
              style: TextStyle(color: colors.text),
            ),
          ),
        ),
      ];
    }

    return results.map((node) {
      final bool isDeleted = node['isDeleted'] ?? false;
      return Card(
        color: colors.cardBackground,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.iconBackground,
              shape: BoxShape.circle,
              border: Border.all(color: colors.iconBorder),
            ),
            child: Icon(Icons.search, size: 16, color: colors.iconColor),
          ),
          title: Text(
            node['name'],
            style: TextStyle(
              color: isDeleted
                  ? colors.text.withValues(alpha: 0.5)
                  : colors.text,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            "Padre ID: ${node['parentId'] ?? 'Raíz'}",
            style: TextStyle(
              color: colors.text.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          trailing: isAdmin
              ? SizedBox(
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
                      if (val == 'edit') _navigateToForm(node);
                      if (val == 'toggle') _toggleDeleteStatus(node);
                    },
                    itemBuilder: (ctx) => [
                      if (!isDeleted)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: colors.iconBackground,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Editar",
                                style: TextStyle(color: colors.text),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              isDeleted
                                  ? Icons.restore_from_trash
                                  : Icons.delete_outline,
                              size: 14,
                              color: colors.iconBackground,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDeleted ? "Restaurar" : "Eliminar",
                              style: TextStyle(color: colors.text),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : null,
        ),
      );
    }).toList();
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
      title: "Jerarquía Organizacional",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) => setState(() => _currentQuery = q),
      enableSort: false,
      onAdd: isAdmin ? () => _navigateToForm() : null, // Ocultar si no es admin
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: _currentQuery.isEmpty
                    ? _buildTreeNodes(null, colors, isAdmin)
                    : _buildSearchResults(colors, isAdmin),
              ),
            ),
    );
  }
}
