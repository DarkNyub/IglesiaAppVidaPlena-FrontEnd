import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/app_theme_colors.dart'; // <--- IMPORTAMOS LA MOCHILA
import 'simplesPages/simple_catalog_page.dart';
import 'Events/event_list_page.dart';
import 'RecordTypes/record_type_list_page.dart';
import 'ChurchFunctionRoles/church_role_list_page.dart';
import 'OrganizationStructures/organization_structure_list_page.dart';
import 'Users/user_list_page.dart';
import 'simplesPages/system_role_list_page.dart';
import 'Members/member_list_page.dart';
import '../../widgets/master_layout.dart';
import 'Reports/report_list_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MasterLayout(
      title: 'Panel de Administración',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SECCIÓN 1: SEGURIDAD (Usuarios)
          const _SectionHeader(title: "Seguridad y Accesos"),

          _DashboardListTile(
            title: "Gestionar Usuarios",
            subtitle: "Altas, bajas y contraseñas",
            icon: Icons.manage_accounts_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserListPage()),
            ),
          ),

          const SizedBox(height: 15),

          // SECCIÓN 2: OPERACIONES
          const _SectionHeader(title: "Gestión Principal"),

          _DashboardListTile(
            title: "Directorio de Miembros",
            subtitle: "Base de datos de personas",
            icon: Icons.people_alt_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MemberListPage()),
            ),
          ),

          _DashboardListTile(
            title: "Gestionar Eventos",
            subtitle: "Calendario y actividades",
            icon: Icons.calendar_month_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EventListPage()),
            ),
          ),

          _DashboardListTile(
            title: "Diseñador de Formularios",
            subtitle: "Estructura de reportes",
            icon: Icons.assignment_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordTypeListPage()),
            ),
          ),

          const SizedBox(height: 15),

          // SECCIÓN 3: ESTRUCTURA Y JERARQUÍA
          const _SectionHeader(title: "Estructura Organizacional"),

          _DashboardListTile(
            title: "Estructuras (Redes/Ministerios)",
            subtitle: "Árbol jerárquico de la iglesia",
            icon: Icons.account_tree_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OrganizationStructureListPage(),
              ),
            ),
          ),

          _DashboardListTile(
            title: "Cargos Eclesiásticos",
            subtitle: "Roles y niveles de autoridad",
            icon: Icons.workspace_premium_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChurchRoleListPage()),
            ),
          ),

          const SizedBox(height: 15),

          // SECCIÓN 4: CATÁLOGOS DE SISTEMA
          const _SectionHeader(title: "Catálogos de Sistema"),

          _DashboardListTile(
            title: "Tipos de Organización",
            subtitle: "Definición (Red, Grupo, Dpto...)",
            icon: Icons.category_outlined,
            onTap: () => _navToCatalog(
              context,
              "Tipos de Org.",
              ApiConstants.organizationTypes,
              "Tipo",
            ),
          ),

          _DashboardListTile(
            title: "Roles de Sistema",
            subtitle: "Permisos técnicos (SuperAdmin, Lider...)",
            icon: Icons.admin_panel_settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SystemRoleListPage()),
            ),
          ),

          const SizedBox(height: 15),

          // SECCIÓN 5: INTELIGENCIA Y REPORTES
          const _SectionHeader(title: "Inteligencia y Reportes"),

          _DashboardListTile(
            title: "Constructor de Reportes",
            subtitle: "Define gráficas y estadísticas",
            icon: Icons.bar_chart,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportListPage()),
            ),
          ),
        ],
      ),
    );
  }

  void _navToCatalog(
    BuildContext context,
    String title,
    String endpoint,
    String label,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleCatalogPage(
          title: title,
          apiEndpoint: endpoint,
          itemLabel: label,
        ),
      ),
    );
  }
}

// --- WIDGETS PRIVADOS 100% LIMPIOS ---

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // 1. Tomamos los colores directamente de la mochila
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5, top: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.text.withValues(alpha: 0.6), // Asignación directa
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DashboardListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Tomamos los colores directamente de la mochila
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: colors.cardBackground, // Asignación directa
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.cardBorder, // Asignación directa
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Contenedor del Ícono
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.iconBackground, // Asignación directa
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.iconBorder, // Asignación directa
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors.iconColor,
                  size: 24,
                ), // Asignación directa
              ),
              const SizedBox(width: 16),

              // Textos usando Expanded para evitar el Overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.text, // Asignación directa
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.text.withValues(
                          alpha: 0.7,
                        ), // Asignación directa
                      ),
                    ),
                  ],
                ),
              ),

              // Flecha derecha
              Icon(
                Icons.chevron_right,
                color: colors.text.withValues(alpha: 0.5), // Asignación directa
              ),
            ],
          ),
        ),
      ),
    );
  }
}
