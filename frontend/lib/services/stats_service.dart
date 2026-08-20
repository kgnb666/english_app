import "api_service.dart";

class DashboardModel {
  final Map<String, dynamic> today;
  final Map<String, dynamic> total;
  final Map<String, dynamic> words;
  final int streakDays;
  final String englishLevel;

  DashboardModel.fromJson(Map<String, dynamic> json)
      : today = json["today"] ?? {},
        total = json["total"] ?? {},
        words = json["words"] ?? {},
        streakDays = json["streak_days"] ?? 0,
        englishLevel = json["english_level"] ?? "beginner";
}

class StatsService {
  final _api = ApiService();

  Future<DashboardModel> getDashboard() async {
    final r = await _api.dio.get("/stats/dashboard");
    return DashboardModel.fromJson(r.data);
  }

  Future<List<Map<String, dynamic>>> getWeekly() async {
    final r = await _api.dio.get("/stats/weekly");
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  /// 月度统计（汇总 + 每日明细）
  Future<Map<String, dynamic>> getMonthly(int year, int month) async {
    final r = await _api.dio
        .get("/stats/monthly", queryParameters: {"year": year, "month": month});
    return r.data as Map<String, dynamic>;
  }

  /// 学习日历（当月每天学习情况）
  Future<List<Map<String, dynamic>>> getCalendar(int year, int month) async {
    final r = await _api.dio
        .get("/stats/calendar", queryParameters: {"year": year, "month": month});
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  /// 开始学习计时
  Future<Map<String, dynamic>> startSession(String type) async {
    final r = await _api.dio
        .post("/stats/sessions", data: {"session_type": type});
    return r.data as Map<String, dynamic>;
  }

  /// 结束学习计时并上报真实活跃秒数
  Future<void> endSession(String sessionId, int seconds) async {
    await _api.dio.post("/stats/sessions/$sessionId/end",
        data: {"duration_seconds": seconds});
  }

  /// 今日任务（真实数据）
  Future<Map<String, dynamic>> getTodayTasks() async {
    final r = await _api.dio.get("/plan/today");
    return r.data as Map<String, dynamic>;
  }

  /// 学习计划模板
  Future<List<Map<String, dynamic>>> getPlan() async {
    final r = await _api.dio.get("/plan");
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  /// 更新学习计划模板
  Future<void> updatePlan(List<Map<String, dynamic>> tasks) async {
    await _api.dio.put("/plan", data: {"tasks": tasks});
  }
}
