import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "../l10n/zh_CN.dart";
import "../services/vocab_service.dart";
import "../services/tts_service.dart";
import "../services/api_service.dart";
import "../widgets/ai_content_renderer.dart";
import "../config/theme.dart";

class WordDetailPage extends StatefulWidget {
  final String wordId;
  const WordDetailPage({super.key, required this.wordId});
  @override State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  final _svc = VocabService();
  VocabWordModel? _word;
  List<Map<String, dynamic>> _examples = [];
  bool _loading = true, _acting = false, _aidLoading = false;
  bool _aidSlow = false;
  Timer? _aidTimer;
  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _aidTimer?.cancel(); super.dispose(); }
  Future<void> _load() async {
    setState(()=>_loading=true);
    try {
      _word = await _svc.getWordDetail(widget.wordId);
      _prepareAudio();
      _examples = await _svc.getWordExamples(widget.wordId);
    } catch (e) { debugPrint("WordDetail load error: $e"); }
    setState(()=>_loading=false);
  }
  /// 有固定音频则预加载；没有则后台生成绑定
  Future<void> _prepareAudio() async {
    final w = _word;
    if (w == null) return;
    if (w.audioUrl != null && w.audioUrl!.isNotEmpty) {
      TtsService.instance.preloadWord(w.word, w.audioUrl);
    } else {
      try {
        await _svc.ensureAudio(widget.wordId);
        if (!mounted) return;
        final fresh = await _svc.getWordDetail(widget.wordId);
        if (!mounted) return;
        // 用户正在操作或 _word 已被更新时不覆盖，避免竞态
        if (!_acting && !_aidLoading && _word?.id == w.id) {
          setState(() => _word = fresh);
        }
        final url = fresh.audioUrl;
        if (url != null && url.isNotEmpty) {
          TtsService.instance.preloadWord(fresh.word, url);
        }
      } catch (e) {
        debugPrint("WordDetail ensureAudio error: $e");
      }
    }
  }
  Future<void> _startLearning() async {
    setState(()=>_acting=true);
    try {
      _word = await _svc.startLearning(widget.wordId);
      if (mounted) ApiService.showSuccess(AppStrings.learningStarted);
    } catch (e) {
      debugPrint("WordDetail start error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(()=>_acting=false);
    }
  }
  Future<void> _review(bool correct) async {
    setState(()=>_acting=true);
    try {
      _word = await _svc.reviewWord(widget.wordId, correct);
      if (mounted) ApiService.showSuccess(AppStrings.reviewRecorded);
    } catch (e) {
      debugPrint("WordDetail review error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(()=>_acting=false);
    }
  }
  Future<void> _speak() async {
    if (_word == null) return;
    final ok = await TtsService.instance.speakWord(_word!.word, _word!.audioUrl);
    if (!ok) debugPrint("WordDetail TTS failed: ${TtsService.instance.lastError}");
  }
  Future<void> _genAid() async {
    setState(() { _aidLoading = true; _aidSlow = false; });
    _aidTimer?.cancel();
    _aidTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _aidSlow = true);
    });
    try {
      _word = await _svc.generateMemoryAid(widget.wordId);
      if (mounted) ApiService.showSuccess(AppStrings.memoryAidGenerated);
    } catch (e) {
      debugPrint("WordDetail memory aid error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      _aidTimer?.cancel();
      if (mounted) setState(() { _aidLoading = false; _aidSlow = false; });
    }
  }
  Future<void> _toggleBookmark() async {
    final w = _word;
    if (w == null) return;
    setState(()=>_acting=true);
    try {
      if (w.progress?["is_bookmarked"] == true) {
        await _svc.removeBookmark(w.id);
      } else {
        await _svc.addBookmark(
          word: w.word,
          chineseDefinition: w.chineseDefinition,
          source: "manual",
        );
      }
      _word = await _svc.getWordDetail(w.id);
    } catch (e) { debugPrint("WordDetail bookmark error: $e"); }
    setState(()=>_acting=false);
  }

  @override
  Widget build(BuildContext ctx) {
    final t = Theme.of(ctx);
    if (_loading) return Scaffold(appBar: AppBar(title: const Text("")), body: const Center(child: CircularProgressIndicator()));
    if (_word == null) return Scaffold(appBar: AppBar(title: const Text("")), body: Center(child: Text(AppStrings.wordNotfound)));
    final w = _word!, prog = w.progress;
    final status = prog?["status"] as String? ?? "new";
    final bookmarked = prog?["is_bookmarked"] == true;
    return Scaffold(
      appBar: AppBar(title: Text(w.word), actions: [
        IconButton(
          icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: bookmarked ? Colors.orange : null),
          tooltip: bookmarked ? AppStrings.unbookmark : AppStrings.bookmark,
          onPressed: _acting ? null : _toggleBookmark,
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(w.word, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))), IconButton(onPressed: _speak, icon: const Icon(Icons.volume_up, color: AppTheme.primaryColor), tooltip: "播放发音"), _badge(status)]),
          if (w.phonetic != null) ...[const SizedBox(height: 4), Text(w.phonetic!, style: TextStyle(fontSize: 15, color: Colors.grey.shade600))],
          if (w.partOfSpeech != null) ...[const SizedBox(height: 4), Text(w.partOfSpeech!, style: TextStyle(fontSize: 13, color: t.colorScheme.primary))],
          const SizedBox(height: 12), Text(w.chineseDefinition ?? "", style: const TextStyle(fontSize: 16)),
        ]))),
        const SizedBox(height: 12),
        if (prog != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _ps(AppStrings.reviewCount, "${prog["review_count"] ?? 0}"), _ps(AppStrings.status, AppStrings.wordStatusLabel(status)),
          _ps(AppStrings.nextReview, prog["next_review_date"]?.toString().substring(0, 10) ?? "--"),
        ]))),
        const SizedBox(height: 12),
        if (w.exampleSentences != null && (w.exampleSentences as List).isNotEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.exampleSentences, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...(w.exampleSentences as List).map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s["en"] ?? "", style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
              Text(s["cn"] ?? "", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]))),
          ]))),
        const SizedBox(height: 12),
        if (_examples.isNotEmpty) ...[
          Card(
            color: AppTheme.primaryColor.withAlpha(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.assignment, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(AppStrings.cetRealExamples,
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                ]),
                const SizedBox(height: 8),
                for (final ex in _examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ex["example"] ?? "",
                          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, height: 1.4)),
                      const SizedBox(height: 3),
                      Text(ex["translation_cn"] ?? "",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      if ((ex["source"] as String? ?? "").isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(ex["source"] as String,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (status == "new") _btn(AppStrings.startLearning, Icons.play_arrow, _startLearning, _acting),
        if (status == "learning" || status == "review") Row(children: [
          Expanded(child: _btn(AppStrings.gotIt, Icons.check, () => _review(true), _acting, Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _btn(AppStrings.again, Icons.refresh, () => _review(false), _acting, Colors.orange)),
        ]),
        if (status == "mastered") Center(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle, size: 28, color: Colors.green.shade400), const SizedBox(width: 8),
          Text(AppStrings.mastered, style: TextStyle(fontSize: 16, color: Colors.green.shade600, fontWeight: FontWeight.w600)),
        ]))),
        const SizedBox(height: 8),
        _btn(_aidSlow ? AppStrings.aiGeneratingSlow : AppStrings.aiMemoryAid, Icons.auto_awesome, _genAid, _aidLoading, AppTheme.accentColor),
        const SizedBox(height: 12),
        if (prog?["memory_aid"] != null) _memoryAidCard((prog!["memory_aid"] as String?) ?? "", t),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _badge(String s) {
    final colors = {"new": Colors.grey, "learning": Colors.orange, "review": Colors.purple, "mastered": Colors.green};
    final c = colors[s] ?? Colors.grey;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: c.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withAlpha(80))), child: Text(AppStrings.wordStatusLabel(s), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)));
  }

  /// 记忆方法卡片：优先结构化渲染，旧纯文本数据自动清理后展示
  Widget _memoryAidCard(String raw, ThemeData t) {
    final parsed = _tryParseMemoryAid(raw);
    if (parsed != null) {
      final sections = (parsed["sections"] as List? ?? [])
          .map((s) {
            final m = s as Map<String, dynamic>;
            return AISection(
              title: (m["title"] as String? ?? ""),
              content: m["content"],
              type: (m["type"] as String? ?? "text"),
            );
          })
          .toList();
      final tips = (parsed["tips"] as List? ?? []).map((e) => e.toString()).toList();
      return AIAnalysisCard(
        title: (parsed["title"] as String? ?? AppStrings.memoryAid),
        icon: Icons.lightbulb,
        summary: parsed["summary"] as String?,
        sections: sections,
        tips: tips,
        accentColor: AppTheme.accentColor,
      );
    }
    final clean = VocabService.cleanMarkdown(raw);
    return Card(
      color: AppTheme.accentColor.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.lightbulb, size: 16, color: AppTheme.accentColor),
            const SizedBox(width: 6),
            Text(AppStrings.memoryAid,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentColor)),
          ]),
          const SizedBox(height: 8),
          Text(clean, style: const TextStyle(fontSize: 14, height: 1.5)),
        ]),
      ),
    );
  }

  Map<String, dynamic>? _tryParseMemoryAid(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic> && d["sections"] is List) return d;
    } catch (_) {}
    return null;
  }

  Widget _ps(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(l, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]);
  Widget _btn(String l, IconData i, VoidCallback t, bool ld, [Color? c]) => SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: ld ? null : t, icon: ld ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(i, size: 18), label: Text(l), style: ElevatedButton.styleFrom(backgroundColor: c ?? AppTheme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14))));
}
