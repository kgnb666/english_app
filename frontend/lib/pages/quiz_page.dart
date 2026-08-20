import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/vocab_service.dart";
import "../services/tts_service.dart";

/// 单词测验：模式选择 + 历史记录
class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _svc = VocabService();
  List<TestHistoryItem> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final history = await _svc.getTestHistory();
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      debugPrint("QuizPage load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start(String type) {
    context.push("/quiz/run", extra: type);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.quizTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(AppStrings.quizModeTitle, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _modeCard(t, AppStrings.quizChoice, AppStrings.quizChoiceSub, Icons.checklist, Colors.blue, () => _start("choice")),
            const SizedBox(height: 10),
            _modeCard(t, AppStrings.quizSpelling, AppStrings.quizSpellingSub, Icons.keyboard, Colors.orange, () => _start("spelling")),
            const SizedBox(height: 10),
            _modeCard(t, AppStrings.quizListening, AppStrings.quizListeningSub, Icons.hearing, Colors.purple, () => _start("listening")),
            const SizedBox(height: 20),
            Text(AppStrings.quizHistory, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(AppStrings.noQuizHistory, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
              )
            else
              ..._history.map((h) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      leading: Icon(_typeIcon(h.testType), color: AppTheme.primaryColor),
                      title: Text(_typeLabel(h.testType), style: const TextStyle(fontSize: 14)),
                      subtitle: Text("${h.score}/${h.total} · ${h.accuracy}% · ${h.createdAt.substring(0, 16)}", style: const TextStyle(fontSize: 12)),
                      trailing: Text("${h.accuracy}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: h.accuracy >= 70 ? Colors.green : h.accuracy >= 40 ? Colors.orange : Colors.red)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(ThemeData t, String title, String sub, IconData icon, Color color, VoidCallback onTap) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );

  IconData _typeIcon(String type) {
    switch (type) {
      case "choice":
        return Icons.checklist;
      case "spelling":
        return Icons.keyboard;
      case "listening":
        return Icons.hearing;
      default:
        return Icons.quiz_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case "choice":
        return AppStrings.quizChoice;
      case "spelling":
        return AppStrings.quizSpelling;
      case "listening":
        return AppStrings.quizListening;
      default:
        return type;
    }
  }
}

/// 答题流程 + 结果
class QuizRunPage extends StatefulWidget {
  final String testType;
  const QuizRunPage({super.key, required this.testType});

  @override
  State<QuizRunPage> createState() => _QuizRunPageState();
}

class _QuizRunPageState extends State<QuizRunPage> {
  final _svc = VocabService();
  final _spellCtrl = TextEditingController();

  List<QuizQuestion> _questions = [];
  final List<Map<String, dynamic>> _answers = [];
  int _index = 0;
  int _correctCount = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _selectedOption;
  String? _feedback;
  bool _feedbackCorrect = false;
  Timer? _nextTimer;
  QuizResult? _result;
  String? _error;

  bool get _isSpelling => widget.testType == "spelling";
  bool get _isListening => widget.testType == "listening";

  @override
  void initState() {
    super.initState();
    _initTts();
    _load();
  }

  Future<void> _initTts() async {
    await TtsService.instance.setRate(0.45);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qs = await _svc.generateTest(widget.testType, count: 10);
      if (!mounted) return;
      setState(() => _questions = qs);
      if (_isListening) _speak();
    } catch (e) {
      debugPrint("QuizRun load error: $e");
      if (!mounted) return;
      setState(() => _error = AppStrings.quizGenerateFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _speak() async {
    final q = _current;
    if (q == null) return;
    try {
      final ok = await TtsService.instance.speakWord(q.word, q.audioUrl);
      if (!ok) debugPrint("Quiz TTS failed: ${TtsService.instance.lastError}");
    } catch (e) {
      debugPrint("Quiz TTS error: $e");
    }
  }

  QuizQuestion? get _current => _index < _questions.length ? _questions[_index] : null;

  void _answer(String answer) {
    if (_feedback != null) return;
    final q = _current;
    if (q == null) return;
    final isCorrect = _isSpelling
        ? answer.trim().toLowerCase() == q.correct.trim().toLowerCase()
        : answer.trim() == q.correct.trim();
    _answers.add({"word_id": q.wordId, "answer": answer.trim()});
    setState(() {
      _selectedOption = answer;
      _feedback = isCorrect ? AppStrings.quizCorrect : AppStrings.quizWrong;
      _feedbackCorrect = isCorrect;
      if (isCorrect) _correctCount++;
    });
    _nextTimer?.cancel();
    _nextTimer = Timer(const Duration(milliseconds: 900), _next);
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _index++;
      _selectedOption = null;
      _feedback = null;
      _spellCtrl.clear();
    });
    if (_index >= _questions.length) {
      _submit();
    } else if (_isListening) {
      _speak();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await _svc.submitTest(widget.testType, _answers);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      debugPrint("QuizRun submit error: $e");
      if (!mounted) return;
      setState(() => _error = AppStrings.quizSubmitFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _spellCtrl.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_result != null) return _buildResult(t);
    if (_submitting) {
      return Scaffold(
        appBar: AppBar(title: Text(_typeTitle())),
        body: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text("提交中..."),
          ]),
        ),
      );
    }
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(_typeTitle())), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_typeTitle())),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_error ?? AppStrings.noQuestions, style: TextStyle(color: t.colorScheme.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text(AppStrings.retry)),
          ]),
        ),
      );
    }
    final q = _current!;
    final total = _questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(_typeTitle()), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              "${AppStrings.quizScore} $_correctCount/$total",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
            ),
          ),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_index + 1) / total, minHeight: 6),
          ),
          const SizedBox(height: 8),
          Text(
            "${AppStrings.quizQuestion} ${_index + 1}/$total",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _isSpelling ? _buildSpellingPrompt(q, t) : _buildChoicePrompt(q, t),
            ),
          ),
          const SizedBox(height: 16),
          if (_isSpelling)
            TextField(
              controller: _spellCtrl,
              enabled: _feedback == null,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: AppStrings.quizInputWord,
                hintText: AppStrings.quizInputWordHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _answer(v);
              },
            ),
          if (_isSpelling) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: (_feedback != null || _spellCtrl.text.trim().isEmpty)
                  ? null
                  : () => _answer(_spellCtrl.text),
              icon: const Icon(Icons.check, size: 18),
              label: Text(AppStrings.quizConfirm),
            ),
          ],
          if (!_isSpelling) ...[
            ...q.options.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _optionButton(t, opt),
                )),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_feedbackCorrect ? Colors.green : Colors.red).withAlpha(12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(_feedbackCorrect ? Icons.check_circle : Icons.cancel, color: _feedbackCorrect ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _feedbackCorrect
                        ? AppStrings.quizCorrect
                        : "${AppStrings.quizWrong} ${AppStrings.quizCorrectAnswer}: ${q.correct}",
                    style: TextStyle(fontSize: 13, color: _feedbackCorrect ? Colors.green : Colors.red),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoicePrompt(QuizQuestion q, ThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(q.word, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
          if (_isListening)
            IconButton(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up, color: AppTheme.primaryColor, size: 28),
              tooltip: AppStrings.quizReplay,
            ),
        ]),
        if (q.phonetic != null) ...[
          const SizedBox(height: 4),
          Text(q.phonetic!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
        const SizedBox(height: 8),
        Text(_isListening ? AppStrings.quizListeningHint : AppStrings.quizChoiceHint, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildSpellingPrompt(QuizQuestion q, ThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.quizSpellingPrompt, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        Text(q.correct, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
      ],
    );
  }

  Widget _optionButton(ThemeData t, String option) {
    final q = _current!;
    Color? bg;
    Color? borderColor;
    if (_feedback != null) {
      if (option == q.correct) {
        bg = Colors.green.withAlpha(20);
        borderColor = Colors.green;
      } else if (option == _selectedOption) {
        bg = Colors.red.withAlpha(20);
        borderColor = Colors.red;
      }
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _feedback == null ? () => _answer(option) : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: borderColor != null ? BorderSide(color: borderColor) : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(option, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _buildResult(ThemeData t) {
    final r = _result!;
    final wrong = r.results.where((x) => !x.isCorrect).toList();
    final color = r.accuracy >= 70 ? Colors.green : r.accuracy >= 40 ? Colors.orange : Colors.red;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.quizResultTitle), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(
                  "${r.accuracy}%",
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 8),
                Text(AppStrings.quizAccuracy, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat(t, "${r.score}/${r.total}", AppStrings.quizScore),
                  _stat(t, "$_correctCount", AppStrings.quizCorrectCount),
                  _stat(t, "${wrong.length}", AppStrings.quizWrongCount),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Text(AppStrings.quizWrongList, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (wrong.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(children: [
                  Icon(Icons.emoji_events, size: 48, color: Colors.amber.shade400),
                  const SizedBox(height: 8),
                  Text(AppStrings.quizAllCorrect, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ]),
              ),
            )
          else
            ...wrong.map((w) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.close, color: Colors.red),
                    title: Text(w.word, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      "${AppStrings.quizYourAnswer}: ${w.userAnswer}\n${AppStrings.quizCorrectAnswer}: ${w.correct}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                  ),
                )),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go("/vocabulary"),
                icon: const Icon(Icons.menu_book),
                label: Text(AppStrings.backToWords),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _questions = [];
                    _answers.clear();
                    _index = 0;
                    _correctCount = 0;
                    _result = null;
                    _selectedOption = null;
                    _feedback = null;
                    _spellCtrl.clear();
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: Text(AppStrings.quizRetry),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String value, String label) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]);

  String _typeTitle() {
    switch (widget.testType) {
      case "choice":
        return AppStrings.quizChoice;
      case "spelling":
        return AppStrings.quizSpelling;
      case "listening":
        return AppStrings.quizListening;
      default:
        return AppStrings.quizTitle;
    }
  }
}
