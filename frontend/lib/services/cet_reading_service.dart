import "api_service.dart";

class CetReadingService {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getArticles(String examType) async {
    final r = await _api.dio
        .get("/cet/reading/articles", queryParameters: {"exam_type": examType});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getArticle(String articleId) async {
    final r = await _api.dio.get("/cet/reading/articles/$articleId");
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submit({
    required String examType,
    required String articleId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final r = await _api.dio.post("/cet/reading/submit", data: {
      "exam_type": examType,
      "article_id": articleId,
      "answers": answers,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await _api.dio.get("/cet/reading/history");
    return (r.data as List).cast<Map<String, dynamic>>();
  }
}
