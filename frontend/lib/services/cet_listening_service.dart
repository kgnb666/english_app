import "api_service.dart";

class CetListeningService {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getItems(String examType) async {
    final r = await _api.dio
        .get("/cet/listening/items", queryParameters: {"exam_type": examType});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getItem(String itemId) async {
    final r = await _api.dio.get("/cet/listening/items/$itemId");
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submit({
    required String examType,
    required String itemId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final r = await _api.dio.post("/cet/listening/submit", data: {
      "exam_type": examType,
      "item_id": itemId,
      "answers": answers,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await _api.dio.get("/cet/listening/history");
    return (r.data as List).cast<Map<String, dynamic>>();
  }
}
