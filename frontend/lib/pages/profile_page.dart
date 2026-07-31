import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:go_router/go_router.dart";
import "../services/auth_provider.dart";
import "../config/theme.dart";

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext ctx) {
    final a = ctx.watch<AuthProvider>(), t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: AppTheme.primaryColor, child: Text((a.username??"U")[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white))),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.username??"User", style: t.textTheme.titleMedium), const SizedBox(height: 4), Text("Beginner Level", style: TextStyle(color: Colors.grey.shade600))]),
        ]))),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.settings), title: const Text("Learning Goals"), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.dark_mode), title: const Text("Dark Mode"), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.info_outline), title: const Text("About"), trailing: const Icon(Icons.chevron_right), onTap: () {}),
        ])),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: () async { await a.logout(); if (ctx.mounted) ctx.go("/login"); },
          style: OutlinedButton.styleFrom(foregroundColor: t.colorScheme.error, minimumSize: const Size(double.infinity, 48), side: BorderSide(color: t.colorScheme.error)),
          child: const Text("Logout")),
      ]),
    );
  }
}
