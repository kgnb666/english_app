import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_reading_service.dart";
import "../services/vocab_service.dart";
import "../services/api_service.dart";
import "../widgets/common_loading_button.dart";
import "../widgets/ai_content_renderer.dart";

class CetReadingDetailPage extends StatefulWidget {
  final String articleId;
  final String examType;
  const CetReadingDetailPage({
    super.key,
    required this.articleId,
    required this.examType,
  });

  @override
  State<CetReadingDetailPage> createState() => _CetReadingDetailPageState();
}

class _CetReadingDetailPageState extends State<CetReadingDetailPage> {
  final _svc = CetReadingService();
  final _vocab = VocabService();
  Map<String, dynamic>? _article;
  final Map<String, int> _answers = {};
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _result;
  String? _error;
  final Set<String> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final article = await _svc.getArticle(widget.articleId);
      if (!mounted) return;
      setState(() => _article = article);
    } catch (e) {
      debugPrint("CetReadingDetail load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _allAnswered {
    final questions = (_article?["questions"] as List? ?? []).length;
    return _answers.length == questions;
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
        articleId: widget.articleId,
        answers: answers,
      );
      if (!mounted) return;
      setState(() => _result = r);
      ApiService.showSuccess(AppStrings.cetReadingSubmitted);
    } catch (e) {
      debugPrint("CetReadingDetail submit error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addToBookmark(String word, String? definition) async {
    try {
      await _vocab.addBookmark(
        word: word,
        chineseDefinition: definition,
        source: "reading",
        context: widget.articleId,
      );
      if (!mounted) return;
      setState(() => _bookmarked.add(word));
      ApiService.showError(AppStrings.addedToWordBook);
    } catch (e) {
      debugPrint("CetReadingDetail bookmark error: $e");
      if (mounted) ApiService.showError(AppStrings.addToWordBookFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cetReadingTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _result != null
                  ? _buildResult(t)
                  : _buildPractice(t),
    );
  }

  Widget _buildPractice(ThemeData t) {
    final questions = (_article?["questions"] as List? ?? []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_article?["title"] ?? "",
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(_article?["article"] ?? "",
                  style: const TextStyle(fontSize: 15, height: 1.7)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        for (final q in questions) _questionCard(q, t),
        const SizedBox(height: 16),
        CommonLoadingButton(
          label: _allAnswered
              ? AppStrings.cetReadingSubmit
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
                  color: _answers[qid] == i
                      ? AppTheme.primaryColor.withAlpha(15)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _answers[qid] == i
                        ? AppTheme.primaryColor
                        : t.colorScheme.outlineVariant,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    _answers[qid] == i
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: _answers[qid] == i
                        ? AppTheme.primaryColor
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(options[i], style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildResult(ThemeData t) {
    final r = _result!;
    final questions = (_article?["questions"] as List? ?? []).cast<Map<String, dynamic>>();
    final perQuestion = ((r["analysis"] as Map<String, dynamic>?)?["per_question"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final sentences = ((r["analysis"] as Map<String, dynamic>?)?["complex_sentences"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final vocab = ((r["analysis"] as Map<String, dynamic>?)?["vocabulary"] as List? ?? [])
        .cast<Map<String, dynamic>>();
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
        if (perQuestion.isNotEmpty) ...[
          Text(AppStrings.cetReadingAnalysis,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < perQuestion.length; i++)
            _analysisCard(t, questions, perQuestion[i], i),
        ],
        if (sentences.isNotEmpty) ...[
          const SizedBox(height: 12),
          AIAnalysisCard(
            title: AppStrings.cetReadingSentences,
            icon: Icons.analytics,
            sections: [
              AISection(
                title: "",
                content: sentences
                    .map((s) => {"en": s["original"], "cn": s["analysis_cn"]})
                    .toList(),
                type: "example",
              ),
            ],
            accentColor: Colors.teal,
          ),
        ],
        if (vocab.isNotEmpty) ...[
          const SizedBox(height: 12),
          _vocabCard(t, vocab),
        ],
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

  Widget _analysisCard(
    ThemeData t,
    List<Map<String, dynamic>> questions,
    Map<String, dynamic> a,
    int index,
  ) {
    final q = index < questions.length ? questions[index] : null;
    final options = (q?["options"] as List? ?? []).cast<String>();
    final qid = a["question_id"] as String?;
    final userAns = _answers[qid];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${index + 1}. ${q?["question"] ?? ""}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 6),
          Text("${AppStrings.cetReadingYourAnswer}：${userAns != null && userAns < options.length ? options[userAns] : "--"}",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text("${AppStrings.cetReadingCorrectReason}：${a["correct_reason"] ?? ""}",
              style: const TextStyle(fontSize: 14, height: 1.6)),
          if ((a["trap"] as String? ?? "").isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("${AppStrings.cetReadingTrap}：${a["trap"]}",
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade800, height: 1.5)),
            ),
        ]),
      ),
    );
  }

  Widget _vocabCard(ThemeData t, List<Map<String, dynamic>> vocab) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.cetReadingVocab,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final v in vocab)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: t.colorScheme.onSurface),
                      children: [
                        TextSpan(text: v["word"] ?? "",
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: "  ${v["definition_cn"] ?? ""}",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _bookmarked.contains(v["word"])
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    size: 20,
                    color: _bookmarked.contains(v["word"])
                        ? Colors.orange
                        : Colors.grey.shade400,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _bookmarked.contains(v["word"])
                      ? null
                      : () => _addToBookmark(v["word"] as String, v["definition_cn"] as String?),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
