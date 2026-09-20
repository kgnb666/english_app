import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "../l10n/server_messages.dart";
import "../l10n/zh_CN.dart";
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

  /// 自动登录：本地有 refresh_token 则调用 /auth/refresh 换取新令牌
  /// 成功进入首页；无令牌或刷新失败则回登录页
  Future<bool> tryAutoLogin() async {
    final refreshToken = await _api.getRefreshToken();
    if (refreshToken == null) {
      _isLoggedIn = false;
      return false;
    }
    try {
      final r = await _api.dio.post(
        "/auth/refresh",
        data: {"refresh_token": refreshToken},
      );
      final d = r.data as Map<String, dynamic>;
      await _api.saveSession(
        accessToken: d["access_token"] as String,
        refreshToken: d["refresh_token"] as String,
        userId: d["user_id"] as String,
        username: d["username"] as String,
      );
      _applyUser(d);
      return true;
    } catch (e) {
      debugPrint("Auto login failed: $e");
      await _api.clearAllTokens();
      // 有 refresh_token 但刷新失败 => 登录已过期，提示后回登录页（不突然退出）
      ApiService.showError("登录已过期，请重新登录");
      _isLoggedIn = false;
      _username = null;
      _userId = null;
      notifyListeners();
      return false;
    }
  }

  /// 从本地存储恢复用户信息（已登录状态下使用）
  Future<void> restoreUser() async {
    final info = await _api.readUserInfo();
    if (info != null) {
      _username = info["username"];
      _userId = info["user_id"];
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final r = await _api.dio.post(
        "/auth/login",
        data: {"username": username, "password": password},
      );
      final d = r.data as Map<String, dynamic>;
      await _saveSessionFromResponse(d);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data is Map
          ? ServerMessages.localize(
              e.response!.data["detail"],
              fallback: AppStrings.loginFailed,
            )
          : AppStrings.loginFailed;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final r = await _api.dio.post(
        "/auth/register",
        data: {"username": username, "email": email, "password": password},
      );
      final d = r.data as Map<String, dynamic>;
      await _saveSessionFromResponse(d);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errorMessage = e.response?.data is Map
          ? ServerMessages.localize(
              e.response!.data["detail"],
              fallback: AppStrings.registerFailed,
            )
          : AppStrings.registerFailed;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 退出登录：先撤销后端 refresh_token，再清空本地令牌
  Future<void> logout() async {
    try {
      final rt = await _api.getRefreshToken();
      if (rt != null) {
        await _api.dio.post("/auth/logout", data: {"refresh_token": rt});
      }
    } catch (e) {
      debugPrint("Logout revoke error: $e");
    }
    await _api.clearAllTokens();
    _isLoggedIn = false;
    _username = null;
    _userId = null;
    notifyListeners();
  }

  Future<void> _saveSessionFromResponse(Map<String, dynamic> d) async {
    await _api.saveSession(
      accessToken: d["access_token"] as String,
      refreshToken: d["refresh_token"] as String,
      userId: d["user_id"] as String,
      username: d["username"] as String,
    );
    _applyUser(d);
  }

  void _applyUser(Map<String, dynamic> d) {
    _userId = d["user_id"] as String?;
    _username = d["username"] as String?;
  }
}
