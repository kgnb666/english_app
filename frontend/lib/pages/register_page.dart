import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../widgets/common_loading_button.dart";
import "package:provider/provider.dart";
import "../l10n/zh_CN.dart";
import "../services/auth_provider.dart";

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _u = TextEditingController(), _e = TextEditingController(), _p = TextEditingController(), _c = TextEditingController();
  bool _ob = true;
  @override void dispose() { _u.dispose(); _e.dispose(); _p.dispose(); _c.dispose(); super.dispose(); }

  Future<void> _reg() async {
    if (_p.text != _c.text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.passwordsMismatch))); return; }
    final a = context.read<AuthProvider>();
    if (await a.register(_u.text.trim(), _e.text.trim(), _p.text) && mounted) context.go("/home");
  }

  @override
  Widget build(BuildContext ctx) {
    final a = ctx.watch<AuthProvider>(), t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.createAccount)),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _u, decoration: InputDecoration(labelText: AppStrings.username, prefixIcon: const Icon(Icons.person_outline)), textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        TextField(controller: _e, decoration: InputDecoration(labelText: AppStrings.email, prefixIcon: const Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        TextField(controller: _p, obscureText: _ob, decoration: InputDecoration(labelText: AppStrings.password, prefixIcon: const Icon(Icons.lock_outline), helperText: AppStrings.passwordHint, suffixIcon: IconButton(icon: Icon(_ob?Icons.visibility_off:Icons.visibility), onPressed: ()=>setState(()=>_ob=!_ob)))),
        const SizedBox(height: 16),
        TextField(controller: _c, obscureText: true, decoration: InputDecoration(labelText: AppStrings.confirmPassword, prefixIcon: const Icon(Icons.lock_outline)), onSubmitted: (_)=>_reg()),
        if (a.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(a.errorMessage!, style: TextStyle(color: t.colorScheme.error, fontSize: 13), textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        CommonLoadingButton(
          label: AppStrings.register,
          loadingLabel: AppStrings.registering,
          icon: Icons.person_add,
          loading: a.isLoading,
          onPressed: _reg,
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: ()=>ctx.go("/login"), child: Text(AppStrings.hasAccount)),
      ])))),
    );
  }
}
