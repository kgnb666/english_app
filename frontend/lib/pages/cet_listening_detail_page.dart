import "package:audioplayers/audioplayers.dart";
import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_listening_service.dart";
import "../services/api_service.dart";
import "../widgets/common_loading_button.dart";
import "../widgets/ai_content_renderer.dart";

class CetListeningDetailPage extends StatefulWidget {
  final String itemId;
  final String examType;
  const CetListeningDetailPage({
    super.key,
    required this.itemId,
    required this.examType,
  });

  @override
  State<CetListeningDetailPage> createState() => _CetListeningDetailPageState();
}

class _CetListeningDetailPageState extends State<CetListeningDetailPage> {
  final _svc = CetListeningService();
  final _player = AudioPlayer();
  Map<String, dynamic>? _item;
  final Map<String, int> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  bool _playing = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final item = await _svc.getItem(widget.itemId);
      if (!mounted) return;
      setState(() => _item = item);
    } catch (e) {
      debugPrint("CetListeningDetail load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _absoluteAudioUrl(String path) {
    if (path.startsWith("http")) return path;
    var base = ApiService().dio.options.baseUrl;
    if (base.endsWith("/api/v1")) {
      base = base.substring(0, base.length - "/api/v1".length);
    }
    return "$base$path";
  }

  Future<void> _togglePlay() async {
    final url = _item?["audio_url"] as String?;
    if (url == null || url.isEmpty) return;
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    await _player.play(UrlSource(_absoluteAudioUrl(url)));
    setState(() => _playing = false);
  }

  bool get _allAnswered {
    final n = (_item?["questions"] as List? ?? []).length;
    return _answers.length == n;
  }

  Future<void> _submit() async {
    if (!_allAnswered || _submitting) return;
    setState(() => _submitting = true);
    try {
      final answers = _answers.entries
          .map((e) => {"question_id": e.key, "answer": e.value})
          .toList();
      final r = await _svc.submit(
        examType: widget.examType,
        itemId: widget.itemId,
        answers: answers,
      );
      if (!mounted) return;
      setState(() => _result = r);
      ApiService.showSuccess(AppStrings.cetListeningDone);
    } catch (e) {
      debugPrint("CetListeningDetail submit error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cetListeningTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildResult(t)
              : _buildPractice(t),
    );
  }

  Widget _buildPractice(ThemeData t) {
    final questions = (_item?["questions"] as List? ?? []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_item?["title"] ?? "",
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Center(
                child: FilledButton.icon(
                  onPressed: _togglePlay,
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(_playing
                      ? AppStrings.cetListeningPlaying
                      : AppStrings.cetListeningPlay),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(_item?["script"] ?? "",
                  style: const TextStyle(fontSize: 14, height: 1.6)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        for (final q in questions) _questionCard(q, t),
        const SizedBox(height: 16),
        CommonLoadingButton(
          label: _allAnswered
              ? AppStrings.cetListeningSubmit
              : AppStrings.cetReadingAnswerAll,
          loadingLabel: AppStrings.cetReadingScoring,
          icon: Icons.send,
          backgroundColor: AppTheme.primaryColor,
          enabled: _allAnswered,
          loading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _questionCard(Map<String, dynamic> q, ThemeData t) {
    final qid = q["id"] as String;
    final options = (q["options"] as List? ?? []).cast<String>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q["question"] ?? "", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _answers[qid] = i),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _answers[qid] == i ? AppTheme.primaryColor.withAlpha(15) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _answers[qid] == i ? AppTheme.primaryColor : t.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _answers[qid] == i ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: _answers[qid] == i ? AppTheme.primaryColor : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(options[i], style: const TextStyle(fontSize: 13))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildResult(ThemeData t) {
    final r = _result!;
    final analysis = r["analysis"] as Map<String, dynamic>? ?? const {};
    final sentences = (analysis["sentence_analysis"] as List? ?? []).cast<Map<String, dynamic>>();
    final vocab = (analysis["vocabulary"] as List? ?? []).cast<Map<String, dynamic>>();
    final scoreColor = (r["accuracy"] as num? ?? 0) >= 60 ? Colors.green : Colors.orange;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text("${r["score"]} / ${r["total"]}",
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: scoreColor)),
              const SizedBox(height: 4),
              Text("${AppStrings.cetReadingAccuracy} ${r["accuracy"]}%",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (sentences.isNotEmpty || vocab.isNotEmpty)
          AIAnalysisCard(
            title: AppStrings.cetListeningSentenceAnalysis,
            icon: Icons.headset,
            sections: [
              if (sentences.isNotEmpty)
                AISection(
                  title: AppStrings.cetListeningSentences,
                  content: sentences.map((s) => {
                    "en": s["original"] ?? "",
                    "cn": [
                      s["translation_cn"] ?? "",
                      if ((s["key_points"] as String? ?? "").isNotEmpty)
                        "要点：${s["key_points"]}",
                    ].where((x) => x.toString().isNotEmpty).join("\n"),
                  }).toList(),
                  type: "example",
                ),
              if (vocab.isNotEmpty)
                AISection(
                  title: AppStrings.cetListeningVocab,
                  content: vocab,
                  type: "word",
                ),
            ],
            accentColor: Colors.blue,
          ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _result = null;
              _answers.clear();
            });
          },
          child: const Text(AppStrings.cetReadingRetry),
        ),
      ],
    );
  }
}
