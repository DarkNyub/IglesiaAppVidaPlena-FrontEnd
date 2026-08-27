class RecordTypeModel {
  final int id;
  final String name;
  final String? description;
  final List<RecordTypeFieldModel> fields;

  RecordTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.fields,
  });

  factory RecordTypeModel.fromJson(Map<String, dynamic> json) {
    return RecordTypeModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      fields:
          (json['fields'] as List?)
              ?.map((x) => RecordTypeFieldModel.fromJson(x))
              .toList() ??
          [],
    );
  }
}

class RecordTypeFieldModel {
  final int id;
  final String name; // Clave JSON (ej: offering_amount)
  final String label; // Etiqueta visual (ej: Ofrenda)
  final String dataType; // int, decimal, string, member_selection
  final bool isRequired;
  final int fieldOrder;
  final String? memberSelectionLogic; // Para saber qué lista cargar

  RecordTypeFieldModel({
    required this.id,
    required this.name,
    required this.label,
    required this.dataType,
    required this.isRequired,
    required this.fieldOrder,
    this.memberSelectionLogic,
  });

  factory RecordTypeFieldModel.fromJson(Map<String, dynamic> json) {
    return RecordTypeFieldModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      dataType: json['dataType'] ?? 'string',
      isRequired: json['isRequired'] ?? false,
      fieldOrder: json['fieldOrder'] ?? 0,
      memberSelectionLogic: json['memberSelectionLogic'],
    );
  }
}
