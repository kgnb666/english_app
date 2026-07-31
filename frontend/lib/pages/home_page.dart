import "package:flutter/material.dart";
import "../config/theme.dart";

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext ctx) {
    final t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: const Text("English Coach"), actions: [IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {})]),
      body: ListView(padding: const EdgeInsets.all(16), children: [_today(t), const SizedBox(height: 16), _stats(t), const SizedBox(height: 16), _tasks(t)]),
    );
  }

  Widget _today(ThemeData t) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.whatshot, color: Colors.orange.shade400), const SizedBox(width: 8), Text("Today's Progress", style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
    const SizedBox(height: 20),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 0.35, minHeight: 8, backgroundColor: t.colorScheme.surfaceContainerHighest)),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _si(Icons.mic, "15 min", "Speaking"), _si(Icons.book, "12/30", "Words"), _si(Icons.article, "0/1", "Reading"),
    ]),
  ])));

  Widget _si(IconData i, String v, String l) => Column(children: [Icon(i, size: 24, color: AppTheme.primaryColor), const SizedBox(height: 4), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(l, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]);

  Widget _stats(ThemeData t) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text("Learning Stats", style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _bs(0x1F525, 7, "Day Streak"), _bs(0x1F4DA, 45, "Words Mastered"), _bs(0x23F0, 128, "Total Min"),
    ]),
  ])));

  Widget _bs(int e, int v, String l) => Column(children: [Text(String.fromCharCode(e), style: const TextStyle(fontSize: 28)), const SizedBox(height: 4), Text("$v", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]);

  Widget _tasks(ThemeData t) {
    final tasks = [
      {"icon": Icons.mic, "title": "AI Speaking Practice", "sub": "20 minutes conversation", "done": false},
      {"icon": Icons.book, "title": "Learn 30 Words", "sub": "Daily vocabulary goal", "done": false},
      {"icon": Icons.article, "title": "Read 1 Article", "sub": "With AI analysis", "done": false},
      {"icon": Icons.edit, "title": "Review Words", "sub": "Spaced repetition", "done": true},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Today's Tasks", style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...tasks.map((tk) => Card(child: ListTile(
        leading: Icon(tk["icon"] as IconData, color: AppTheme.primaryColor),
        title: Text(tk["title"] as String), subtitle: Text(tk["sub"] as String),
        trailing: Icon((tk["done"] as bool) ? Icons.check_circle : Icons.circle_outlined, color: (tk["done"] as bool) ? Colors.green : Colors.grey)))),
    ]);
  }
}
