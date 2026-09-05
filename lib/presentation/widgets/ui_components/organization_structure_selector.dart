import 'package:flutter/material.dart';
import '../../../../core/app_theme_colors.dart';
import 'app_inputs.dart';

class OrganizationStructureSelector extends StatefulWidget {
  final int? value;
  final List<dynamic> structures;
  final String label;
  final ValueChanged<int?> onChanged;
  final bool allowNull;
  final String nullLabel;

  const OrganizationStructureSelector({
    super.key,
    required this.value,
    required this.structures,
    required this.label,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel = "(Ninguno)",
  });

  @override
  State<OrganizationStructureSelector> createState() =>
      _OrganizationStructureSelectorState();
}

class _OrganizationStructureSelectorState
    extends State<OrganizationStructureSelector> {
  String _searchQuery = "";

  // 🪄 1. MOTOR RECURSIVO: Arma la ruta de texto (Ej: Sede > Red > Grupo)
  String _getFullPath(int? id) {
    if (id == null) return widget.nullLabel;

    var current = widget.structures.firstWhere(
      (s) => s['id'] == id,
      orElse: () => null,
    );
    if (current == null) return "Desconocido";

    List<String> path = [current['name']];
    int? parentId = current['parentId'] ?? current['parent_id'];

    int safeCounter = 0;
    while (parentId != null && safeCounter < 20) {
      var parent = widget.structures.firstWhere(
        (s) => s['id'] == parentId,
        orElse: () => null,
      );
      if (parent != null) {
        path.insert(0, parent['name']);
        parentId = parent['parentId'] ?? parent['parent_id'];
      } else {
        break;
      }
      safeCounter++;
    }
    return path.join("  >  ");
  }

  // 🪄 2. CALCULAR PROFUNDIDAD: Para empujar visualmente a los hijos a la derecha
  int _getDepth(int? id) {
    if (id == null) return 0;
    var current = widget.structures.firstWhere(
      (s) => s['id'] == id,
      orElse: () => null,
    );
    if (current == null) return 0;

    int depth = 0;
    int? parentId = current['parentId'] ?? current['parent_id'];
    int safeCounter = 0;

    while (parentId != null && safeCounter < 20) {
      var parent = widget.structures.firstWhere(
        (s) => s['id'] == parentId,
        orElse: () => null,
      );
      if (parent != null) {
        depth++;
        parentId = parent['parentId'] ?? parent['parent_id'];
      } else {
        break;
      }
      safeCounter++;
    }
    return depth;
  }

  // 🪄 3. ORDENAR COMO ÁRBOL (Top-Down): Aplana la lista respetando la jerarquía
  List<dynamic> get _hierarchicalStructures {
    final Map<int?, List<dynamic>> childrenMap = {};

    // Agrupar todos por su respectivo padre
    for (var item in widget.structures) {
      final parentId = item['parentId'] ?? item['parent_id'];
      childrenMap.putIfAbsent(parentId, () => []).add(item);
    }

    // Ordenar alfabéticamente en cada nivel de hermanos
    childrenMap.forEach((key, list) {
      list.sort(
        (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
          (b['name'] ?? '').toString().toLowerCase(),
        ),
      );
    });

    final List<dynamic> sorted = [];

    // Función recursiva que toma un padre y encola a todos sus descendientes
    void traverse(int? parentId) {
      final children = childrenMap[parentId] ?? [];
      for (var child in children) {
        sorted.add(child);
        traverse(child['id']); // Buscar los hijos de este hijo
      }
    }

    // Empezar por las raíces (padre == null)
    traverse(null);

    // Control de daños: Agregar huérfanos si la BD tuviera datos corruptos
    final addedIds = sorted.map((e) => e['id']).toSet();
    final orphans = widget.structures
        .where((e) => !addedIds.contains(e['id']))
        .toList();
    sorted.addAll(orphans);

    return sorted;
  }

  void _showSearchDialog(AppThemeColors colors) {
    setState(() => _searchQuery = "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Pasamos la lista plana por el motor de ordenamiento de árbol
            final allSorted = _hierarchicalStructures;

            // Filtramos la búsqueda sobre la lista ya ordenada
            final filteredList = allSorted.where((p) {
              final fullPath = _getFullPath(p['id']).toLowerCase();
              return fullPath.contains(_searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AppTextField(
                      controller: TextEditingController(text: _searchQuery)
                        ..selection = TextSelection.collapsed(
                          offset: _searchQuery.length,
                        ),
                      label: "Buscar Estructura...",
                      prefixIcon: Icons.search,
                      onChanged: (val) =>
                          setModalState(() => _searchQuery = val),
                    ),
                  ),
                  if (widget.allowNull && _searchQuery.isEmpty) ...[
                    ListTile(
                      leading: Icon(
                        Icons.star_border,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                      title: Text(
                        widget.nullLabel,
                        style: TextStyle(
                          color: colors.text.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onTap: () {
                        widget.onChanged(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(),
                  ],
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        final fullPath = _getFullPath(item['id']);
                        final isSelected = item['id'] == widget.value;

                        // Si buscamos algo, quitamos la sangría visual para que no se vea raro.
                        // Si la barra está vacía, mostramos el árbol con sus ramas visuales identadas.
                        final depth = _searchQuery.isEmpty
                            ? _getDepth(item['id'])
                            : 0;
                        final leftPadding = depth * 24.0;

                        return Padding(
                          padding: EdgeInsets.only(left: leftPadding),
                          child: ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : (depth == 0
                                        ? Icons.domain
                                        : Icons.subdirectory_arrow_right),
                              color: isSelected
                                  ? colors.successColor
                                  : colors.iconBackground.withValues(
                                      alpha: depth == 0 ? 1.0 : 0.4,
                                    ),
                              size: depth == 0 ? 24 : 18,
                            ),
                            title: Text(
                              item['name'],
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: isSelected || depth == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              fullPath,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.text.withValues(alpha: 0.5),
                              ),
                            ),
                            onTap: () {
                              widget.onChanged(item['id']);
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final currentPath = _getFullPath(widget.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: colors.text.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSearchDialog(colors),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.inputBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: colors.text.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentPath,
                    style: TextStyle(
                      color: widget.value == null
                          ? colors.text.withValues(alpha: 0.5)
                          : colors.text,
                      fontStyle: widget.value == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: colors.text.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
