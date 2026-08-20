import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "services/theme_provider.dart";
import "l10n/zh_CN.dart";
import "pages/splash_page.dart";
import "pages/home_page.dart";
import "pages/chat_page.dart";
import "pages/chat_list_page.dart";
import "pages/vocabulary_page.dart";
import "pages/word_detail_page.dart";
import "pages/reading_page.dart";
import "pages/writing_page.dart";
import "pages/profile_page.dart";
import "pages/login_page.dart";
import "pages/register_page.dart";
import "pages/reminder_page.dart";
import "pages/backup_page.dart";
import "pages/server_settings_page.dart";
import "pages/reading_history_page.dart";
import "pages/writing_history_page.dart";
import "pages/quiz_page.dart";
import "pages/stats_page.dart";
import "pages/plan_page.dart";
import "pages/learning_profile_page.dart";
import "pages/pronunciation_page.dart";
import "pages/cet_study_page.dart";
import "pages/cet_vocabulary_page.dart";
import "pages/cet_reading_page.dart";
import "pages/cet_reading_detail_page.dart";
import "pages/cet_writing_page.dart";
import "pages/cet_translation_page.dart";
import "pages/cet_listening_page.dart";
import "pages/cet_listening_detail_page.dart";
import "pages/cet_speaking_page.dart";
import "pages/cet_coach_page.dart";
import "config/theme.dart";
import "services/notification_service.dart";
import "services/api_service.dart";

final appRouter = GoRouter(
  initialLocation: "/splash",
  routes: [
    GoRoute(path: "/splash", builder: (_, __) => const SplashPage()),
    GoRoute(path: "/login", builder: (_, __) => const LoginPage()),
    GoRoute(path: "/register", builder: (_, __) => const RegisterPage()),
    GoRoute(path: "/reminder", builder: (_, __) => const ReminderPage()),
    GoRoute(path: "/backup", builder: (_, __) => const BackupPage()),
    GoRoute(path: "/server-settings", builder: (_, __) => const ServerSettingsPage()),
    GoRoute(path: "/chat/detail", builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>;
      return ChatPage(sessionId: extra["sessionId"] as String, sessionTitle: extra["title"] as String);
    }),
    GoRoute(path: "/vocabulary/detail", builder: (_, state) => WordDetailPage(wordId: state.extra as String)),
    GoRoute(path: "/reading/history", builder: (_, __) => const ReadingHistoryPage()),
    GoRoute(path: "/reading/history/detail", builder: (_, state) => ReadingHistoryDetailPage(recordId: state.extra as String)),
    GoRoute(path: "/writing/history", builder: (_, __) => const WritingHistoryPage()),
    GoRoute(path: "/writing/history/detail", builder: (_, state) => WritingHistoryDetailPage(recordId: state.extra as String)),
    GoRoute(path: "/quiz", builder: (_, __) => const QuizPage()),
    GoRoute(path: "/quiz/run", builder: (_, state) => QuizRunPage(testType: state.extra as String)),
    GoRoute(path: "/stats", builder: (_, __) => const StatsPage()),
    GoRoute(path: "/plan", builder: (_, __) => const PlanPage()),
    GoRoute(path: "/learning-profile", builder: (_, __) => const LearningProfilePage()),
    GoRoute(path: "/pronunciation", builder: (_, __) => const PronunciationPage()),
    GoRoute(path: "/cet", builder: (_, __) => const CetStudyPage()),
    GoRoute(path: "/cet/vocabulary", builder: (_, __) => const CetVocabularyPage()),
    GoRoute(path: "/cet/reading", builder: (_, __) => const CetReadingPage()),
    GoRoute(path: "/cet/reading/article", builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>;
      return CetReadingDetailPage(
        articleId: extra["articleId"] as String,
        examType: extra["examType"] as String,
      );
    }),
    GoRoute(path: "/cet/writing", builder: (_, __) => const CetWritingPage()),
    GoRoute(path: "/cet/translation", builder: (_, __) => const CetTranslationPage()),
    GoRoute(path: "/cet/listening", builder: (_, __) => const CetListeningPage()),
    GoRoute(path: "/cet/listening/detail", builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>;
      return CetListeningDetailPage(
        itemId: extra["itemId"] as String,
        examType: extra["examType"] as String,
      );
    }),
    GoRoute(path: "/cet/speaking", builder: (_, __) => const CetSpeakingPage()),
    GoRoute(path: "/cet/coach", builder: (_, __) => const CetCoachPage()),
    ShellRoute(builder: (_, __, child) => MainShell(child: child), routes: [
      GoRoute(path: "/home", builder: (_, __) => const HomePage()),
      GoRoute(path: "/chat", builder: (_, __) => const ChatListPage()),
      GoRoute(path: "/vocabulary", builder: (_, __) => const VocabularyPage()),
      GoRoute(path: "/reading", builder: (_, __) => const ReadingPage()),
      GoRoute(path: "/writing", builder: (_, __) => const WritingPage()),
      GoRoute(path: "/profile", builder: (_, __) => const ProfilePage()),
    ]),
  ],
);

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith("/chat")) return 1;
    if (loc.startsWith("/vocabulary")) return 2;
    if (loc.startsWith("/reading")) return 3;
    if (loc.startsWith("/writing")) return 4;
    if (loc.startsWith("/profile")) return 5;
    return 0;
  }
  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(body: child, bottomNavigationBar: NavigationBar(selectedIndex: idx, onDestinationSelected: (i) => context.go(["/home","/chat","/vocabulary","/reading","/writing","/profile"][i]), destinations: [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: AppStrings.tabHome),
      NavigationDestination(icon: const Icon(Icons.chat_outlined), selectedIcon: const Icon(Icons.chat), label: AppStrings.tabChat),
      NavigationDestination(icon: const Icon(Icons.book_outlined), selectedIcon: const Icon(Icons.book), label: AppStrings.tabWords),
      NavigationDestination(icon: const Icon(Icons.article_outlined), selectedIcon: const Icon(Icons.article), label: AppStrings.tabRead),
      NavigationDestination(icon: const Icon(Icons.edit_outlined), selectedIcon: const Icon(Icons.edit), label: AppStrings.tabWrite),
      NavigationDestination(icon: const Icon(Icons.person_outlined), selectedIcon: const Icon(Icons.person), label: AppStrings.tabProfile),
    ]));
  }
}

class EnglishCoachApp extends StatefulWidget {
  const EnglishCoachApp({super.key});
  @override
  State<EnglishCoachApp> createState() => _EnglishCoachAppState();
}

class _EnglishCoachAppState extends State<EnglishCoachApp> {
  @override
  void initState() {
    super.initState();
    // 冷启动由通知点击拉起时，首帧后跳转到目标页面
    final launchRoute = NotificationService.instance.launchRoute;
    if (launchRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) appRouter.go(launchRoute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: tp.mode,
      routerConfig: appRouter,
      scaffoldMessengerKey: ApiService.messengerKey,
    );
  }
}
