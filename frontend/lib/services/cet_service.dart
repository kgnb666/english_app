import "api_service.dart";

class CetService {
  final _api = ApiService();

  Future<Map<String, dynamic>> getDashboard() async {
    final r = await _api.dio.get("/cet/dashboard");
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setGoal({
    required String examType,
    required int targetScore,
    required String examDate,
    required int dailyMinutes,
  }) async {
    final r = await _api.dio.put("/cet/goal", data: {
      "exam_type": examType,
      "target_score": targetScore,
      "exam_date": examDate,
      "daily_minutes": dailyMinutes,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> cancelGoal() async {
    await _api.dio.delete("/cet/goal");
  }
}
