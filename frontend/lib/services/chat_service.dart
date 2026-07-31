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
}

