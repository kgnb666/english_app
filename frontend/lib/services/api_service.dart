import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "../config/api_config.dart";
import "../l10n/zh_CN.dart";

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  /// 全局 SnackBar 入口（挂在 MaterialApp.scaffoldMessengerKey 上）
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 401 未授权回调（由 main.dart 注册，跳转登录页）
  static void Function()? onUnauthorized;

  /// AI 生成类接口专用接收超时（LLM 生成经常超过全局 30s，按请求覆盖避免误报超时）
  static Options aiReceiveTimeout() =>
      Options(receiveTimeout: const Duration(minutes: 3));

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  Future<void>? _refreshFuture;

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {"Content-Type": "application/json"},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: "access_token");
        if (token != null) options.headers["Authorization"] = "Bearer $token";
        handler.next(options);
      },
      onError: (error, handler) async {
        final resp = error.response;
        final status = resp?.statusCode;
        final path = error.requestOptions.path;
        final isAuthRequest = path == "/auth/login" ||
            path == "/auth/register" ||
            path == "/auth/refresh" ||
            path == "/auth/logout";

        // 401 且非认证请求：尝试用 refresh_token 刷新后重放原请求
        if (status == 401 && !isAuthRequest) {
          try {
            await _ensureFreshToken();
            final opts = error.requestOptions;
            final token = await _storage.read(key: "access_token");
            if (token != null) opts.headers["Authorization"] = "Bearer $token";
            final response = await dio.fetch(opts);
            handler.resolve(response);
            return;
          } catch (e) {
            debugPrint("Token refresh failed, force logout: $e");
            await _forceLogout();
            handler.next(error);
            return;
          }
        }
        _handleError(error);
        handler.next(error);
      },
    ));
  }

  /// 统一错误处理：401 跳登录、403 权限提示、5xx 服务器错误、网络错误提示
  static void _handleError(DioException error) {
    final resp = error.response;
    final status = resp?.statusCode;

    final path = error.requestOptions.path;
    final isAuthRequest = path == "/auth/login" ||
        path == "/auth/register" ||
        path == "/auth/refresh" ||
        path == "/auth/logout";
    if (status == 401 && !isAuthRequest) {
      clearTokenSilently();
      onUnauthorized?.call();
      showError(AppStrings.sessionExpired);
      return;
    }
    // 聊天消息接口的错误由聊天页统一处理（失败消息可重试），跳过全局提示
    if (path.contains("/chat/") && path.contains("/messages")) {
      return;
    }
    if (status == 403) {
      showError(AppStrings.permissionDenied);
      return;
    }
    if (status != null && status >= 500) {
      showError(AppStrings.serverError);
      return;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        showError(AppStrings.requestTimeout);
        return;
      case DioExceptionType.connectionError:
        showError(AppStrings.networkError);
        return;
      case DioExceptionType.unknown:
        final msg = error.message ?? "";
        if (msg.contains("SocketException") || msg.contains("Failed host lookup")) {
          showError(AppStrings.networkError);
        }
        return;
      default:
        return;
    }
  }

  /// 并发 401 只触发一次刷新，其余请求等待同一刷新完成
  Future<void> _ensureFreshToken() {
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final f = _doRefresh();
    _refreshFuture = f.whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<void> _doRefresh() async {
    final rt = await _storage.read(key: "refresh_token");
    if (rt == null) throw Exception("No refresh token");
    final r = await dio.post("/auth/refresh", data: {"refresh_token": rt});
    final data = r.data as Map<String, dynamic>;
    await _storage.write(key: "access_token", value: data["access_token"] as String);
    await _storage.write(key: "refresh_token", value: data["refresh_token"] as String);
  }

  /// 刷新失败：清空本地登录态并跳转登录页（带过期提示）
  Future<void> _forceLogout() async {
    await clearToken();
    await _storage.delete(key: "refresh_token");
    await _storage.delete(key: "user_info");
    showError(AppStrings.sessionExpired);
    onUnauthorized?.call();
  }

  static void showError(String message) {
    final messenger = messengerKey.currentState;
    messenger?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// 统一成功提示（绿色 SnackBar）
  static void showSuccess(String message) {
    final messenger = messengerKey.currentState;
    messenger?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  static void clearTokenSilently() {
    _instance._storage.delete(key: "access_token");
  }

  /// 保存完整登录会话（access + refresh + 用户信息）
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    await _storage.write(key: "access_token", value: accessToken);
    await _storage.write(key: "refresh_token", value: refreshToken);
    await _storage.write(
      key: "user_info",
      value: jsonEncode({"user_id": userId, "username": username}),
    );
  }

  Future<Map<String, String>?> readUserInfo() async {
    final raw = await _storage.read(key: "user_info");
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        "user_id": map["user_id"]?.toString() ?? "",
        "username": map["username"]?.toString() ?? "",
      };
    } catch (e) {
      debugPrint("readUserInfo error: $e");
      return null;
    }
  }

  Future<void> clearAllTokens() async {
    await _storage.delete(key: "access_token");
    await _storage.delete(key: "refresh_token");
    await _storage.delete(key: "user_info");
  }

  /// 运行时更新服务器地址（例如用户修改服务器设置后）
  void updateBaseUrl(String url) {
    dio.options.baseUrl = url;
  }

  Future<void> saveToken(String token) async =>
      await _storage.write(key: "access_token", value: token);
  Future<String?> getToken() async => await _storage.read(key: "access_token");
  Future<String?> getRefreshToken() async =>
      await _storage.read(key: "refresh_token");
  Future<void> clearToken() async => await _storage.delete(key: "access_token");
}
