import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "api_service.dart";

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _username;
  String? _userId;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get username => _username;
  String? get userId => _userId;

  Future<bool> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token != null) { _isLoggedIn = true; notifyListeners(); return true; }
    return false;
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final r = await _api.dio.post("/auth/login", data: {"username": username, "password": password});
      final d = r.data;
      await _api.saveToken(d["access_token"]);
      _username = d["username"]; _userId = d["user_id"];
      _isLoggedIn = true; _isLoading = false; notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data["detail"] ?? "Login failed";
      _isLoading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true; _errorMessage = null; notifyListeners();
    try {
      final r = await _api.dio.post("/auth/register", data: {"username": username, "email": email, "password": password});
      final d = r.data;
      await _api.saveToken(d["access_token"]);
      _username = d["username"]; _userId = d["user_id"];
      _isLoggedIn = true; _isLoading = false; notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data["detail"] ?? "Registration failed";
      _isLoading = false; notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _isLoggedIn = false; _username = null; _userId = null;
    notifyListeners();
  }
}
