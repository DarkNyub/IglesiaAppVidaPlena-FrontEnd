import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/system_role_manager.dart'; // <--- MOTOR DE NORMALIZACIÓN
import '../../../../core/user_session.dart';
import 'event_form_page.dart';

class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  final _repository = GenericRepository(endpoint: ApiConstants.events);

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  String _currentQuery = '';
  String _sortBy = 'date';
  bool _ascending = false;

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
        case 'name':
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          cmp = nameA.compareTo(nameB);
          break;
        case 'date':
        default:
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          cmp = dateA.compareTo(dateB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() => _filteredItems = temp);
  }

  Future<void> _navigateToForm([Map<String, dynamic>? item]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(event: item)),
    );
    if (result == true) _loadData();
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.cardBorder),
            ),
            title: Text(
              isDeleted ? "¿Restaurar Evento?" : "¿Cancelar Evento?",
              style: TextStyle(color: colors.text),
            ),
            content: Text(
              isDeleted
                  ? "El evento volverá a estar activo en la cartelera."
                  : "Se marcará como cancelado.",
              style: TextStyle(color: colors.text.withValues(alpha: 0.8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text("Volver", style: TextStyle(color: colors.text)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonBackground,
                ),
                child: Text(
                  isDeleted ? "Restaurar" : "Cancelar Evento",
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
        await _repository.customPost(id, 'restore');
      } else {
        await _repository.delete(id);
      }
      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _decodeRecurringDays(int? bitmask) {
    if (bitmask == null || bitmask == 0) return "";
    List<String> days = [];
    if ((bitmask & 1) != 0) days.add("L");
    if ((bitmask & 2) != 0) days.add("M");
    if ((bitmask & 4) != 0) days.add("X");
    if ((bitmask & 8) != 0) days.add("J");
    if ((bitmask & 16) != 0) days.add("V");
    if ((bitmask & 32) != 0) days.add("S");
    if ((bitmask & 64) != 0) days.add("D");
    return days.join(",");
  }

  String _getRecurrenceText(Map<String, dynamic> item) {
    final type = item['recurrenceType'] ?? 'NONE';
    if (type == 'NONE') return "";

    final interval = item['recurrenceInterval'] ?? 1;
    final endType = item['endType'] ?? 'NEVER';

    String baseStr = "";
    if (type == 'DAILY') {
      baseStr = interval == 1 ? "Diario" : "Cada $interval días";
    }
    if (type == 'WEEKLY') {
      String days = _decodeRecurringDays(item['recurringDays']);
      baseStr = interval == 1
          ? "Semanal ($days)"
          : "Cada $interval sem ($days)";
    }
    if (type == 'MONTHLY') {
      baseStr = interval == 1 ? "Mensual" : "Cada $interval meses";
    }
    if (type == 'ANNUALLY') {
      baseStr = interval == 1 ? "Anual" : "Cada $interval años";
    }

    if (endType == 'UNTIL_DATE' && item['endDate'] != null) {
      final dt = DateTime.tryParse(item['endDate']);
      if (dt != null) baseStr += " hasta ${DateFormat('MMM dd').format(dt)}";
    } else if (endType == 'AFTER_OCCURRENCES' &&
        item['maxOccurrences'] != null) {
      baseStr += " (${item['maxOccurrences']}x)";
    }

    return baseStr;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // 🔥 NORMALIZACIÓN (Oculta botones a usuarios que no son Admin)
    final normalizedRole = SystemRoles.normalize(UserSession().role);
    final isAdmin =
        normalizedRole == SystemRoles.superAdmin ||
        normalizedRole == SystemRoles.admin;

    return MasterLayout(
      title: "Gestión de Eventos",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Fecha del Evento", "date"),
        SortOption("Nombre", "name"),
      ],
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
                "No hay eventos registrados",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final dateRaw = item['date'];
                DateTime? dateObj;
                if (dateRaw != null) dateObj = DateTime.tryParse(dateRaw);

                final bool isDeleted = item['isDeleted'] ?? false;
                final bool isInPerson = item['isInPerson'] ?? false;
                final String recurrenceType = item['recurrenceType'] ?? 'NONE';
                final String orgName =
                    item['organizationStructure']?['name'] ?? "Evento Global";

                final bool isPastSingleEvent =
                    !isDeleted &&
                    recurrenceType == 'NONE' &&
                    dateObj != null &&
                    dateObj.isBefore(DateTime.now());

                String statusText;
                Color statusColor;

                if (isDeleted) {
                  statusText = "CANCELADO";
                  statusColor = colors.errorColor;
                } else if (isPastSingleEvent) {
                  statusText = "PASADO";
                  statusColor = colors.text.withValues(alpha: 0.5);
                } else {
                  statusText = "ACTIVO";
                  statusColor = colors.successColor;
                }

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
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: colors.iconBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.iconBorder),
                              ),
                              child: (recurrenceType != 'NONE')
                                  ? Icon(
                                      Icons.repeat,
                                      color: colors.iconColor,
                                      size: 24,
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          dateObj != null
                                              ? "${dateObj.day}"
                                              : "?",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: colors.iconColor,
                                          ),
                                        ),
                                        Text(
                                          dateObj != null
                                              ? _getMonthName(dateObj.month)
                                              : "-",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.iconColor,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                      item['name'] ?? 'Evento',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: isDeleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: (isDeleted || isPastSingleEvent)
                                            ? colors.text.withValues(alpha: 0.5)
                                            : colors.text,
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
                                                      size: 12,
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
                                                        ? Icons.restore
                                                        : Icons.cancel_outlined,
                                                    size: 12,
                                                    color: colors.iconColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isDeleted
                                                      ? "Restaurar"
                                                      : "Cancelar",
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

                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 12,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      orgName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // 🔥 CORRECCIÓN OVERFLOW: USO DE WRAP PARA LOS BADGES
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildUnifiedBadge(
                                    isInPerson ? "Presencial" : "Virtual",
                                    isInPerson
                                        ? Icons.location_on
                                        : Icons.videocam,
                                    colors,
                                  ),
                                  if (recurrenceType != 'NONE')
                                    _buildUnifiedBadge(
                                      _getRecurrenceText(item),
                                      Icons.repeat,
                                      colors,
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

  Widget _buildUnifiedBadge(String text, IconData icon, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.text.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: colors.text.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.text.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int m) {
    const months = [
      "ENE",
      "FEB",
      "MAR",
      "ABR",
      "MAY",
      "JUN",
      "JUL",
      "AGO",
      "SEP",
      "OCT",
      "NOV",
      "DIC",
    ];
    if (m < 1 || m > 12) return "";
    return months[m - 1];
  }
}
