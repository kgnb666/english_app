import "api_service.dart";

class CetTranslationService {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getSentences(String examType) async {
    final r = await _api.dio
        .get("/cet/translation/sentences", queryParameters: {"exam_type": examType});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submit({
    required String examType,
    required String sentenceId,
    required String userTranslation,
  }) async {
    final r = await _api.dio.post("/cet/translation/submit",
        data: {
          "exam_type": examType,
          "sentence_id": sentenceId,
          "user_translation": userTranslation,
        },
        options: ApiService.aiReceiveTimeout());
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await _api.dio.get("/cet/translation/history");
    return (r.data as List).cast<Map<String, dynamic>>();
  }
}
