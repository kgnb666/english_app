import "package:flutter/material.dart";
import "../services/chat_service.dart";
import "../config/theme.dart";

class ChatPage extends StatefulWidget {
  final String sessionId, sessionTitle;
  const ChatPage({super.key, required this.sessionId, required this.sessionTitle});
  @override State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _svc = ChatService(), _tc = TextEditingController(), _sc = ScrollController();
  final _msgs = <ChatMessageModel>[];
  bool _loading = false, _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _tc.dispose(); _sc.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try { _msgs.addAll(await _svc.getMessages(widget.sessionId)); } catch (_) {}
    setState(() => _loading = false);
    _scroll();
  }

  Future<void> _send() async {
    final txt = _tc.text.trim(); if (txt.isEmpty || _sending) return;
    _tc.clear(); setState(() => _sending = true);
    _msgs.add(ChatMessageModel.fromJson({"id":"temp","session_id":widget.sessionId,"role":"user","content":txt,"created_at":DateTime.now().toIso8601String()}));
    _scroll();
    try {
      final reply = await _svc.sendMessage(widget.sessionId, txt);
      setState(() { _msgs.removeLast(); _msgs.add(reply); });
    } catch (_) {
      setState(() { _msgs.removeLast(); _msgs.add(ChatMessageModel.fromJson({"id":"err","session_id":widget.sessionId,"role":"assistant","content":"Sorry, something went wrong.","created_at":DateTime.now().toIso8601String()})); });
    }
    setState(() => _sending = false); _scroll();
  }

  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) { if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); });

  @override
  Widget build(BuildContext ctx) {
    final t = Theme.of(ctx);
    return Scaffold(
      appBar: AppBar(title: Text(widget.sessionTitle, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _msgs.isEmpty ? _empty(t)
            : ListView.builder(controller: _sc, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: _msgs.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) => i == _msgs.length ? _typing(t) : _bubble(_msgs[i], t))),
        _input(t),
      ]),
    );
  }

  Widget _empty(ThemeData t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.chat_bubble_outline, size: 64, color: t.colorScheme.onSurface.withAlpha(80)),
    const SizedBox(height: 16), Text("Start a conversation", style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onSurface.withAlpha(150))),
    const SizedBox(height: 8), Text("Your AI English teacher is ready.", style: TextStyle(color: t.colorScheme.onSurface.withAlpha(100)))],));

  Widget _typing(ThemeData t) => Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(top: 8, bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest, borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [for (int i=0;i<3;i++) ...[_dot(t), if(i<2) const SizedBox(width: 4)]],)));

  Widget _dot(ThemeData t) => TweenAnimationBuilder<double>(tween: Tween(begin: 0.3, end: 1.0), duration: const Duration(milliseconds: 600), builder: (_, v, __) => Transform.scale(scale: v, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.colorScheme.primary.withAlpha(120), shape: BoxShape.circle))));

  Widget _bubble(ChatMessageModel m, ThemeData t) {
    final isU = m.role == "user", corr = m.grammarCorrections;
    return Align(alignment: isU ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width*0.78), margin: const EdgeInsets.only(top: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: isU ? AppTheme.primaryColor : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: isU ? const Radius.circular(16) : const Radius.circular(2), bottomRight: isU ? const Radius.circular(2) : const Radius.circular(16))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.content, style: TextStyle(color: isU ? Colors.white : t.colorScheme.onSurface, fontSize: 15, height: 1.4)),
          if (!isU && corr != null) ...[const SizedBox(height: 8), _correctionCard(corr, t)],
        ])));
  }

  Widget _correctionCard(Map<String,dynamic> c, ThemeData t) => Container(padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withAlpha(60))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.auto_fix_high, size: 14, color: Colors.orange.shade700), const SizedBox(width: 6), Text("Correction", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700))]),
      const SizedBox(height: 4),
      RichText(text: TextSpan(style: TextStyle(fontSize: 13, color: t.colorScheme.onSurface), children: [
        TextSpan(text: c["original"]??"", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red)),
        const TextSpan(text: " -> "),
        TextSpan(text: c["corrected"]??"", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
      ])),
      if ((c["explanation"]??"").toString().isNotEmpty) ...[const SizedBox(height: 4), Text(c["explanation"], style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface.withAlpha(160)))],
    ]));

  Widget _input(ThemeData t) => Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: BoxDecoration(color: t.scaffoldBackgroundColor, border: Border(top: BorderSide(color: t.dividerColor.withAlpha(80)))),
    child: SafeArea(child: Row(children: [
      Expanded(child: TextField(controller: _tc, decoration: InputDecoration(hintText: "Type a message...", filled: true, fillColor: t.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), isDense: true), textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), maxLines: 4, minLines: 1)),
      const SizedBox(width: 8),
      _sending ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)) : IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded, size: 20), style: IconButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white)),
    ])),
  );
}
