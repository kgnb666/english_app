import "api_service.dart";

class CetCoachService {
  final _api = ApiService();

  Future<Map<String, dynamic>> getProfile() async {
    final r = await _api.dio.get("/cet/coach/profile");
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSuggestion() async {
    final r = await _api.dio.get("/cet/coach/suggestion");
    return r.data as Map<String, dynamic>;
  }
}
