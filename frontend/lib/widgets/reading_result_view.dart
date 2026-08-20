import "package:flutter/material.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/reading_service.dart";
import "../services/vocab_service.dart";

/// 阅读分析结果展示（主页面与历史详情复用）
class ReadingResultView extends StatefulWidget {
  final ReadingResult result;
  const ReadingResultView({super.key, required this.result});

  @override
  State<ReadingResultView> createState() => _ReadingResultViewState();
}

class _ReadingResultViewState extends State<ReadingResultView> {
  final _vocab = VocabService();
  final Set<String> _bookmarked = {};
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = widget.result;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(t, AppStrings.summary, Icons.summarize, r.summaryCn),
      const SizedBox(height: 16),
      if (r.mainIdea.isNotEmpty) ...[
        _section(t, AppStrings.mainIdea, Icons.lightbulb, r.mainIdea),
        const SizedBox(height: 16),
      ],
      if (r.vocabulary.isNotEmpty) ...[
        _buildVocab(r.vocabulary, t),
        const SizedBox(height: 16),
      ],
      if (r.complexSentences.isNotEmpty) _buildSentences(r.complexSentences, t),
    ]);
  }

  Widget _section(ThemeData t, String title, IconData icon, String content) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ]),
              const SizedBox(height: 8),
              Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
            ],
          ),
        ),
      );

  Widget _buildVocab(List<VocabItem> vocab, ThemeData t) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.bookmark, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(AppStrings.keyVocabulary, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ]),
              const SizedBox(height: 12),
              ...vocab.map((v) => _vocabRow(v, t)),
            ],
          ),
        ),
      );

  Widget _vocabRow(VocabItem v, ThemeData t) {
    final done = _bookmarked.contains(v.word);
    final busy = _busy.contains(v.word);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 7, right: 10), decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: t.colorScheme.onSurface),
                children: [
                  TextSpan(text: v.word, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: "  ${v.definitionCn}", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(done ? Icons.bookmark : Icons.bookmark_border, size: 20,
                    color: done ? Colors.orange : Colors.grey.shade400),
            tooltip: done ? AppStrings.inWordBook : AppStrings.bookmarkFromReading,
            visualDensity: VisualDensity.compact,
            onPressed: busy || done ? null : () => _addBookmark(v),
          ),
        ],
      ),
    );
  }

  Future<void> _addBookmark(VocabItem v) async {
    setState(() => _busy.add(v.word));
    try {
      await _vocab.addBookmark(
        word: v.word,
        chineseDefinition: v.definitionCn,
        source: "reading",
        context: v.definitionCn,
      );
      if (!mounted) return;
      setState(() => _bookmarked.add(v.word));
    } catch (e) {
      debugPrint("ReadingResultView bookmark error: $e");
    } finally {
      if (mounted) setState(() => _busy.remove(v.word));
    }
  }

  Widget _buildSentences(List<SentenceItem> ss, ThemeData t) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.analytics, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(AppStrings.complexSentences, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ]),
              const SizedBox(height: 12),
              ...ss.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                          child: Text("${e.key + 1}. ${e.value.original}", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                        ),
                        const SizedBox(height: 6),
                        Text(e.value.analysisCn, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      );
}
