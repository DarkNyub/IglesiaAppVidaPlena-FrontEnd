import 'package:flutter/material.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../../../core/constants/api_constants.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import 'registry_form_page.dart';

class RegistryEventPendingListPage extends StatefulWidget {
  const RegistryEventPendingListPage({super.key});

  @override
  State<RegistryEventPendingListPage> createState() =>
      _RegistryEventPendingListPageState();
}

class _RegistryEventPendingListPageState
    extends State<RegistryEventPendingListPage> {
  final _repository = GenericRepository(endpoint: ApiConstants.events);

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  String _currentQuery = '';
  String _sortBy = 'date';
  bool _ascending = true; // Cambiado a true para ver los más próximos primero

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

  // 🔥 MAGIA: Calcula la próxima fecha real basada en la recurrencia y el día de hoy
  DateTime _getNextOccurrenceDate(dynamic event) {
    final dateRaw = event['date'];
    if (dateRaw == null) return DateTime.now();

    final startDate = DateTime.tryParse(dateRaw) ?? DateTime.now();
    final type = event['recurrenceType'] ?? 'NONE';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);

    if (type == 'NONE') {
      return startDate; // Si no se repite, es su fecha única
    }

    // El cursor de búsqueda empieza hoy, a menos que el evento inicie en el futuro
    DateTime cursor = startDay.isAfter(today) ? startDay : today;

    if (type == 'DAILY') {
      return cursor;
    }

    if (type == 'WEEKLY') {
      final bitmask = event['recurringDays'] ?? 0;
      if (bitmask == 0) return cursor;

      // Buscamos en los próximos 7 días cuál coincide con los días marcados
      for (int i = 0; i < 7; i++) {
        final testDate = cursor.add(Duration(days: i));
        // Dart DateTime.weekday: 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab, 7=Dom
        // Tu Bitmask BD: 1=Lun, 2=Mar, 4=Mie, 8=Jue, 16=Vie, 32=Sab, 64=Dom
        int dayBit = 1 << (testDate.weekday - 1);

        if ((bitmask & dayBit) != 0) {
          return testDate; // Encontramos el próximo día válido (Ej: el próximo Jueves)
        }
      }
    }

    if (type == 'MONTHLY') {
      DateTime testMonth = DateTime(cursor.year, cursor.month, startDate.day);
      if (testMonth.isBefore(cursor)) {
        testMonth = DateTime(cursor.year, cursor.month + 1, startDate.day);
      }
      return testMonth;
    }

    if (type == 'ANNUALLY') {
      DateTime testYear = DateTime(cursor.year, startDate.month, startDate.day);
      if (testYear.isBefore(cursor)) {
        testYear = DateTime(cursor.year + 1, startDate.month, startDate.day);
      }
      return testYear;
    }

    return cursor;
  }

  void _applyFilters() {
    List<dynamic> temp = _allItems;
    if (_currentQuery.isNotEmpty) {
      final lower = _currentQuery.toLowerCase();
      temp = _allItems.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        final org = (item['organizationStructureName'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(lower) || org.contains(lower);
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
          // Ahora ordenamos basándonos en la PRÓXIMA fecha calculada, no en la de creación
          final dateA = _getNextOccurrenceDate(a);
          final dateB = _getNextOccurrenceDate(b);
          cmp = dateA.compareTo(dateB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() {
      _filteredItems = temp;
    });
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

    if (type == 'DAILY')
      return interval == 1 ? "Diario" : "Cada $interval días";
    if (type == 'WEEKLY') {
      String days = _decodeRecurringDays(item['recurringDays']);
      return interval == 1 ? "Semanal ($days)" : "Cada $interval sem ($days)";
    }
    if (type == 'MONTHLY')
      return interval == 1 ? "Mensual" : "Cada $interval meses";
    if (type == 'ANNUALLY')
      return interval == 1 ? "Anual" : "Cada $interval años";
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: 'Eventos para Reportar',
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      enableSort: true,
      sortOptions: const [
        SortOption("Fecha Más Próxima", "date"),
        SortOption("Nombre", "name"),
      ],
      onSort: (val, asc) {
        _sortBy = val;
        _ascending = asc;
        _applyFilters();
      },
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 80,
                    color: colors.text.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No tienes eventos pendientes por llenar.',
                    style: TextStyle(
                      fontSize: 16,
                      color: colors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                return _buildEventCard(context, _filteredItems[index], colors);
              },
            ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    dynamic event,
    AppThemeColors colors,
  ) {
    // Calculamos la fecha inteligente a mostrar
    final dateObj = _getNextOccurrenceDate(event);

    final dayStr = dateObj.day.toString();
    final monthStr = _getMonthName(dateObj.month);

    final orgName = event['organizationStructureName'] ?? "Evento Global";
    final bool isInPerson = event['isInPerson'] ?? true;
    final recurrenceText = _getRecurrenceText(event);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colors.iconBackground.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegistryFormPage(
                eventId: event['id'],
                eventName: event['name'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // FECHA VISUAL INTELIGENTE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.iconBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.iconBorder),
                  boxShadow: [
                    BoxShadow(
                      color: colors.iconBackground.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      dayStr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.iconColor,
                      ),
                    ),
                    Text(
                      monthStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.iconColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // DETALLES
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name'] ?? 'Evento',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),

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
                              color: colors.text.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          isInPerson ? "Presencial" : "Virtual",
                          isInPerson ? Icons.location_on : Icons.videocam,
                          colors,
                        ),
                        if (recurrenceText.isNotEmpty)
                          _buildBadge(recurrenceText, Icons.repeat, colors),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // INDICADOR DE ACCIÓN (OSCURO Y RESALTANTE)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.iconBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.iconBackground.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_document,
                  color: colors.iconColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon, AppThemeColors colors) {
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
