import "api_service.dart";

class CetWritingService {
  final _api = ApiService();

  Future<Map<String, dynamic>> reviewEssay({
    required String essay,
    required String examType,
  }) async {
    final r = await _api.dio.post("/cet/writing/review",
        data: {
          "essay": essay,
          "exam_type": examType,
        },
        options: ApiService.aiReceiveTimeout());
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final r = await _api.dio.get("/cet/writing/templates");
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTemplate({
    required String title,
    required String content,
    String? category,
  }) async {
    final r = await _api.dio.post("/cet/writing/templates", data: {
      "title": title,
      "content": content,
      if (category != null && category.isNotEmpty) "category": category,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteTemplate(String id) async {
    await _api.dio.delete("/cet/writing/templates/$id");
  }

  Future<Map<String, dynamic>> aiRecommend({
    required String examType,
    String category = "议论文",
  }) async {
    final r = await _api.dio.post("/cet/writing/templates/ai-recommend",
        data: {
          "exam_type": examType,
          "category": category,
        },
        options: ApiService.aiReceiveTimeout());
    return r.data as Map<String, dynamic>;
  }
}
