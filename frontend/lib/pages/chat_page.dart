import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "../l10n/zh_CN.dart";
import "../services/chat_service.dart";
import "../services/study_session_service.dart";
import "../services/vocab_service.dart";
import "../services/tts_service.dart";
import "../services/speech_service.dart";
import "../services/api_service.dart";
import "../config/theme.dart";

class ChatPage extends StatefulWidget {
  final String sessionId, sessionTitle;
  const ChatPage({super.key, required this.sessionId, required this.sessionTitle});
  @override State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _svc = ChatService(), _tc = TextEditingController(), _sc = ScrollController();
  final _msgs = <ChatMessageModel>[];
  final _speaking = <String>{};
  final _failedTexts = <String, String>{};
  final _rendered = <String, String>{};
  final _expanded = <String>{};
  final _revealTimers = <String, Timer>{};
  bool _loading = false, _sending = false, _listening = false;
  double _level = 0;
  int _seconds = 0;
  Timer? _recordTimer;
  List<String> _topics = [];
  bool _topicsLoading = true;

  @override void initState() { super.initState(); StudySessionService.instance.start("chat"); _load(); _loadTopics(); TtsService.instance.setRate(0.5); SpeechService.instance.init(); }
  @override void dispose() {
    _recordTimer?.cancel();
    SpeechService.instance.stop();
    for (final t in _revealTimers.values) {
      t.cancel();
    }
    StudySessionService.instance.end("chat"); _tc.dispose(); _sc.dispose(); TtsService.instance.stop(); super.dispose();
  }

  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      final loaded = await _svc.getMessages(widget.sessionId);
      final existing = _msgs.map((m) => m.id).toSet();
      _msgs.addAll(loaded.where((m) => !existing.contains(m.id)));
    }
    catch (e) { debugPrint("ChatPage load error: $e"); }
    setState(()=>_loading=false); _scroll();
  }

  /// 请求动态主题（按用户等级）；失败时保留空列表并允许重试
  Future<void> _loadTopics() async {
    setState(()=>_topicsLoading=true);
    try { final topics = await _svc.getTopics(); if (!mounted) return; setState(()=>_topics = topics); }
    catch (e) { debugPrint("ChatPage topics error: $e"); }
    if (mounted) setState(()=>_topicsLoading=false);
  }

  Future<void> _send() => _sendText(_tc.text);

  Future<void> _sendText(String raw) async {
    final txt = raw.trim();
    if (txt.isEmpty || _sending) return;
    _tc.clear();
    setState(()=>_sending=true);
    final tempId = "temp_${DateTime.now().microsecondsSinceEpoch}";
    _msgs.add(ChatMessageModel.fromJson({"id": tempId, "session_id": widget.sessionId, "role": "user", "content": txt, "created_at": DateTime.now().toIso8601String()}));
    _scroll();
    try {
      final reply = await _streamOrSend(widget.sessionId, txt, tempId);
      if (!mounted) return;
      setState(() {
        _rendered.remove(tempId);
        final idx = _msgs.indexWhere((m) => m.id == tempId);
        if (idx >= 0) { _msgs[idx] = reply; } else { _msgs.add(reply); }
      });
      // 预合成 AI 回复，点击喇叭时秒播
      if (reply.role == "assistant" && reply.content.isNotEmpty) {
        TtsService.instance.preload(reply.content);
      }
    } on DioException catch (e) {
      debugPrint("ChatPage send dio error: ${e.response?.statusCode} ${e.message}");
      if (!mounted) return;
      final retryable = e.response?.statusCode == 503;
      _replaceWithError(tempId, txt, retryable ? AppStrings.aiUnavailable : AppStrings.sendFailed, retryable);
    } catch (e) {
      debugPrint("ChatPage send error: $e");
      if (!mounted) return;
      _replaceWithError(tempId, txt, AppStrings.sendFailed, false);
    }
    setState(()=>_sending=false); _scroll();
  }

  /// 流式发送：SSE 逐字渲染；流式不可用时回退普通发送
  Future<ChatMessageModel> _streamOrSend(String sessionId, String text, String tempId) async {
    try {
      ChatMessageModel? done;
      await for (final line in _svc.streamMessage(sessionId, text)) {
        if (line.isEmpty) continue;
        final ev = jsonDecode(line) as Map<String, dynamic>;
        switch (ev["type"]) {
          case "chunk":
            final acc = _rendered[tempId] ?? "";
            if (mounted) setState(() => _rendered[tempId] = acc + (ev["text"] as String));
            _scroll();
            break;
          case "done":
            done = ChatMessageModel.fromJson(ev["data"] as Map<String, dynamic>);
            break;
          case "error":
            throw DioException(
              requestOptions: RequestOptions(path: ""),
              type: DioExceptionType.unknown,
              error: ev["message"] ?? "stream error",
            );
        }
        if (done != null) break;
      }
      if (done != null) return done;
      throw DioException(
        requestOptions: RequestOptions(path: ""),
        type: DioExceptionType.unknown,
        error: "stream ended without done",
      );
    } catch (e) {
      debugPrint("Chat stream failed, fallback to normal send: $e");
      return await _svc.sendMessage(sessionId, text);
    }
  }

  Future<void> _showSummary() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SummarySheet(sessionId: widget.sessionId),
    );
  }

  /// 用错误消息替换临时消息；可重试的错误记录原文，供点击重试
  void _replaceWithError(String tempId, String original, String message, bool retryable) {
    final errId = "err_${DateTime.now().microsecondsSinceEpoch}";
    setState(() {
      final idx = _msgs.indexWhere((m) => m.id == tempId);
      final err = ChatMessageModel.fromJson({
        "id": errId,
        "session_id": widget.sessionId,
        "role": "assistant",
        "content": message,
        "created_at": DateTime.now().toIso8601String(),
      });
      if (idx >= 0) { _msgs[idx] = err; } else { _msgs.add(err); }
      if (retryable) _failedTexts[errId] = original;
    });
  }

  void _retry(String errId) {
    final text = _failedTexts.remove(errId);
    if (text == null) return;
    setState(() => _msgs.removeWhere((m) => m.id == errId));
    _sendText(text);
  }

  String _displayText(ChatMessageModel m) {
    final revealing = _rendered.containsKey(m.id);
    final base = revealing ? _rendered[m.id]! : m.content;
    final collapsed = !revealing && base.length > 350 && !_expanded.contains(m.id);
    return collapsed ? "${base.substring(0, 350)}…" : base;
  }

  Future<void> _startListening() async {
    final speech = SpeechService.instance;
    if (!speech.isReady) {
      final ok = await speech.init();
      if (!ok) {
        _showPermissionGuide();
        return;
      }
    }
    _seconds = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds += 1);
    });
    setState(() => _listening = true);
    final ok = await speech.listen(
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      onResult: (text, isFinal, _) {
        if (isFinal) {
          _recordTimer?.cancel();
          if (mounted) {
            setState(() {
              _listening = false;
              _level = 0;
            });
          }
          final t = text.trim();
          if (t.isEmpty) {
            ApiService.showError(AppStrings.speechNoResult);
          } else {
            // 识别结果填入输入框，用户确认后手动发送
            _tc.text = t;
            _tc.selection = TextSelection.collapsed(offset: t.length);
          }
        } else {
          _tc.text = text;
        }
      },
    );
    if (!ok) {
      _recordTimer?.cancel();
      if (mounted) {
        setState(() {
          _listening = false;
          _level = 0;
        });
      }
      if (speech.lastError == "permission") {
        _showPermissionGuide();
      } else {
        ApiService.showError(AppStrings.speechFailed);
      }
    }
  }

  Future<void> _stopListening() async {
    _recordTimer?.cancel();
    final fallback = SpeechService.instance.isRecordingFallback;
    await SpeechService.instance.stop();
    if (mounted) {
      setState(() {
        _listening = false;
        _level = 0;
      });
    }
    // 降级录音模式下，转写结果异步回调，不在此处误判为空
    if (!fallback && _tc.text.trim().isEmpty) {
      ApiService.showError(AppStrings.speechNoResult);
    }
  }

  void _showPermissionGuide() {
    ApiService.showError(AppStrings.enableMicrophonePermission);
  }

  Future<void> _speak(String text) async {
    setState(() => _speaking.add(text));
    final ok = await TtsService.instance.speak(text);
    if (mounted) setState(() => _speaking.remove(text));
    if (!ok) {
      debugPrint("ChatPage TTS failed: ${TtsService.instance.lastError}");
    }
  }
  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) { if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); });

  void _showBookmarkDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.bookmarkWord),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: AppStrings.bookmarkWordHint,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submitBookmark(ctx, ctrl),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          TextButton(onPressed: () => _submitBookmark(ctx, ctrl), child: const Text(AppStrings.save)),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  Future<void> _submitBookmark(BuildContext dialogCtx, TextEditingController ctrl) async {
    final word = ctrl.text.trim();
    if (word.isEmpty) return;
    Navigator.pop(dialogCtx);
    try {
      await VocabService().addBookmark(word: word, source: "chat");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.addedToWordBook),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("ChatPage bookmark error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.addToWordBookFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sessionTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: AppStrings.sessionSummary,
            onPressed: _showSummary,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: AppStrings.bookmarkWord,
            onPressed: _showBookmarkDialog,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _msgs.isEmpty ? _empty(t) : ListView.builder(controller:_sc,padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),itemCount:_msgs.length+(_sending?1:0),itemBuilder:(_,i)=>i==_msgs.length?_typing(t):_bubble(_msgs[i],t))),
        _input(t),
      ]),
    );
  }

  Widget _empty(ThemeData t) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.chat_bubble_outline, size: 48, color: t.colorScheme.onSurface.withAlpha(80)), const SizedBox(height: 16),
      Text(AppStrings.startConversation, style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onSurface.withAlpha(150))),
      const SizedBox(height: 16),
      if (_topicsLoading)
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(AppStrings.loadingTopics, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ]))
      else if (_topics.isEmpty)
        TextButton.icon(onPressed: _loadTopics, icon: const Icon(Icons.refresh, size: 18), label: Text(AppStrings.retry))
      else
        ..._topics.map((topic) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        child: SizedBox(width: double.infinity, child: OutlinedButton(
          onPressed: () { _tc.text = topic; _send(); },
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          child: Text(topic, style: TextStyle(color: t.colorScheme.onSurface.withAlpha(200), fontSize: 13)),
        )),
      )),
    ]));
  }

  Widget _typing(ThemeData t) => Align(alignment:Alignment.centerLeft,child:Container(margin:const EdgeInsets.only(top:8,bottom:4),padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),decoration:BoxDecoration(color:t.colorScheme.surfaceContainerHighest,borderRadius:const BorderRadius.only(topLeft:Radius.circular(2),topRight:Radius.circular(16),bottomLeft:Radius.circular(16),bottomRight:Radius.circular(16))),child:Row(mainAxisSize:MainAxisSize.min,children:[for(int i=0;i<3;i++)...[_dot(t),if(i<2)const SizedBox(width:4)]])));
  Widget _dot(ThemeData t) => TweenAnimationBuilder<double>(tween:Tween(begin:0.3,end:1.0),duration:const Duration(milliseconds:600),builder:(_,v,__)=>Transform.scale(scale:v,child:Container(width:8,height:8,decoration:BoxDecoration(color:t.colorScheme.primary.withAlpha(120),shape:BoxShape.circle))));

  Widget _bubble(ChatMessageModel m, ThemeData t) {
    final isU = m.role == "user", corr = m.grammarCorrections;
    final isErr = !isU && m.id.startsWith("err_");
    final display = _displayText(m);
    final showExpand = !isU && m.content.length > 350;
    return Align(alignment:isU?Alignment.centerRight:Alignment.centerLeft,
      child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*0.78),margin:const EdgeInsets.only(top:6,bottom:4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
        decoration:BoxDecoration(color:isU?AppTheme.primaryColor:t.colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.only(topLeft:const Radius.circular(16),topRight:const Radius.circular(16),bottomLeft:isU?const Radius.circular(16):const Radius.circular(2),bottomRight:isU?const Radius.circular(2):const Radius.circular(16))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(display,style:TextStyle(color:isU?Colors.white:t.colorScheme.onSurface,fontSize:15,height:1.4)),
          if(showExpand) Align(alignment:Alignment.centerLeft,child:GestureDetector(
            onTap:()=>setState((){if(_expanded.contains(m.id)){_expanded.remove(m.id);}else{_expanded.add(m.id);}}),
            child: Padding(padding:const EdgeInsets.only(top:4),child:Text(
              _expanded.contains(m.id)?AppStrings.collapse:AppStrings.expand,
              style:TextStyle(fontSize:12,color:AppTheme.primaryColor,fontWeight:FontWeight.w600),
            )),
          )),
          if(!isU&&corr!=null)...[const SizedBox(height:8),_correctionCard(corr,t)],
          if(isErr)...[
            const SizedBox(height:6),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: () => _retry(m.id),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text(AppStrings.retry),
              style: TextButton.styleFrom(
                foregroundColor: t.colorScheme.error,
                visualDensity: VisualDensity.compact,
              ),
            )),
          ],
          if(!isU)...[const SizedBox(height:4),Align(alignment:Alignment.centerRight,child:InkWell(onTap:()=>_speak(m.content),child:_speaking.contains(m.content)?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(Icons.volume_up,size:18,color:AppTheme.primaryColor.withAlpha(180))))],
        ])));
  }

  /// 兼容两种纠错结构：
  /// 新：{"corrections": [{"wrong","correct","reason","better_expression","error_type_cn"}, ...]}
  /// 旧：{"original","corrected","explanation"}
  Widget _correctionCard(Map<String, dynamic> c, ThemeData t) {
    final list = <Map<String, dynamic>>[];
    if (c["corrections"] is List) {
      list.addAll((c["corrections"] as List).cast<Map<String, dynamic>>());
    } else if ((c["wrong"] ?? c["original"]) != null) {
      list.add(c);
    }
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_fix_high, size: 14, color: Colors.orange.shade700),
            const SizedBox(width: 6),
            Text(
              AppStrings.correction,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
            ),
          ]),
          for (final item in list) _correctionItem(item, t),
        ],
      ),
    );
  }

  Widget _correctionItem(Map<String, dynamic> item, ThemeData t) {
    final wrong = item["wrong"] ?? item["original"] ?? "";
    final correct = item["correct"] ?? item["corrected"] ?? "";
    final reason = item["reason"] ?? item["explanation"] ?? "";
    final better = item["better_expression"] ?? "";
    final typeCn = item["error_type_cn"];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: t.colorScheme.onSurface),
              children: [
                TextSpan(
                  text: wrong.toString(),
                  style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red),
                ),
                const TextSpan(text: " -> "),
                TextSpan(
                  text: correct.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                ),
              ],
            ),
          ),
          if (typeCn != null && typeCn.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                typeCn.toString(),
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              ),
            ),
          if (reason.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                reason.toString(),
                style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface.withAlpha(160)),
              ),
            ),
          if (better.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "${AppStrings.moreNatural}: $better",
                style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _input(ThemeData t) => Container(padding:const EdgeInsets.fromLTRB(12,8,12,12),decoration:BoxDecoration(color:t.scaffoldBackgroundColor,border:Border(top:BorderSide(color:t.dividerColor.withAlpha(80)))),child:SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
    if (_listening)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(Icons.graphic_eq, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 6),
          Text(
            "${AppStrings.listening} ${_fmtDuration(_seconds)}",
            style: TextStyle(fontSize: 12, color: Colors.red.shade400),
          ),
        ]),
      ),
    Row(children:[
      IconButton(
        onPressed: _listening ? _stopListening : _startListening,
        icon: _listening
            ? Transform.scale(
                scale: 1.0 + (_level.clamp(0, 1) * 0.35),
                child: const Icon(Icons.mic, color: Colors.red, size: 26),
              )
            : const Icon(Icons.mic_none, color: AppTheme.primaryColor, size: 24),
        style: _listening ? IconButton.styleFrom(backgroundColor: Colors.red.withAlpha(25)) : null,
        tooltip: _listening ? AppStrings.stopListening : AppStrings.startListening,
      ),
      Expanded(child:TextField(controller:_tc,decoration:InputDecoration(hintText:_listening?AppStrings.listening:AppStrings.typeOrSpeak,filled:true,fillColor:t.colorScheme.surfaceContainerHighest,border:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:12),isDense:true),textInputAction:TextInputAction.send,onSubmitted:(_)=>_send(),maxLines:4,minLines:1)),
      const SizedBox(width:8),
      _sending?const SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2.5)):IconButton.filled(onPressed:_send,icon:const Icon(Icons.send_rounded,size:20),style:IconButton.styleFrom(backgroundColor:AppTheme.primaryColor,foregroundColor:Colors.white)),
    ]),
  ])));

  String _fmtDuration(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, "0");
    final s = (sec % 60).toString().padLeft(2, "0");
    return "$m:$s";
  }
}

/// 会话总结底部弹窗
class _SummarySheet extends StatefulWidget {
  final String sessionId;
  const _SummarySheet({required this.sessionId});

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  final _svc = ChatService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getSummary(widget.sessionId);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      debugPrint("Summary load error: $e");
      if (!mounted) return;
      setState(() => _error = AppStrings.summaryFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(AppStrings.summaryLoading),
                ]),
              ),
            )
          : _error != null
              ? SizedBox(
                  height: 140,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text(AppStrings.retry)),
                    ]),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.summarize, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(AppStrings.sessionSummary,
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 14),
                    if ((_data?["summary_cn"] as String? ?? "").isNotEmpty) ...[
                      Text(_data!["summary_cn"] as String,
                          style: const TextStyle(fontSize: 14, height: 1.5)),
                      const SizedBox(height: 14),
                    ],
                    if ((_data?["key_points"] as List? ?? []).isNotEmpty) ...[
                      Text(AppStrings.summaryKeyPoints,
                          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      for (final p in _data!["key_points"] as List)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text("•  ", style: TextStyle(fontSize: 13)),
                            Expanded(
                                child: Text("$p", style: const TextStyle(fontSize: 13, height: 1.4))),
                          ]),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if ((_data?["to_improve"] as List? ?? []).isNotEmpty) ...[
                      Text(AppStrings.summaryToImprove,
                          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      for (final p in _data!["to_improve"] as List)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text("•  ", style: TextStyle(fontSize: 13)),
                            Expanded(
                                child: Text("$p", style: const TextStyle(fontSize: 13, height: 1.4))),
                          ]),
                        ),
                    ],
                  ],
                ),
    );
  }
}
