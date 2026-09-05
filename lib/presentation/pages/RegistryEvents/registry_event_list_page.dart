import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart';
import '../../../../core/ui_provider.dart';
import '../../../../core/user_session.dart';
import '../../../../core/system_role_manager.dart';
import 'registry_event_detail_page.dart';

class RegistryEventListPage extends StatefulWidget {
  const RegistryEventListPage({super.key});

  @override
  State<RegistryEventListPage> createState() => _RegistryEventListPageState();
}

class _RegistryEventListPageState extends State<RegistryEventListPage> {
  final _registryRepo = GenericRepository(
    endpoint: ApiConstants.registryEvents,
  );
  final _eventRepo = GenericRepository(endpoint: ApiConstants.events);

  List<dynamic> _allReports = [];
  List<dynamic> _allEvents = [];
  Map<String, Map<String, List<dynamic>>> _groupedByWeekAndEvent = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final responses = await Future.wait([
        _registryRepo.getAll(),
        _eventRepo.getAll(),
      ]);

      if (mounted) {
        setState(() {
          _allReports = (responses[0] is List) ? responses[0] : [];
          _allEvents = (responses[1] is List) ? responses[1] : [];
          _processAndGroupData();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processAndGroupData() {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final customColors = uiProvider.customColors;
    final int startDay = customColors?['firstDayOfWeek'] ?? 1;

    // Estructura: Map<Semana, Map<NombreEvento, List<Reportes>>>
    Map<String, Map<String, List<dynamic>>> groups = {};

    // 1. Garantizamos la semana actual
    final now = DateTime.now();
    final currentWeekKey = _getWeekRangeText(now, startDay);
    groups[currentWeekKey] = {};

    // 2. Agrupamos por Semana -> Evento
    for (var report in _allReports) {
      final dateStr = report['registryDate'];
      final DateTime date = dateStr != null
          ? (DateTime.tryParse(dateStr) ?? DateTime.now()).toLocal()
          : DateTime.now();

      final weekRange = _getWeekRangeText(date, startDay);
      final eventName = report['eventName'] ?? 'Evento sin Nombre';

      if (!groups.containsKey(weekRange)) {
        groups[weekRange] = {};
      }
      if (!groups[weekRange]!.containsKey(eventName)) {
        groups[weekRange]![eventName] = [];
      }
      groups[weekRange]![eventName]!.add(report);
    }

    setState(() {
      _groupedByWeekAndEvent = groups;
    });
  }

  String _getWeekRangeText(DateTime date, int startDay) {
    int daysToSubtract;
    if (startDay == 1) {
      daysToSubtract = date.weekday - 1;
    } else {
      daysToSubtract = date.weekday == 7 ? 0 : date.weekday;
    }

    final startDate = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysToSubtract));
    final endDate = startDate.add(const Duration(days: 6));

    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    return "Semana del ${formatter.format(startDate)} al ${formatter.format(endDate)}";
  }

  void _navigateToEventDetail(
    String weekTitle,
    String eventName,
    List<dynamic> eventReports,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistryEventDetailPage(
          weekTitle: weekTitle,
          eventName: eventName,
          reportsList: eventReports,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final session = UserSession();
    final normalizedRole = SystemRoles.normalize(session.role);
    final isSuperAdmin = normalizedRole == SystemRoles.superAdmin;

    final weekKeys = _groupedByWeekAndEvent.keys.toList();

    return MasterLayout(
      title: isSuperAdmin
          ? "Bitácora Global (SuperAdmin)"
          : "Historial de Reportes",
      mode: PageMode.list,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: weekKeys.length,
              itemBuilder: (context, index) {
                final weekTitle = weekKeys[index];
                final eventsMap = _groupedByWeekAndEvent[weekTitle]!;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  color: colors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.cardBorder, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CABECERA DE LA SEMANA
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              color: colors.iconBackground,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              weekTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: colors.cardBorder, height: 20),

                        // SI NO HAY REPORTES EN LA SEMANA
                        if (eventsMap.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pending_actions,
                                  size: 14,
                                  color: colors.text.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Sin reportes enviados en esta semana aún.",
                                  style: TextStyle(
                                    color: colors.text.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // FILAS INDIVIDUALES POR EVENTO (DISCRIMINADAS Y CLICKEABLES)
                          Column(
                            children: eventsMap.entries.map((entry) {
                              final eventName = entry.key;
                              final reports = entry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _navigateToEventDetail(
                                    weekTitle,
                                    eventName,
                                    reports,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.inputBackground.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.cardBorder.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.assignment_turned_in,
                                          size: 16,
                                          color: colors.iconBackground,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            eventName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: colors.text,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.iconBackground
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            "${reports.length} cargado(s)",
                                            style: TextStyle(
                                              color: colors.iconBackground,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: colors.text.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
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
