import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "../config/api_config.dart";

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

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
      onError: (error, handler) => handler.next(error),
    ));
  }

  Future<void> saveToken(String token) async => await _storage.write(key: "access_token", value: token);
  Future<String?> getToken() async => await _storage.read(key: "access_token");
  Future<void> clearToken() async => await _storage.delete(key: "access_token");
}

