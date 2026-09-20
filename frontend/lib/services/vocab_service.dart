import "api_service.dart";

class VocabWordModel {
  final String id, word;
  final String? phonetic, partOfSpeech, chineseDefinition;
  final String? difficulty, category;
  final String? examType;
  final String? wordLevel;
  final List? exampleSentences;
  final Map<String, dynamic>? progress;
  final String? bookmarkSource;
  final String? audioUrl;

  VocabWordModel.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        word = json["word"],
        phonetic = json["phonetic"],
        partOfSpeech = json["part_of_speech"],
        chineseDefinition = json["chinese_definition"],
        difficulty = json["difficulty"],
        category = json["category"],
        examType = json["exam_type"],
        wordLevel = json["word_level"],
        exampleSentences = json["example_sentences"],
        progress = json["progress"],
        bookmarkSource = json["bookmark_source"],
        audioUrl = json["audio_url"];

  String get statusStr {
    final s = progress?["status"] as String?;
    switch (s) {
      case "learning": return "Learning";
      case "review": return "To Review";
      case "mastered": return "Mastered";
      default: return "New";
    }
  }
}

class VocabSummaryModel {
  final int total, learnedCount, masteredCount, reviewCount, errorCount, bookmarkedCount;
  final int newCount, learning, review, mastered, todayReview;
  VocabSummaryModel.fromJson(Map<String, dynamic> json)
      : total = json["total"] ?? 0,
        learnedCount = json["learned_count"] ?? 0,
        masteredCount = json["mastered_count"] ?? 0,
        reviewCount = json["review_count"] ?? 0,
        errorCount = json["error_count"] ?? 0,
        bookmarkedCount = json["bookmarked_count"] ?? 0,
        newCount = json["new_count"] ?? 0,
        learning = json["learning"] ?? 0,
        review = json["review"] ?? 0,
        mastered = json["mastered"] ?? 0,
        todayReview = json["today_review"] ?? 0;
}

class VocabService {
  final _api = ApiService();

  /// 清理 AI 记忆法中的 Markdown 符号，保留换行结构（兼容历史脏数据）
  static String cleanMarkdown(String text) {
    if (text.isEmpty) return text;
    final lines = <String>[];
    for (final raw in text.split("\n")) {
      var line = raw.trimRight();
      final stripped = line.trim();
      if (RegExp(r"^[-*_]{3,}$").hasMatch(stripped)) continue;
      if (stripped == "```") continue;
      line = line.replaceFirst(RegExp(r"^#{1,6}\s*"), "");
      line = line.replaceFirst(RegExp(r"^>\s?"), "");
      line = line.replaceAllMapped(RegExp(r"\*\*(.+?)\*\*"), (m) => m.group(1)!);
      line = line.replaceAllMapped(
          RegExp(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r"`([^`]+)`"), (m) => m.group(1)!);
      lines.add(line);
    }
    var result = lines.join("\n");
    result = result.replaceAll(RegExp(r"\n{3,}"), "\n\n");
    return result.trim();
  }

  Future<List<VocabWordModel>> getWords({
    String? status,
    String? search,
    String? examType,
    String? wordLevel,
    int page = 1,
  }) async {
    final params = <String, dynamic>{"page": page, "page_size": 50};
    if (status != null) params["status"] = status;
    if (examType != null) params["exam_type"] = examType;
    if (wordLevel != null) params["word_level"] = wordLevel;
    if (search != null && search.trim().isNotEmpty) params["search"] = search.trim();
    final r = await _api.dio.get("/vocabulary/words", queryParameters: params);
    return (r.data["items"] as List).map((j) => VocabWordModel.fromJson(j)).toList();
  }

  /// 真题例句列表
  Future<List<Map<String, dynamic>>> getWordExamples(String wordId) async {
    final r = await _api.dio.get("/vocabulary/words/$wordId/examples");
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  /// 录入真题例句
  Future<void> addWordExample(
    String wordId, {
    required String example,
    required String translationCn,
    String? source,
  }) async {
    await _api.dio.post("/vocabulary/words/$wordId/examples", data: {
      "example": example,
      "translation_cn": translationCn,
      if (source != null && source.isNotEmpty) "source": source,
    });
  }

  /// 分页搜索（返回 列表 + 总数），支持滚动加载更多
  Future<(List<VocabWordModel>, int)> getWordsPage({
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, dynamic>{"page": page, "page_size": pageSize};
    if (search != null && search.trim().isNotEmpty) params["search"] = search.trim();
    final r = await _api.dio.get("/vocabulary/words", queryParameters: params);
    final data = r.data as Map<String, dynamic>;
    final items = (data["items"] as List)
        .map((j) => VocabWordModel.fromJson(j))
        .toList();
    return (items, (data["total"] as num?)?.toInt() ?? items.length);
  }

  Future<VocabWordModel> getWordDetail(String wordId) async {
    final r = await _api.dio.get("/vocabulary/words/$wordId");
    return VocabWordModel.fromJson(r.data);
  }

  Future<List<VocabWordModel>> getMyProgress({String? status}) async {
    final params = status != null ? <String, dynamic>{"status": status} : null;
    final r = await _api.dio.get("/vocabulary/my-progress", queryParameters: params);
    return (r.data as List).map((j) => VocabWordModel.fromJson(j)).toList();
  }

  Future<VocabWordModel> startLearning(String wordId) async {
    final r = await _api.dio.post("/vocabulary/words/$wordId/start");
    return VocabWordModel.fromJson(r.data);
  }

  Future<VocabWordModel> reviewWord(String wordId, bool correct) async {
    final r = await _api.dio.post("/vocabulary/words/$wordId/review?correct=$correct");
    return VocabWordModel.fromJson(r.data);
  }

  Future<VocabWordModel> generateMemoryAid(String wordId) async {
    final r = await _api.dio.post("/vocabulary/words/$wordId/memory-aid",
        options: ApiService.aiReceiveTimeout());
    return VocabWordModel.fromJson(r.data);
  }

  /// 为单词生成固定音频资源并返回（含 audio_url）
  Future<Map<String, dynamic>> ensureAudio(String wordId) async {
    final r = await _api.dio.post("/vocabulary/words/$wordId/audio",
        options: ApiService.aiReceiveTimeout());
    return r.data as Map<String, dynamic>;
  }

  Future<VocabSummaryModel> getSummary() async {
    final r = await _api.dio.get("/vocabulary/summary");
    return VocabSummaryModel.fromJson(r.data);
  }

  // ===== 生词本 =====

  Future<List<VocabWordModel>> getBookmarks() async {
    final r = await _api.dio.get("/vocabulary/bookmarks");
    return (r.data as List).map((j) => VocabWordModel.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> addBookmark({
    required String word,
    String? chineseDefinition,
    String source = "manual",
    String? context,
  }) async {
    final r = await _api.dio.post("/vocabulary/bookmark", data: {
      "word": word,
      if (chineseDefinition != null && chineseDefinition.isNotEmpty)
        "chinese_definition": chineseDefinition,
      "source": source,
      if (context != null && context.isNotEmpty) "context": context,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> removeBookmark(String wordId) async {
    await _api.dio.delete("/vocabulary/bookmark/$wordId");
  }

  // ===== 单词测验 =====

  Future<List<QuizQuestion>> generateTest(String testType, {int count = 10}) async {
    final r = await _api.dio.get("/vocabulary/test/generate",
        queryParameters: {"test_type": testType, "count": count},
        options: ApiService.aiReceiveTimeout());
    return (r.data["questions"] as List).map((j) => QuizQuestion.fromJson(j)).toList();
  }

  Future<QuizResult> submitTest(String testType, List<Map<String, dynamic>> answers) async {
    final r = await _api.dio.post("/vocabulary/test/submit", data: {"test_type": testType, "answers": answers});
    return QuizResult.fromJson(r.data);
  }

  Future<List<TestHistoryItem>> getTestHistory({int page = 1, int pageSize = 10}) async {
    final r = await _api.dio.get("/vocabulary/test/history", queryParameters: {"page": page, "page_size": pageSize});
    return (r.data["items"] as List).map((j) => TestHistoryItem.fromJson(j)).toList();
  }
}

class QuizQuestion {
  final String wordId;
  final String word;
  final String? phonetic;
  final String? audioUrl;
  final String correct;
  final List<String> options;

  QuizQuestion.fromJson(Map<String, dynamic> json)
      : wordId = json["word_id"] ?? "",
        word = json["word"] ?? "",
        phonetic = json["phonetic"],
        audioUrl = json["audio_url"],
        correct = json["correct"] ?? "",
        options = (json["options"] as List? ?? []).map((o) => o.toString()).toList();
}

class QuizResult {
  final int score;
  final int total;
  final int accuracy;
  final List<QuizAnswerResult> results;

  QuizResult.fromJson(Map<String, dynamic> json)
      : score = json["score"] ?? 0,
        total = json["total"] ?? 0,
        accuracy = json["accuracy"] ?? 0,
        results = (json["results"] as List? ?? []).map((j) => QuizAnswerResult.fromJson(j)).toList();
}

class QuizAnswerResult {
  final String word;
  final String userAnswer;
  final String correct;
  final bool isCorrect;

  QuizAnswerResult.fromJson(Map<String, dynamic> json)
      : word = json["word"] ?? "",
        userAnswer = json["user_answer"] ?? "",
        correct = json["correct"] ?? "",
        isCorrect = json["is_correct"] ?? false;
}

class TestHistoryItem {
  final String id;
  final String testType;
  final int score;
  final int total;
  final int accuracy;
  final String createdAt;

  TestHistoryItem.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        testType = json["test_type"] ?? "",
        score = json["score"] ?? 0,
        total = json["total"] ?? 0,
        accuracy = json["accuracy"] ?? 0,
        createdAt = json["created_at"] ?? "";
}
