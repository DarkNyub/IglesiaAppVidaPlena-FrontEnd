// ... [MANTÉN TUS IMPORTS Y LA CLASE STATEFUL WIDGET IGUAL] ...
import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../../core/user_session.dart'; // <--- SESIÓN
import 'report_designer_page.dart';
import 'report_export_page.dart';
import 'report_viewer_page.dart';

class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.reports);

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;
  String _currentQuery = '';

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
        final desc = (item['description'] ?? '').toString().toLowerCase();
        return name.contains(lower) || desc.contains(lower);
      }).toList();
    }
    setState(() => _filteredItems = temp);
  }

  Future<void> _navigateToDesigner([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDesignerPage(existingReport: item),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToExporter(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    if (isDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Restaure la plantilla para exportar.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportExportPage(reportData: item)),
    );
  }

  Future<void> _navigateToViewer(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    if (isDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Restaure la plantilla para visualizar.",
            style: TextStyle(color: colors.text),
          ),
          backgroundColor: colors.warningColor,
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportViewerPage(reportData: item)),
    );
  }

  Future<void> _toggleDeleteStatus(Map<String, dynamic> item) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final bool isDeleted = item['isDeleted'] ?? false;
    final int id = item['id'];

    final title = isDeleted ? "¿Restaurar Plantilla?" : "¿Eliminar Plantilla?";
    final msg = isDeleted
        ? "La plantilla volverá a estar disponible."
        : "Esta acción inhabilitará la plantilla, pero NO los datos almacenados.";

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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 MAGIA DE NORMALIZACIÓN APLICADA (Oculta botones de Diseño a usuarios "Report")
    final normalizedRole = SystemRoles.normalize(UserSession().role);
    final isAdmin =
        normalizedRole == SystemRoles.superAdmin ||
        normalizedRole == SystemRoles.admin;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Reportes Disponibles",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      // Solo Admin/SuperAdmin puede crear nuevos reportes
      onAdd: isAdmin ? () => _navigateToDesigner() : null,

      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No hay plantillas de reportes",
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
                        // ICONO Y ESTADO
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
                                Icons.table_chart,
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

                        // INFO Y KEBAB
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
                                  // MENU 3 PUNTOS
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
                                        if (val == 'export') {
                                          _navigateToExporter(item);
                                        }
                                        if (val == 'view') {
                                          _navigateToViewer(item);
                                        }
                                        if (val == 'edit') {
                                          _navigateToDesigner(item);
                                        }
                                        if (val == 'toggle') {
                                          _toggleDeleteStatus(item);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        if (isActive)
                                          PopupMenuItem(
                                            value: 'export',
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
                                                    Icons.download,
                                                    size: 12,
                                                    color: colors.iconColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Exportar CSV",
                                                  style: TextStyle(
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (isActive)
                                          PopupMenuItem(
                                            value: 'view',
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
                                                    Icons.bar_chart,
                                                    size: 12,
                                                    color: colors.iconColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Ver Gráficas",
                                                  style: TextStyle(
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (isActive &&
                                            isAdmin) // <--- OCULTO SI NO ES ADMIN
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
                                                    size: 12,
                                                    color: colors.iconColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Editar Diseño",
                                                  style: TextStyle(
                                                    color: colors.text,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (isAdmin) // <--- OCULTO SI NO ES ADMIN
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
                              const SizedBox(height: 6),
                              Text(
                                item['description'] != null &&
                                        item['description']
                                            .toString()
                                            .isNotEmpty
                                    ? item['description']
                                    : "Plantilla de Exportación",
                                style: TextStyle(
                                  color: colors.text.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
