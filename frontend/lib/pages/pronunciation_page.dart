import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/pronunciation_service.dart";
import "../services/study_session_service.dart";
import "../services/tts_service.dart";
import "../services/speech_service.dart";
import "../services/api_service.dart";

class PronunciationPage extends StatefulWidget {
  const PronunciationPage({super.key});

  @override
  State<PronunciationPage> createState() => _PronunciationPageState();
}

class _PronunciationPageState extends State<PronunciationPage> {
  final _svc = PronunciationService();
  final _study = StudySessionService.instance;
  final _inputCtrl = TextEditingController();
  bool _listening = false;
  bool _evaluating = false;
  String _target = "I went to the park yesterday";
  String _recognized = "";
  double? _confidence;
  PronunciationResult? _result;
  List<PronunciationResult> _history = [];
  String? _error;

  static const _sentences = [
    "I went to the park yesterday",
    "She is reading a book in the garden",
    "How are you doing today?",
    "The weather is really nice this morning",
    "I would like a cup of coffee, please",
  ];

  @override
  void initState() {
    super.initState();
    _study.start("speaking");
    TtsService.instance.setRate(0.45);
    // 预合成预设练习句，第一次点击也基本秒播
    TtsService.instance.preloadMany(_sentences.toList());
    SpeechService.instance.init();
    _loadHistory();
  }

  @override
  void dispose() {
    _study.end("speaking");
    TtsService.instance.stop();
    SpeechService.instance.stop();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await _svc.getHistory(limit: 10);
      if (!mounted) return;
      setState(() => _history = h);
    } catch (e) {
      debugPrint("PronunciationPage history error: $e");
    }
  }

  Future<void> _speak(String text) async {
    final ok = await TtsService.instance.speak(text);
    if (!ok) {
      debugPrint("PronunciationPage TTS failed: ${TtsService.instance.lastError}");
    }
  }

  Future<void> _startListening() async {
    final speech = SpeechService.instance;
    if (!speech.isReady) {
      final ok = await speech.init();
      if (!ok) {
        ApiService.showError(AppStrings.enableMicrophonePermission);
        return;
      }
    }
    if (_listening) return;
    setState(() {
      _listening = true;
      _recognized = "";
      _confidence = null;
      _result = null;
      _error = null;
    });
    final ok = await speech.listen(
      onResult: (text, isFinal, confidence) {
        if (!mounted) return;
        setState(() {
          _recognized = text;
          _confidence = confidence;
        });
        if (isFinal) {
          setState(() => _listening = false);
          _submit();
        }
      },
    );
    if (!ok) {
      if (mounted) setState(() => _listening = false);
      if (speech.lastError == "permission") {
        ApiService.showError(AppStrings.enableMicrophonePermission);
      } else {
        ApiService.showError(AppStrings.speechFailed);
      }
    }
  }

  Future<void> _stopListening() async {
    await SpeechService.instance.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _submit() async {
    final rec = _recognized.trim();
    if (rec.isEmpty) {
      if (mounted) setState(() => _error = AppStrings.pronunciationNoSpeech);
      return;
    }
    setState(() => _evaluating = true);
    try {
      final r = await _svc.evaluate(
        targetText: _target,
        recognizedText: rec,
        confidence: _confidence,
      );
      if (!mounted) return;
      setState(() => _result = r);
      _loadHistory();
    } catch (e) {
      debugPrint("PronunciationPage evaluate error: $e");
      if (mounted) setState(() => _error = AppStrings.pronunciationFailed);
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.pronunciationTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _targetCard(t),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13, color: t.colorScheme.error),
              ),
            ),
          if (_evaluating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("正在分析发音..."),
                ]),
              ),
            ),
          if (_result != null && !_evaluating) _resultCard(_result!, t),
          const SizedBox(height: 12),
          _historyCard(t),
        ],
      ),
    );
  }

  Widget _targetCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            AppStrings.pronunciationPractice,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sentences)
                ChoiceChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: _target == s,
                  onSelected: (_) => setState(() => _target = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputCtrl,
            decoration: InputDecoration(
              hintText: AppStrings.pronunciationCustomHint,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, size: 18),
                onPressed: () {
                  final v = _inputCtrl.text.trim();
                  if (v.isNotEmpty) setState(() => _target = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _target,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: AppTheme.primaryColor),
                tooltip: AppStrings.pronunciationListen,
                onPressed: () => _speak(_target),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _listening
                  ? ElevatedButton.icon(
                      onPressed: _stopListening,
                      icon: const Icon(Icons.stop),
                      label: const Text(AppStrings.listening),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: (SpeechService.instance.isReady && !_evaluating)
                          ? _startListening
                          : null,
                      icon: const Icon(Icons.mic),
                      label: const Text(AppStrings.pronunciationRecord),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ]),
          if (!SpeechService.instance.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppStrings.pronunciationSttInit,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          if (_recognized.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "${AppStrings.pronunciationYouSaid}: $_recognized",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _resultCard(PronunciationResult r, ThemeData t) {
    final color = r.score >= 80
        ? Colors.green
        : r.score >= 60
            ? Colors.orange
            : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                AppStrings.pronunciationResult,
                style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Column(children: [
              Text(
                "${r.score}",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                AppStrings.pronunciationScore,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: r.score / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: color,
            backgroundColor: t.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 16),
          if (r.mispronouncedWords.isNotEmpty) ...[
            Text(
              AppStrings.pronunciationWrongWords,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final w in r.mispronouncedWords) _wrongWordRow(w, t),
            const SizedBox(height: 12),
          ] else
            Row(children: [
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade400),
              const SizedBox(width: 6),
              Text(
                AppStrings.pronunciationGreat,
                style: TextStyle(fontSize: 13, color: Colors.green.shade600),
              ),
            ]),
          if (r.suggestions.isNotEmpty) ...[
            Text(
              AppStrings.pronunciationSuggestions,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            for (final s in r.suggestions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("•  ", style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(s, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ]),
              ),
          ],
          if (r.overallAdvice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "${AppStrings.pronunciationAdvice}: ${r.overallAdvice}",
              style: TextStyle(
                fontSize: 13,
                color: t.colorScheme.onSurface.withAlpha(180),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _speak(r.targetText),
              icon: const Icon(Icons.volume_up, size: 18),
              label: const Text(AppStrings.pronunciationListenAgain),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _wrongWordRow(Map<String, dynamic> w, ThemeData t) {
    final word = w["word"] ?? "";
    final recognized = w["recognized"] ?? "";
    final syllables = w["syllables"] ?? "";
    final tip = w["tip"] ?? "";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: t.colorScheme.onSurface),
            children: [
              TextSpan(
                text: word.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              if (recognized.toString().isNotEmpty) ...[
                const TextSpan(text: "  →  "),
                TextSpan(
                  text: recognized.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                ),
              ],
            ],
          ),
        ),
        if (syllables.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              syllables.toString(),
              style: TextStyle(fontSize: 12, color: Colors.indigo.shade400),
            ),
          ),
        if (tip.toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              tip.toString(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
      ]),
    );
  }

  Widget _historyCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            AppStrings.pronunciationHistory,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  AppStrings.pronunciationNoHistory,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            for (final h in _history)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: (h.score >= 80 ? Colors.green : h.score >= 60 ? Colors.orange : Colors.red)
                          .withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${h.score}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: h.score >= 80
                            ? Colors.green.shade700
                            : h.score >= 60
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h.targetText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 18),
                    color: AppTheme.primaryColor,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _speak(h.targetText),
                  ),
                ]),
              ),
        ]),
      ),
    );
  }
}
