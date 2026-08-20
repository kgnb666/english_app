import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "../l10n/zh_CN.dart";
import "../services/chat_service.dart";
import "../services/api_service.dart";
import "../config/theme.dart";
import "../widgets/empty_state_view.dart";

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
    try { _sessions = await _svc.getSessions(); } catch (e) { debugPrint("ChatList load error: $e"); _err = AppStrings.error; }
    setState(() => _loading = false);
  }
  Future<void> _create() async {
    try {
      final s = await _svc.createSession();
      if (mounted) context.push("/chat/detail", extra: {"sessionId": s.id, "title": s.title}).then((_) => _load());
    } catch (e) {
      debugPrint("ChatList create error: $e");
      ApiService.showError(AppStrings.createSessionFailed);
    }
  }
  Future<void> _del(String id) async {
    try { await _svc.deleteSession(id); _load(); }
    catch (e) {
      debugPrint("ChatList delete error: $e");
      ApiService.showError(AppStrings.deleteFailed);
    }
  }
  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDeleteHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return AppStrings.justNow;
    if (diff.inHours < 1) return "${diff.inMinutes}${AppStrings.minAgo}";
    if (diff.inDays < 1) return "${diff.inHours}${AppStrings.hourAgo}";
    return DateFormat("MM/dd").format(dt);
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.aiTeacher), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _err != null ? ErrorRetryView(message: _err!, onRetry: _load)
          : _sessions.isEmpty ? EmptyStateView(
              icon: Icons.chat_outlined,
              title: AppStrings.noConversations,
              subtitle: AppStrings.startChat,
              actionLabel: AppStrings.newChat,
              onAction: _create,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _sessions.length,
                itemBuilder: (_, i) {
                  final s = _sessions[i];
                  return Dismissible(
                    key: Key(s.id),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                    confirmDismiss: (_) => _confirmDelete(),
                    onDismissed: (_) => _del(s.id),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withAlpha(30), child: const Icon(Icons.chat, color: AppTheme.primaryColor, size: 20)),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text("${s.messageCount} ${AppStrings.messages}  ${_fmt(s.updatedAt)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push("/chat/detail", extra: {"sessionId": s.id, "title": s.title}).then((_) => _load()),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.newChat),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
