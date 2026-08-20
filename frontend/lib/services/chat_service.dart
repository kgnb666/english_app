import "dart:convert";

import "package:dio/dio.dart";

import "api_service.dart";

class ChatSessionModel {
  final String id, title;
  final String? topic;
  final int messageCount;
  final DateTime createdAt, updatedAt;
  ChatSessionModel.fromJson(Map<String, dynamic> json)
      : id = json["id"], title = json["title"] ?? "New Conversation",
        topic = json["topic"], messageCount = json["message_count"] ?? 0,
        createdAt = DateTime.parse(json["created_at"]),
        updatedAt = DateTime.parse(json["updated_at"]);
}

class ChatMessageModel {
  final String id, sessionId, role, content;
  final Map<String, dynamic>? grammarCorrections;
  final DateTime createdAt;
  ChatMessageModel.fromJson(Map<String, dynamic> json)
      : id = json["id"], sessionId = json["session_id"],
        role = json["role"], content = json["content"],
        grammarCorrections = json["grammar_corrections"],
        createdAt = DateTime.parse(json["created_at"]);
}

class ChatService {
  final _api = ApiService();

  /// 根据用户等级与学习记录获取动态推荐话题
  Future<List<String>> getTopics() async {
    final r = await _api.dio.get("/chat/topics");
    return (r.data as List).map((e) => e.toString()).toList();
  }

  Future<List<ChatSessionModel>> getSessions() async {
    final r = await _api.dio.get("/chat/sessions");
    return (r.data as List).map((j) => ChatSessionModel.fromJson(j)).toList();
  }

  Future<ChatSessionModel> createSession({String? topic}) async {
    final uri = topic != null ? "/chat/sessions?topic=$topic" : "/chat/sessions";
    final r = await _api.dio.post(uri);
    return ChatSessionModel.fromJson(r.data);
  }

  Future<void> deleteSession(String id) async => await _api.dio.delete("/chat/sessions/$id");

  Future<List<ChatMessageModel>> getMessages(String sessionId) async {
    final r = await _api.dio.get("/chat/sessions/$sessionId");
    return (r.data["messages"] as List).map((j) => ChatMessageModel.fromJson(j)).toList();
  }

  Future<ChatMessageModel> sendMessage(String sessionId, String content) async {
    final r = await _api.dio.post("/chat/sessions/$sessionId/messages", data: {"content": content});
    return ChatMessageModel.fromJson(r.data);
  }

  /// 流式对话：返回 SSE 的 data 行（事件 JSON 字符串）
  Stream<String> streamMessage(String sessionId, String content) async* {
    final resp = await _api.dio.post<ResponseBody>(
      "/chat/sessions/$sessionId/messages/stream",
      data: {"content": content},
      options: Options(responseType: ResponseType.stream),
    );
    final body = resp.data;
    if (body == null) return;
    yield* body.stream
        .map((chunk) => utf8.decode(chunk))
        .transform(const LineSplitter())
        .where((line) => line.startsWith("data: "))
        .map((line) => line.substring(6).trim());
  }

  /// AI 生成会话总结
  Future<Map<String, dynamic>> getSummary(String sessionId) async {
    final r = await _api.dio.post("/chat/sessions/$sessionId/summary");
    return r.data as Map<String, dynamic>;
  }
}
