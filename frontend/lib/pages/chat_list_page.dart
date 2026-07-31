import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "../services/chat_service.dart";
import "../config/theme.dart";

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _svc = ChatService();
  List<ChatSessionModel> _sessions = [];
  bool _loading = true;
  String? _err;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _err = null; });
    try { _sessions = await _svc.getSessions(); } catch (_) { _err = "Failed to load"; }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final s = await _svc.createSession();
      if (mounted) context.push("/chat/detail", extra: {"sessionId": s.id, "title": s.title}).then((_) => _load());
    } catch (_) {}
  }

  Future<void> _del(String id) async {
    try { await _svc.deleteSession(id); _load(); } catch (_) {}
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return DateFormat("MM/dd").format(dt);
  }

  @override
  Widget build(BuildContext ctx) {
    final t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: const Text("AI Teacher"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _err != null ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey), const SizedBox(height: 16),
            Text(_err!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text("Retry"))]))
          : _sessions.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_outlined, size: 64, color: t.colorScheme.onSurface.withAlpha(80)),
            const SizedBox(height: 16),
            Text("No conversations yet", style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 8), Text("Start a new chat with your AI English teacher.", style: TextStyle(color: t.colorScheme.onSurface.withAlpha(100)))],))
          : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.symmetric(vertical: 8), itemCount: _sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (_, i) {
              final s = _sessions[i];
              return Dismissible(key: Key(s.id), direction: DismissDirection.endToStart,
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) => _del(s.id),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withAlpha(30), child: const Icon(Icons.chat, color: AppTheme.primaryColor, size: 20)),
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("${s.messageCount} messages  ${_fmt(s.updatedAt)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ctx.push("/chat/detail", extra: {"sessionId": s.id, "title": s.title}).then((_) => _load()),
                ),
              );
            })),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text("New Chat"), backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
    );
  }
}
