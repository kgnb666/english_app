import "api_service.dart";

class ReadingResult {
  final String summaryCn;
  final String mainIdea;
  final List<VocabItem> vocabulary;
  final List<SentenceItem> complexSentences;

  ReadingResult.fromJson(Map<String, dynamic> json)
      : summaryCn = json["summary_cn"] ?? "",
        mainIdea = json["main_idea"] ?? "",
        vocabulary = (json["vocabulary"] as List? ?? []).map((v) => VocabItem.fromJson(v)).toList(),
        complexSentences = (json["complex_sentences"] as List? ?? []).map((s) => SentenceItem.fromJson(s)).toList();
}

class VocabItem {
  final String word, definitionCn;
  VocabItem.fromJson(Map<String, dynamic> json)
      : word = json["word"] ?? "", definitionCn = json["definition_cn"] ?? "";
}

class SentenceItem {
  final String original, analysisCn;
  SentenceItem.fromJson(Map<String, dynamic> json)
      : original = json["original"] ?? "", analysisCn = json["analysis_cn"] ?? "";
}

class ReadingService {
  final _api = ApiService();

  Future<ReadingResult> analyze(String article) async {
    final r = await _api.dio.post("/reading/analyze",
        data: {"article": article}, options: ApiService.aiReceiveTimeout());
    return ReadingResult.fromJson(r.data);
  }

  Future<List<ReadingHistoryItem>> getHistory({int page = 1, int pageSize = 20}) async {
    final r = await _api.dio.get("/reading/history", queryParameters: {"page": page, "page_size": pageSize});
    return (r.data["items"] as List).map((j) => ReadingHistoryItem.fromJson(j)).toList();
  }

  Future<ReadingHistoryDetail> getHistoryDetail(String id) async {
    final r = await _api.dio.get("/reading/history/$id");
    return ReadingHistoryDetail.fromJson(r.data);
  }

  Future<void> deleteRecord(String id) async {
    await _api.dio.delete("/reading/history/$id");
  }
}

class ReadingHistoryItem {
  final String id;
  final String articlePreview;
  final String summaryCn;
  final String createdAt;

  ReadingHistoryItem.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        articlePreview = json["article_preview"] ?? "",
        summaryCn = json["summary_cn"] ?? "",
        createdAt = json["created_at"] ?? "";
}

class ReadingHistoryDetail {
  final String id;
  final String articleContent;
  final ReadingResult result;
  final String createdAt;

  ReadingHistoryDetail.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        articleContent = json["article_content"] ?? "",
        result = ReadingResult.fromJson(json["analysis_result"] as Map<String, dynamic>? ?? const {}),
        createdAt = json["created_at"] ?? "";
}
