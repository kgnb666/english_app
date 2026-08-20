import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../widgets/common_loading_button.dart";
import "package:provider/provider.dart";
import "../l10n/zh_CN.dart";
import "../services/auth_provider.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _u = TextEditingController(), _p = TextEditingController();
  bool _ob = true;
  @override void dispose() { _u.dispose(); _p.dispose(); super.dispose(); }

  Future<void> _login() async {
    final a = context.read<AuthProvider>();
    if (await a.login(_u.text.trim(), _p.text) && mounted) context.go("/home");
  }

  @override
  Widget build(BuildContext ctx) {
    final a = ctx.watch<AuthProvider>(), t = Theme.of(ctx);
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.school, size: 64, color: t.colorScheme.primary), const SizedBox(height: 16),
        Text(AppStrings.appName, textAlign: TextAlign.center, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: t.colorScheme.primary)),
        const SizedBox(height: 8),
        Text(AppStrings.appSubtitle, textAlign: TextAlign.center, style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurface.withAlpha(150))),
        const SizedBox(height: 48),
        TextField(controller: _u, decoration: InputDecoration(labelText: AppStrings.username, prefixIcon: const Icon(Icons.person_outline)), textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        TextField(controller: _p, obscureText: _ob, decoration: InputDecoration(labelText: AppStrings.password, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_ob?Icons.visibility_off:Icons.visibility), onPressed: ()=>setState(()=>_ob=!_ob))), onSubmitted: (_)=>_login()),
        if (a.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(a.errorMessage!, style: TextStyle(color: t.colorScheme.error, fontSize: 13), textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        CommonLoadingButton(
          label: AppStrings.login,
          loadingLabel: AppStrings.loggingIn,
          icon: Icons.login,
          loading: a.isLoading,
          onPressed: _login,
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: ()=>ctx.go("/register"), child: Text(AppStrings.noAccount)),
      ])))),
    );
  }
}
