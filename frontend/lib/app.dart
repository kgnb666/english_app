import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "pages/home_page.dart";
import "pages/chat_page.dart";
import "pages/chat_list_page.dart";
import "pages/vocabulary_page.dart";
import "pages/reading_page.dart";
import "pages/profile_page.dart";
import "pages/login_page.dart";
import "pages/register_page.dart";
import "config/theme.dart";

final _router = GoRouter(
  initialLocation: "/login",
  routes: [
    GoRoute(path: "/login", builder: (_, __) => const LoginPage()),
    GoRoute(path: "/register", builder: (_, __) => const RegisterPage()),
    GoRoute(path: "/chat/detail", builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>;
      return ChatPage(sessionId: extra["sessionId"] as String, sessionTitle: extra["title"] as String);
    }),
    ShellRoute(builder: (_, __, child) => MainShell(child: child), routes: [
      GoRoute(path: "/home", builder: (_, __) => const HomePage()),
      GoRoute(path: "/chat", builder: (_, __) => const ChatListPage()),
      GoRoute(path: "/vocabulary", builder: (_, __) => const VocabularyPage()),
      GoRoute(path: "/reading", builder: (_, __) => const ReadingPage()),
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
    if (loc.startsWith("/profile")) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(["/home","/chat","/vocabulary","/reading","/profile"][i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.chat_outlined), selectedIcon: Icon(Icons.chat), label: "AI Teacher"),
          NavigationDestination(icon: Icon(Icons.book_outlined), selectedIcon: Icon(Icons.book), label: "Words"),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: "Reading"),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class EnglishCoachApp extends StatelessWidget {
  const EnglishCoachApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: "English Coach",
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.system,
    routerConfig: _router,
  );
}
