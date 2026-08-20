import "api_service.dart";

class LearningProfile {
  final String englishLevel;
  final String? goal;
  final int vocabularySize;
  final List<String> weakSkills;
  final Map<String, dynamic> preferences;
  final List<Map<String, dynamic>> commonErrors;

  LearningProfile.fromJson(Map<String, dynamic> json)
      : englishLevel = json["english_level"] ?? "beginner",
        goal = json["goal"],
        vocabularySize = (json["vocabulary_size"] as num?)?.toInt() ?? 0,
        weakSkills = (json["weak_skills"] as List? ?? []).map((e) => e.toString()).toList(),
        preferences = json["preferences"] as Map<String, dynamic>? ?? const {},
        commonErrors = (json["common_errors"] as List? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
}

class ErrorLogItem {
  final String id;
  final String wrongText;
  final String correctText;
  final String errorType;
  final String errorTypeCn;
  final int count;
  final String lastSeenAt;

  ErrorLogItem.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        wrongText = json["wrong_text"] ?? "",
        correctText = json["correct_text"] ?? "",
        errorType = json["error_type"] ?? "other",
        errorTypeCn = json["error_type_cn"] ?? "其他错误",
        count = (json["count"] as num?)?.toInt() ?? 0,
        lastSeenAt = json["last_seen_at"] ?? "";
}

class ProfileService {
  final _api = ApiService();

  Future<LearningProfile> getProfile() async {
    final r = await _api.dio.get("/profile");
    return LearningProfile.fromJson(r.data as Map<String, dynamic>);
  }

  Future<LearningProfile> updateProfile(Map<String, dynamic> data) async {
    final r = await _api.dio.put("/profile", data: data);
    return LearningProfile.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<ErrorLogItem>> getErrors({int limit = 50}) async {
    final r = await _api.dio
        .get("/profile/errors", queryParameters: {"limit": limit});
    final data = r.data as Map<String, dynamic>;
    return (data["items"] as List? ?? [])
        .map((j) => ErrorLogItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteError(String id) async {
    await _api.dio.delete("/profile/errors/$id");
  }
}
