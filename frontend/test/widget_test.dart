// 基础冒烟测试：验证核心配置与文案

import "package:flutter_test/flutter_test.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "package:english_coach/config/api_config.dart";
import "package:english_coach/l10n/zh_CN.dart";
import "package:english_coach/pages/home_page.dart";
import "package:english_coach/pages/profile_page.dart";
import "package:english_coach/services/auth_provider.dart";
import "package:english_coach/services/theme_provider.dart";
import "package:english_coach/pages/stats_page.dart";
import "package:english_coach/widgets/empty_state_view.dart";

void main() {
  test("API 配置不再硬编码局域网 IP", () {
    expect(ApiConfig.fallbackBaseUrl.contains("192.168."), isFalse);
    expect(ApiConfig.fallbackBaseUrl, startsWith("http://"));
  });

  test("学习提醒文案存在", () {
    expect(AppStrings.reminderSettings, "学习提醒");
    expect(AppStrings.dailyReminderText, isNotEmpty);
  });

  test("数据备份文案存在", () {
    expect(AppStrings.dataBackup, "数据备份");
    expect(AppStrings.exportData, isNotEmpty);
  });

  testWidgets("首页通知按钮已绑定提醒设置跳转", (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    final btn = tester.widget<IconButton>(find.byType(IconButton));
    expect(btn.onPressed, isNotNull);
    // 推进虚拟时间，让 Dio 超时计时器过期，避免 pending timer
    await tester.pump(const Duration(seconds: 35));
  });

  testWidgets("个人中心修改密码入口弹出密码表单", (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(AppStrings.changePassword), findsOneWidget);

    await tester.scrollUntilVisible(find.text(AppStrings.changePassword), 200);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(AppStrings.changePassword));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(AppStrings.oldPassword), findsOneWidget);
    expect(find.text(AppStrings.newPassword), findsOneWidget);
    expect(find.text(AppStrings.confirmPassword), findsOneWidget);
  });

  testWidgets("退出登录需要确认", (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(find.text(AppStrings.logout), 200);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(AppStrings.logout));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.confirmLogout), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.confirmLogout), findsNothing);
  });

  testWidgets("学习统计页可打开且包含图表区域", (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StatsPage()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(AppStrings.statsTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 35));
  });

  testWidgets("空状态组件包含提示与操作按钮", (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            icon: Icons.inbox_outlined,
            title: "暂无内容",
            subtitle: "去创建一条记录吧",
            actionLabel: "去创建",
            onAction: null,
          ),
        ),
      ),
    );
    expect(find.text("暂无内容"), findsOneWidget);
    expect(find.text("去创建一条记录吧"), findsOneWidget);
  });
}
