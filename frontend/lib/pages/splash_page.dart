import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
import "../l10n/zh_CN.dart";
import "../services/auth_provider.dart";

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override void initState() { super.initState(); _checkAuth(); }
  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.tryAutoLogin();
    if (!mounted) return;
    if (ok) {
      context.go("/home");
    } else {
      context.go("/login");
    }
  }
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.school, size: 72, color: t.colorScheme.primary),
      const SizedBox(height: 16),
      Text(AppStrings.appName, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: t.colorScheme.primary)),
      const SizedBox(height: 24),
      const CircularProgressIndicator(),
    ])));
  }
}
