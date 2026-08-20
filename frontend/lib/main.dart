import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "app.dart";
import "config/api_config.dart";
import "services/auth_provider.dart";
import "services/theme_provider.dart";
import "services/notification_service.dart";
import "services/api_service.dart";
import "services/study_session_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 加载动态 API 配置（配置文件 + 用户自定义地址）
  await ApiConfig.load();
  // 注册统一错误处理：401 时跳转登录页
  ApiService.onUnauthorized = () {
    final current = appRouter.routerDelegate.currentConfiguration.uri.path;
    if (current != "/login") {
      appRouter.go("/login");
    }
  };
  // 初始化本地通知（学习提醒）
  await NotificationService.instance.init(onNotificationTap: (route) {
    appRouter.go(route);
  });
  // 初始化真实学习计时（前后台自动暂停）
  StudySessionService.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const EnglishCoachApp(),
    ),
  );
}
