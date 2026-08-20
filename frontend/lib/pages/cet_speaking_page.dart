import "dart:async";

import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_speaking_service.dart";
import "../services/speech_service.dart";
import "../services/api_service.dart";
import "../widgets/common_loading_button.dart";
import "../widgets/ai_content_renderer.dart";

class CetSpeakingPage extends StatefulWidget {
  const CetSpeakingPage({super.key});

  @override
  State<CetSpeakingPage> createState() => _CetSpeakingPageState();
}

class _CetSpeakingPageState extends State<CetSpeakingPage> {
  final _svc = CetSpeakingService();
  String _examType = "CET4";
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = await _svc.getQuestions(_examType);
      if (!mounted) return;
      setState(() => _questions = q);
    } catch (e) {
      debugPrint("CetSpeaking load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: _svc.getHistory(),
        builder: (ctx, snap) {
          final items = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(AppStrings.cetSpeakingHistory,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(AppStrings.noData)),
                )
              else
                for (final h in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h["question"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(h["user_answer"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text("${h["score"]}",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: (h["score"] as num? ?? 0) >= 12 ? Colors.green : Colors.orange)),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _answer(Map<String, dynamic> q) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SpeakingSheet(
        examType: _examType,
        question: q["question"] as String,
        svc: _svc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cetSpeakingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppStrings.cetSpeakingHistory,
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 口语")),
              ButtonSegment(value: "CET6", label: Text("CET6 口语")),
            ],
            selected: {_examType},
            onSelectionChanged: (s) {
              setState(() => _examType = s.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: _questions.length,
                    itemBuilder: (_, i) {
                      final q = _questions[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: Icon(Icons.mic, color: AppTheme.primaryColor),
                          title: Text(q["question"] ?? "",
                              style: const TextStyle(fontSize: 14, height: 1.4)),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => _answer(q),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}

class _SpeakingSheet extends StatefulWidget {
  final String examType;
  final String question;
  final CetSpeakingService svc;
  const _SpeakingSheet({
    required this.examType,
    required this.question,
    required this.svc,
  });

  @override
  State<_SpeakingSheet> createState() => _SpeakingSheetState();
}

class _SpeakingSheetState extends State<_SpeakingSheet> {
  bool _listening = false;
  bool _submitting = false;
  double _level = 0;
  int _seconds = 0;
  Timer? _timer;
  String _answer = "";
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _timer?.cancel();
    SpeechService.instance.stop();
    super.dispose();
  }

  Future<void> _start() async {
    final speech = SpeechService.instance;
    if (!speech.isReady) {
      final ok = await speech.init();
      if (!ok) return;
    }
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds += 1);
    });
    setState(() {
      _listening = true;
      _answer = "";
      _result = null;
    });
    final ok = await speech.listen(
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
      onResult: (text, isFinal, _) {
        if (isFinal) {
          _timer?.cancel();
          if (mounted) {
            setState(() {
              _listening = false;
              _level = 0;
              _answer = text;
            });
          }
        }
      },
    );
    if (!ok && mounted) {
      _timer?.cancel();
      setState(() => _listening = false);
      ApiService.showError(AppStrings.speechFailed);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await SpeechService.instance.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _submit() async {
    final text = _answer.trim();
    if (text.isEmpty) {
      ApiService.showError(AppStrings.speechNoResult);
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await widget.svc.submit(
        examType: widget.examType,
        question: widget.question,
        userAnswer: text,
      );
      if (!mounted) return;
      setState(() => _result = r);
      ApiService.showSuccess(AppStrings.cetSpeakingDone);
    } catch (e) {
      debugPrint("CetSpeaking submit error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.cetSpeakingQuestion,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(widget.question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 16),
          if (_listening)
            Row(children: [
              Transform.scale(
                scale: 1.0 + (_level.clamp(0, 1) * 0.3),
                child: const Icon(Icons.mic, color: Colors.red),
              ),
              const SizedBox(width: 10),
              Text("${AppStrings.listening} ${_fmt(_seconds)}",
                  style: TextStyle(fontSize: 13, color: Colors.red.shade400)),
            ]),
          if (_listening)
            const SizedBox(height: 12),
          CommonLoadingButton(
            label: _listening ? AppStrings.stopListening : AppStrings.cetSpeakingRecord,
            icon: _listening ? Icons.stop : Icons.mic,
            backgroundColor: _listening ? Colors.red : AppTheme.primaryColor,
            loading: false,
            onPressed: _listening ? _stop : _start,
          ),
          if (_answer.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(AppStrings.cetSpeakingYourAnswer,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_answer, style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 12),
            CommonLoadingButton(
              label: AppStrings.cetSpeakingSubmit,
              loadingLabel: AppStrings.cetSpeakingScoring,
              icon: Icons.send,
              backgroundColor: AppTheme.primaryColor,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            _resultView(t, _result!),
          ],
        ]),
      ),
    );
  }

  Widget _resultView(ThemeData t, Map<String, dynamic> r) {
    final scores = r["scores"] as Map<String, dynamic>? ?? const {};
    final suggestions = ((r["analysis"] as Map<String, dynamic>?)?["suggestions"] as List? ?? [])
        .cast<String>();
    final analysis = ((r["analysis"] as Map<String, dynamic>?)?["analysis"] as String? ?? "");
    final score = (r["score"] as num?)?.toInt() ?? 0;
    final color = score >= 15 ? Colors.green : score >= 10 ? Colors.orange : Colors.red;
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("$score",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text("/ 20", style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _scoreItem(AppStrings.cetSpeakingFluency, scores["fluency"]),
              _scoreItem(AppStrings.cetSpeakingGrammar, scores["grammar"]),
              _scoreItem(AppStrings.cetSpeakingVocabulary, scores["vocabulary"]),
              _scoreItem(AppStrings.cetSpeakingPronunciation, scores["pronunciation"]),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      AIAnalysisCard(
        title: AppStrings.cetSpeakingScore,
        icon: Icons.record_voice_over,
        summary: analysis.isEmpty ? null : analysis,
        sections: const [],
        tips: suggestions,
        accentColor: Colors.pink,
      ),
    ]);
  }

  Widget _scoreItem(String label, dynamic value) {
    final v = (value as num?)?.toInt() ?? 0;
    return Column(children: [
      Text("$v/5", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, "0");
    final s = (sec % 60).toString().padLeft(2, "0");
    return "$m:$s";
  }
}
