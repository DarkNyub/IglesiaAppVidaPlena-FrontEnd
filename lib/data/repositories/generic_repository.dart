import '../services/api_service.dart';

class GenericRepository {
  final ApiService _api = ApiService();
  final String endpoint;

  GenericRepository({required this.endpoint});

  // 1. LISTAR
  Future<List<dynamic>> getAll() async {
    try {
      final response = await _api.get(endpoint);
      return response is List ? response : [];
    } catch (e) {
      throw Exception(_handleError(e)); // 🔥 Lanza Exception, no un String
    }
  }

  // 2. OBTENER POR ID
  Future<dynamic> getById(int id) async {
    try {
      return await _api.get('$endpoint/$id');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // 3. GUARDAR (POST/PUT Automático)
  Future<void> save(Map<String, dynamic> data) async {
    try {
      final id = data['id'];

      if (id != null && id != 0) {
        // PUT (Editar)
        await _api.put('$endpoint/$id', data);
      } else {
        // POST (Crear) - Quitamos el ID para no confundir al backend
        final cleanData = Map<String, dynamic>.from(data)..remove('id');
        await _api.post(endpoint, cleanData);
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // 4. ELIMINAR (Soft Delete en el backend)
  Future<void> delete(int id) async {
    try {
      await _api.delete('$endpoint/$id');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // 5. ACCIÓN PERSONALIZADA (Toggle, Restore, etc.)
  // 🔥 Le agregamos un body opcional por si el endpoint lo requiere
  Future<dynamic> customPost(
    int id,
    String actionPath, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      return await _api.post('$endpoint/$id/$actionPath', body ?? {});
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- MANEJO DE ERRORES CENTRALIZADO ---
  String _handleError(dynamic error) {
    final e = error.toString().toLowerCase();

    // Si el ApiService ya limpió el mensaje (ej. "Usuario suspendido"), lo extraemos:
    if (e.contains("exception:")) {
      return error.toString().replaceAll("Exception: ", "").trim();
    }

    if (e.contains("401"))
      return "Sesión expirada. Por favor, inicia sesión nuevamente.";
    if (e.contains("403"))
      return "No tienes permisos para realizar esta acción.";
    if (e.contains("404")) return "Registro no encontrado.";
    if (e.contains("network") ||
        e.contains("socket") ||
        e.contains("connection")) {
      return "Error de conexión. Verifica tu internet.";
    }

    return "Ocurrió un error inesperado. Intenta de nuevo.";
  }
}
