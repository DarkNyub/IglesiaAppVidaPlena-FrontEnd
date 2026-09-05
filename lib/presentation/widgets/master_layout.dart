import 'package:flutter/material.dart';
import 'package:iglesia_app/presentation/pages/settings_page.dart';
import '../../core/user_session.dart';
import '../../core/system_role_manager.dart';
import '../../data/services/auth_service.dart';
import '../pages/login_page.dart';
import '../pages/RegistryEvents/registry_event_pending_list_page.dart';
import '../../core/app_theme_colors.dart';

// Imports de módulos
import '../pages/admin/ChurchFunctionRoles/church_role_list_page.dart';
import '../pages/admin/Events/event_list_page.dart';
import '../pages/admin/Members/member_list_page.dart';
import '../pages/admin/OrganizationStructures/organization_structure_list_page.dart';
import '../pages/admin/RecordTypes/record_type_list_page.dart';
import '../pages/admin/Reports/report_list_page.dart';
import '../pages/admin/simplesPages/simple_catalog_page.dart';
import '../pages/admin/Users/user_list_page.dart';
import '../pages/RegistryEvents/registry_event_list_page.dart';
import '../pages/admin/admin_dashboard_page.dart';

enum PageMode { list, form, view }

class SortOption {
  final String label;
  final String value;
  const SortOption(this.label, this.value);
}

class MasterLayout extends StatefulWidget {
  final String title;
  final Widget child;
  final PageMode mode;
  final bool enableSearch;
  final Function(String query)? onSearch;
  final bool enableSort;
  final List<SortOption>? sortOptions;
  final Function(String sortBy, bool ascending)? onSort;
  final VoidCallback? onAdd;
  final VoidCallback? onSave;
  final bool isSaving;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const MasterLayout({
    super.key,
    required this.title,
    required this.child,
    this.mode = PageMode.list,
    this.enableSearch = false,
    this.onSearch,
    this.enableSort = false,
    this.sortOptions,
    this.onSort,
    this.onAdd,
    this.onSave,
    this.isSaving = false,
    this.floatingActionButton,
    this.actions,
  });

  @override
  State<MasterLayout> createState() => _MasterLayoutState();
}

class _MasterLayoutState extends State<MasterLayout> {
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  String? _currentSortValue;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    if (widget.sortOptions != null && widget.sortOptions!.isNotEmpty) {
      _currentSortValue = widget.sortOptions!.first.value;
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchCtrl.clear();
        if (widget.onSearch != null) widget.onSearch!('');
      }
    });
  }

  void _showSortMenu() {
    if (widget.sortOptions == null) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  "Ordenar por",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.text,
                  ),
                ),
              ),
              ...widget.sortOptions!.map(
                (opt) => ListTile(
                  title: Text(opt.label, style: TextStyle(color: colors.text)),
                  leading: Radio<String>(
                    value: opt.value,
                    groupValue: _currentSortValue,
                    activeColor: colors.iconBackground,
                    onChanged: (val) =>
                        setModalState(() => _currentSortValue = val),
                  ),
                  onTap: () =>
                      setModalState(() => _currentSortValue = opt.value),
                ),
              ),
              Divider(color: colors.cardBorder),
              SwitchListTile(
                title: Text(
                  _isAscending ? "Ascendente" : "Descendente",
                  style: TextStyle(color: colors.text),
                ),
                value: _isAscending,
                activeThumbColor: colors.iconColor,
                activeTrackColor: colors.iconBackground,
                onChanged: (val) => setModalState(() => _isAscending = val),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _applySort(_currentSortValue!, _isAscending);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.buttonBackground,
                    ),
                    child: Text(
                      "Aplicar Orden",
                      style: TextStyle(
                        color: colors.buttonText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  void _applySort(String val, bool asc) {
    setState(() {
      _currentSortValue = val;
      _isAscending = asc;
    });
    if (widget.onSort != null) widget.onSort!(val, asc);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    List<Widget> appBarActions = [];

    if (widget.mode == PageMode.list) {
      if (widget.enableSearch) {
        appBarActions.add(
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: colors.text,
            ),
            tooltip: _isSearching ? "Cerrar" : "Buscar",
          ),
        );
      }
      if (!_isSearching && widget.enableSort) {
        appBarActions.add(
          IconButton(
            onPressed: _showSortMenu,
            icon: Icon(Icons.sort, color: colors.text),
            tooltip: "Ordenar",
          ),
        );
      }
      if (!_isSearching && widget.onAdd != null) {
        appBarActions.add(
          IconButton(
            onPressed: widget.onAdd,
            icon: Icon(Icons.add_circle_outline, size: 28, color: colors.text),
            tooltip: "Nuevo",
          ),
        );
      }
      if (!_isSearching && widget.actions != null) {
        appBarActions.addAll(widget.actions!);
      }
    } else if (widget.mode == PageMode.form) {
      if (widget.onSave != null) {
        appBarActions.add(
          IconButton(
            onPressed: widget.isSaving ? null : widget.onSave,
            icon: widget.isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: colors.text,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.save, color: colors.text),
            tooltip: "Guardar",
          ),
        );
      }
    }
    appBarActions.add(const SizedBox(width: 10));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.cardBackground,
        foregroundColor: colors.text,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.cardBorder),
        ),
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(color: colors.text),
                cursorColor: colors.iconBackground,
                decoration: InputDecoration(
                  hintText: "Escribe para filtrar...",
                  hintStyle: TextStyle(
                    color: colors.text.withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                ),
                onChanged: widget.onSearch,
              )
            : Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: colors.text,
                ),
              ),
        actions: appBarActions,
      ),
      drawer: widget.mode == PageMode.list
          ? _buildDrawer(context, colors)
          : null,
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildDrawer(BuildContext context, AppThemeColors colors) {
    final session = UserSession();
    final username = session.currentUser?.username ?? 'Usuario';
    final role = session.role ?? 'Invitado';
    final authService = AuthService();

    return Drawer(
      backgroundColor: colors.cardBackground,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              username,
              style: TextStyle(
                color: colors.iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: Text(
              "Rol: $role",
              style: TextStyle(color: colors.iconColor.withValues(alpha: 0.8)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colors.iconColor,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : "U",
                style: TextStyle(
                  fontSize: 24,
                  color: colors.iconBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            decoration: BoxDecoration(color: colors.iconBackground),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SystemRoleManager(
                  allowedRoles: const [SystemRoles.lider, SystemRoles.user],
                  child: _drawerItem(
                    context,
                    Icons.home,
                    "Inicio",
                    () => const RegistryEventPendingListPage(),
                    colors,
                  ),
                ),
                Divider(color: colors.cardBorder),
                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                    SystemRoles.lider,
                  ],
                  child: _drawerItem(
                    context,
                    Icons.people,
                    "Directorio Miembros",
                    () => const MemberListPage(),
                    colors,
                  ),
                ),
                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                  ],
                  child: _drawerItem(
                    context,
                    Icons.manage_accounts,
                    "Usuarios Sistema",
                    () => const UserListPage(),
                    colors,
                  ),
                ),
                Divider(color: colors.cardBorder),
                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                  ], // 🚫 LÍDER NO CREA EVENTOS
                  child: _drawerItem(
                    context,
                    Icons.event,
                    "Gestión Eventos",
                    () => const EventListPage(),
                    colors,
                  ),
                ),

                // 🔥 PERMISO ACTUALIZADO: AHORA EL LÍDER PUEDE VER LA BITÁCORA DE SU RED
                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                    SystemRoles.lider,
                    SystemRoles.report,
                  ],
                  child: _drawerItem(
                    context,
                    Icons.assignment_turned_in,
                    "Bitácora",
                    () => const RegistryEventListPage(),
                    colors,
                  ),
                ),

                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                    SystemRoles.report,
                  ],
                  child: _drawerItem(
                    context,
                    Icons.bar_chart,
                    "Reportes",
                    () => const ReportListPage(),
                    colors,
                  ),
                ),
                Divider(color: colors.cardBorder),
                SystemRoleManager(
                  allowedRoles: const [
                    SystemRoles.superAdmin,
                    SystemRoles.admin,
                  ],
                  child: _drawerItem(
                    context,
                    Icons.admin_panel_settings,
                    "Panel Admin",
                    () => const AdminDashboardPage(),
                    colors,
                  ),
                ),
                Divider(color: colors.cardBorder),
                ListTile(
                  leading: Icon(
                    Icons.settings,
                    color: colors.text.withValues(alpha: 0.6),
                  ),
                  title: Text(
                    "Configuración Visual",
                    style: TextStyle(color: colors.text),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(color: colors.cardBorder),
          ListTile(
            leading: Icon(Icons.logout, color: colors.errorColor),
            title: Text(
              "Cerrar Sesión",
              style: TextStyle(
                color: colors.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget Function() page,
    AppThemeColors colors,
  ) {
    return ListTile(
      leading: Icon(icon, color: colors.iconBackground),
      title: Text(
        title,
        style: TextStyle(color: colors.text, fontWeight: FontWeight.w500),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
      },
    );
  }
}
