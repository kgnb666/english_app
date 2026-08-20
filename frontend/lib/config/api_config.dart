import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 全局 API 配置
///
/// 地址解析优先级（高 -> 低）：
/// 1. 编译期 `--dart-define=API_BASE_URL=...`
/// 2. 用户在 App 内“服务器设置”中自定义的地址（shared_preferences 持久化）
/// 3. `assets/config/app_config.json` 中当前环境（API_ENV）对应的 apiBaseUrl
/// 4. 本地回退地址（仅用于未配置任何地址时的兜底，非固定服务器）
///
/// 环境通过 `--dart-define=API_ENV=dev|test|prod` 选择，默认 dev。
class ApiConfig {
  /// 无任何配置时的本地兜底地址（Android 模拟器访问宿主机请改为 10.0.2.2）
  static const String fallbackBaseUrl = "http://localhost:8002/api/v1";

  /// 编译期环境：flutter run --dart-define=API_ENV=test
  static const String env = String.fromEnvironment("API_ENV", defaultValue: "dev");

  /// 编译期地址覆盖：flutter run --dart-define=API_BASE_URL=http://host:port/api/v1
  static const String _baseUrlFromDefine = String.fromEnvironment("API_BASE_URL");

  static const int connectTimeout = 10000;
  static const int receiveTimeout = 30000;

  static const String _prefsKey = "custom_api_base_url";

  static String _envDefaultUrl = fallbackBaseUrl;
  static String? _userOverride;

  /// 当前生效的 API 基础地址
  static String baseUrl = _baseUrlFromDefine.isNotEmpty ? _baseUrlFromDefine : fallbackBaseUrl;

  /// 用户是否设置了自定义服务器地址
  static bool get hasUserOverride => _userOverride != null && _userOverride!.isNotEmpty;

  /// App 启动时调用：读取配置文件 + 用户自定义地址
  static Future<void> load() async {
    _envDefaultUrl = await _readEnvDefaultUrl();
    if (_baseUrlFromDefine.isNotEmpty) {
      _envDefaultUrl = _baseUrlFromDefine;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _userOverride = prefs.getString(_prefsKey);
    } catch (e) {
      debugPrint("ApiConfig.load prefs error: $e");
    }
    baseUrl = hasUserOverride ? _userOverride! : _envDefaultUrl;
  }

  /// 设置用户自定义服务器地址（自动补全 /api/v1 后缀）
  static Future<void> setUserBaseUrl(String url) async {
    var normalized = url.trim();
    if (normalized.isEmpty) {
      await clearUserOverride();
      return;
    }
    if (!normalized.startsWith("http://") && !normalized.startsWith("https://")) {
      normalized = "http://$normalized";
    }
    if (!normalized.endsWith("/api/v1")) {
      normalized = normalized.endsWith("/") ? "${normalized}api/v1" : "$normalized/api/v1";
    }
    _userOverride = normalized;
    baseUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    } catch (e) {
      debugPrint("ApiConfig.setUserBaseUrl error: $e");
    }
  }

  /// 清除用户自定义地址，回到环境默认配置
  static Future<void> clearUserOverride() async {
    _userOverride = null;
    baseUrl = _envDefaultUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint("ApiConfig.clearUserOverride error: $e");
    }
  }

  static Future<String> _readEnvDefaultUrl() async {
    try {
      final raw = await rootBundle.loadString("assets/config/app_config.json");
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final environments = map["environments"] as Map<String, dynamic>? ?? const {};
      final selected = environments[env] as Map<String, dynamic>?;
      final url = selected?["apiBaseUrl"] as String?;
      if (url != null && url.isNotEmpty) return url;
    } catch (e) {
      debugPrint("ApiConfig.readEnvDefaultUrl error: $e");
    }
    return fallbackBaseUrl;
  }
}
