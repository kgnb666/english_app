import "api_service.dart";

class WritingResult {
  final int score;
  final String suggestions;
  final String optimized;
  final List<ErrorItem> errors;
  WritingResult.fromJson(Map<String, dynamic> json)
      : score = json["score"] ?? 0,
        suggestions = json["suggestions"] ?? "",
        optimized = json["optimized"] ?? "",
        errors = (json["errors"] as List? ?? []).map((e) => ErrorItem.fromJson(e)).toList();
}

class ErrorItem {
  final String original, correction, explanation;
  ErrorItem.fromJson(Map<String, dynamic> json)
      : original = json["original"] ?? "", correction = json["correction"] ?? "", explanation = json["explanation"] ?? "";
}

class WritingService {
  final _api = ApiService();
  Future<WritingResult> review(String essay) async {
    final r = await _api.dio.post("/writing/review",
        data: {"essay": essay}, options: ApiService.aiReceiveTimeout());
    return WritingResult.fromJson(r.data);
  }

  Future<List<WritingHistoryItem>> getHistory({int page = 1, int pageSize = 20}) async {
    final r = await _api.dio.get("/writing/history", queryParameters: {"page": page, "page_size": pageSize});
    return (r.data["items"] as List).map((j) => WritingHistoryItem.fromJson(j)).toList();
  }

  Future<WritingHistoryDetail> getHistoryDetail(String id) async {
    final r = await _api.dio.get("/writing/history/$id");
    return WritingHistoryDetail.fromJson(r.data);
  }

  Future<void> deleteRecord(String id) async {
    await _api.dio.delete("/writing/history/$id");
  }
}

class WritingHistoryItem {
  final String id;
  final String preview;
  final int score;
  final String createdAt;

  WritingHistoryItem.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        preview = json["preview"] ?? "",
        score = json["score"] ?? 0,
        createdAt = json["created_at"] ?? "";
}

class WritingHistoryDetail {
  final String id;
  final String originalText;
  final int score;
  final WritingResult result;
  final String createdAt;

  WritingHistoryDetail.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        originalText = json["original_text"] ?? "",
        score = json["score"] ?? 0,
        result = WritingResult.fromJson(json["correction_result"] as Map<String, dynamic>? ?? const {}),
        createdAt = json["created_at"] ?? "";
}
