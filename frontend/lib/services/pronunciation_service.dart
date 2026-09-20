import "api_service.dart";

class PronunciationResult {
  final String id;
  final int score;
  final String targetText;
  final String recognizedText;
  final List<Map<String, dynamic>> mispronouncedWords;
  final List<String> suggestions;
  final String overallAdvice;
  final String createdAt;

  PronunciationResult.fromJson(Map<String, dynamic> json)
      : id = json["id"] ?? "",
        score = (json["score"] as num?)?.toInt() ?? 0,
        targetText = json["target_text"] ?? "",
        recognizedText = json["recognized_text"] ?? "",
        mispronouncedWords = ((json["result"] as Map<String, dynamic>?)?["mispronounced_words"]
                as List? ??
            [])
            .map((e) => e as Map<String, dynamic>)
            .toList(),
        suggestions = ((json["result"] as Map<String, dynamic>?)?["suggestions"] as List? ??
                [])
            .map((e) => e.toString())
            .toList(),
        overallAdvice =
            (json["result"] as Map<String, dynamic>?)?["overall_advice"] as String? ?? "",
        createdAt = json["created_at"] ?? "";
}

class PronunciationService {
  final _api = ApiService();

  Future<PronunciationResult> evaluate({
    required String targetText,
    required String recognizedText,
    double? confidence,
  }) async {
    final r = await _api.dio.post("/pronunciation/evaluate",
        data: {
          "target_text": targetText,
          "recognized_text": recognizedText,
          if (confidence != null) "confidence": confidence,
        },
        options: ApiService.aiReceiveTimeout());
    return PronunciationResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<PronunciationResult>> getHistory({int limit = 10}) async {
    final r = await _api.dio
        .get("/pronunciation/history", queryParameters: {"limit": limit});
    return (r.data as List)
        .map((j) => PronunciationResult.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
