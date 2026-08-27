import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/repositories/generic_repository.dart';
import '../../widgets/master_layout.dart';
import '../../../../core/app_theme_colors.dart'; // <--- LA MOCHILA
import 'registry_event_detail_page.dart';

class RegistryEventListPage extends StatefulWidget {
  const RegistryEventListPage({super.key});

  @override
  State<RegistryEventListPage> createState() => _RegistryEventListPageState();
}

class _RegistryEventListPageState extends State<RegistryEventListPage> {
  final _repo = GenericRepository(endpoint: ApiConstants.registryEvents);
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
        final eventName = (item['eventName'] ?? '').toString().toLowerCase();
        final leaderName = (item['leaderName'] ?? '').toString().toLowerCase();
        final recordTypeName = (item['recordTypeName'] ?? '')
            .toString()
            .toLowerCase();

        return eventName.contains(lower) ||
            leaderName.contains(lower) ||
            recordTypeName.contains(lower);
      }).toList();
    }
    setState(() => _filteredItems = temp);
  }

  Future<void> _navigateToDetail(Map<String, dynamic> item) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistryEventDetailPage(eventData: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return MasterLayout(
      title: "Bitácora de Eventos",
      mode: PageMode.list,
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: colors.iconBackground),
            )
          : _filteredItems.isEmpty
          ? Center(
              child: Text(
                "No hay reportes registrados",
                style: TextStyle(color: colors.text),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];

                final eventName = item['eventName'] ?? 'Evento sin nombre';
                final formName = item['recordTypeName'] ?? 'Formulario';
                final leader = item['leaderName'] ?? 'Sin líder';

                final dateStr = item['registryDate'];
                final date = dateStr != null
                    ? DateTime.tryParse(dateStr) ?? DateTime.now()
                    : DateTime.now();

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
                        // Ícono
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.iconBackground,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.iconBorder),
                          ),
                          child: Icon(
                            Icons.assignment_turned_in,
                            color: colors.iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Info Central
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      eventName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  // Menú Kebab Unificado
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
                                        if (val == 'view')
                                          _navigateToDetail(item);
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'view',
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.iconBackground,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: colors.iconBorder,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.visibility,
                                                  size: 14,
                                                  color: colors.iconColor,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Ver Detalles",
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
                                    Icons.description_outlined,
                                    size: 12,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      formName,
                                      style: TextStyle(
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 12,
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
                                    Icons.person_outline,
                                    size: 12,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Por: $leader",
                                      style: TextStyle(
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: colors.text.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'EEEE d, MMM yyyy - HH:mm',
                                        'es',
                                      ).format(date.toLocal()),
                                      style: TextStyle(
                                        color: colors.text.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
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
