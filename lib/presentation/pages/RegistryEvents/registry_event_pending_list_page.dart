import 'package:flutter/material.dart';
import 'package:iglesia_app/data/repositories/generic_repository.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/generic_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../../widgets/master_layout.dart'; // <--- EL NUEVO STANDARD
import 'registry_form_page.dart';

class RegistryEventPendingListPage extends StatefulWidget {
  const RegistryEventPendingListPage({super.key});

  @override
  State<RegistryEventPendingListPage> createState() =>
      _RegistryEventPendingListPageState();
}

class _RegistryEventPendingListPageState
    extends State<RegistryEventPendingListPage> {
  // Usamos el repositorio para consistencia
  final _repository = GenericRepository(endpoint: ApiConstants.events);

  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;

  // Filtros internos
  String _currentQuery = '';
  String _sortBy = 'date'; // Por defecto: Fecha
  bool _ascending = false; // Por defecto: Más recientes primero (Descendente)

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
    // 1. Filtrar
    List<dynamic> temp = _allItems;
    if (_currentQuery.isNotEmpty) {
      final lower = _currentQuery.toLowerCase();
      temp = _allItems.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(lower);
      }).toList();
    }

    // 2. Ordenar
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
          // Ordenar por fecha es lo más crítico en el Home
          final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1900);
          final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1900);
          cmp = dateA.compareTo(dateB);
          break;
      }
      return _ascending ? cmp : -cmp;
    });

    setState(() {
      _filteredItems = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MasterLayout(
      title: 'Eventos Disponibles',
      mode: PageMode.list, // Activa Drawer, Buscador y Ordenar
      // BUSCADOR
      enableSearch: true,
      onSearch: (q) {
        _currentQuery = q;
        _applyFilters();
      },

      // ORDENAMIENTO
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

      // NOTA: No ponemos onAdd porque esto es para consumo general,
      // la creación de eventos se hace desde el menú Admin -> Eventos.
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    'No hay eventos programados.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final event = _filteredItems[index];
                return _buildEventCard(context, event);
              },
            ),
    );
  }

  Widget _buildEventCard(BuildContext context, dynamic event) {
    final dateRaw = event['date'];
    DateTime? dateObj;
    if (dateRaw != null) dateObj = DateTime.tryParse(dateRaw);

    // Formato de fecha amigable (Ej: Sáb, 12 Oct)
    final dayStr = dateObj != null ? dateObj.day.toString() : "?";
    final monthStr = dateObj != null ? _getMonthName(dateObj.month) : "";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Acción principal: IR A LLENAR EL FORMULARIO
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
              // FECHA VISUAL (Cajita estilo calendario)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    Text(
                      dayStr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      monthStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event['description'] ?? 'Toca para registrar asistencia',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    // Etiqueta de tipo (Presencial/Virtual) si existe
                    if (event['isInPerson'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event['isInPerson'] == true
                              ? "Presencial"
                              : "Virtual",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),

              // FLECHA DE ACCIÓN
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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
