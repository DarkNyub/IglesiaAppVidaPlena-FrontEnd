class ApiConstants {
  // Ajusta según tu emulador/dispositivo
  // Android Emulator: 10.0.2.2 | Web/iOS: localhost
  //static const String baseUrl = "http://localhost:5009/api";

  // === AUTH ===
  static const String login = "auth/login";

  // === MAESTROS DE SISTEMA ===
  static const String systemRoles = "system-roles";
  static const String userSystemRoles = "user-system-roles";

  // === NUEVA ARQUITECTURA ORGANIZACIONAL ===
  // Antes eran networks/ministries, ahora todo es estructura
  static const String organizationTypes = "organization-types";
  static const String organizationStructures = "organization-structures";
  static const String churchRoles = "church-function-roles";
  static const String organizationMembers = "organization-members";

  // === MIEMBROS Y USUARIOS ===
  static const String members = "members";
  static const String users = "users";

  // === GESTIÓN DE EVENTOS Y FORMULARIOS ===
  static const String events = "events";
  static const String recordTypes = "record-types";
  static const String recordTypeFields = "record-type-fields";
  static const String registryEvents = "registry-events";

  static const String reports = "reports";
  // === HELPERS ===
  // Obtener estructura del formulario para un evento
  static String eventStructure(int eventId) =>
      "$recordTypes/event/$eventId/structure";

  // Obtener campos de un tipo de registro
  static String fieldsByRecordType(int recordTypeId) =>
      "$recordTypeFields/by-record-type/$recordTypeId";
}
