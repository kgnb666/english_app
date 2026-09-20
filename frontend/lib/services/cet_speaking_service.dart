import "api_service.dart";

class CetSpeakingService {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> getQuestions(String examType) async {
    final r = await _api.dio
        .get("/cet/speaking/questions", queryParameters: {"exam_type": examType});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> submit({
    required String examType,
    required String question,
    required String userAnswer,
  }) async {
    final r = await _api.dio.post("/cet/speaking/submit",
        data: {
          "exam_type": examType,
          "question": question,
          "user_answer": userAnswer,
        },
        options: ApiService.aiReceiveTimeout());
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final r = await _api.dio.get("/cet/speaking/history");
    return (r.data as List).cast<Map<String, dynamic>>();
  }
}
