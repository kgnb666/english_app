import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:provider/provider.dart";
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
    if (_p.text != _c.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match"))); return; }
    final a = context.read<AuthProvider>();
    if (await a.register(_u.text.trim(), _e.text.trim(), _p.text) && mounted) context.go("/home");
  }

  @override
  Widget build(BuildContext ctx) {
    final a = ctx.watch<AuthProvider>(), t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account")),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 32), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _u, decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person_outline)), textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        TextField(controller: _e, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        TextField(controller: _p, obscureText: _ob, decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline), helperText: "At least 6 characters", suffixIcon: IconButton(icon: Icon(_ob ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ob = !_ob)))),
        const SizedBox(height: 16),
        TextField(controller: _c, obscureText: true, decoration: const InputDecoration(labelText: "Confirm Password", prefixIcon: Icon(Icons.lock_outline)), onSubmitted: (_) => _reg()),
        if (a.errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(a.errorMessage!, style: TextStyle(color: t.colorScheme.error, fontSize: 13), textAlign: TextAlign.center)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: a.isLoading ? null : _reg, child: a.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Register", style: TextStyle(fontSize: 16))),
        const SizedBox(height: 16),
        TextButton(onPressed: () => ctx.go("/login"), child: const Text("Already have an account? Login")),
      ])))),
    );
  }
}
