import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_translation_service.dart";
import "../services/api_service.dart";
import "../widgets/common_loading_button.dart";
import "../widgets/ai_content_renderer.dart";

class CetTranslationPage extends StatefulWidget {
  const CetTranslationPage({super.key});

  @override
  State<CetTranslationPage> createState() => _CetTranslationPageState();
}

class _CetTranslationPageState extends State<CetTranslationPage> {
  final _svc = CetTranslationService();
  String _examType = "CET4";
  List<Map<String, dynamic>> _sentences = [];
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
      final s = await _svc.getSentences(_examType);
      if (!mounted) return;
      setState(() => _sentences = s);
    } catch (e) {
      debugPrint("CetTranslation load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showHistory() async {
    final items = await _svc.getHistory();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx2, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text(AppStrings.cetTranslationHistory,
                style: Theme.of(ctx2).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                  title: Text(h["chinese_text"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(h["user_translation"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text("${h["score"]}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: (h["score"] as num? ?? 0) >= 6 ? Colors.green : Colors.orange)),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _practice(Map<String, dynamic> sentence) async {
    final ctrl = TextEditingController();
    Map<String, dynamic>? result;
    var submitting = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sentence["chinese"] ?? "",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppStrings.cetTranslationInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            CommonLoadingButton(
              label: AppStrings.cetTranslationSubmit,
              loadingLabel: AppStrings.cetTranslationScoring,
              icon: Icons.send,
              backgroundColor: AppTheme.primaryColor,
              loading: submitting,
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isEmpty) return;
                setSheetState(() => submitting = true);
                try {
                  final r = await _svc.submit(
                    examType: _examType,
                    sentenceId: sentence["id"] as String,
                    userTranslation: text,
                  );
                  if (ctx.mounted) {
                    setSheetState(() => result = r);
                    ApiService.showSuccess(AppStrings.cetTranslationDone);
                  }
                } catch (e) {
                  debugPrint("CetTranslation submit error: $e");
                  if (ctx.mounted) ApiService.showError(AppStrings.operationFailed);
                } finally {
                  if (ctx.mounted) setSheetState(() => submitting = false);
                }
              },
            ),
            if (result != null) ...[
              const SizedBox(height: 14),
              _resultView(result!, Theme.of(ctx)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _resultView(Map<String, dynamic> r, ThemeData t) {
    final a = r["analysis"] as Map<String, dynamic>? ?? const {};
    final score = (r["score"] as num?)?.toInt() ?? 0;
    final color = score >= 7 ? Colors.green : score >= 4 ? Colors.orange : Colors.red;
    final suggestions = (a["suggestions"] as List? ?? []).cast<String>();
    final sections = <AISection>[
      if ((a["vocab_analysis"] as String? ?? "").isNotEmpty)
        AISection(title: AppStrings.cetTranslationVocab, content: a["vocab_analysis"], type: "text"),
      if ((a["word_order_analysis"] as String? ?? "").isNotEmpty)
        AISection(title: AppStrings.cetTranslationOrder, content: a["word_order_analysis"], type: "text"),
      if ((a["naturalness_analysis"] as String? ?? "").isNotEmpty)
        AISection(title: AppStrings.cetTranslationNatural, content: a["naturalness_analysis"], type: "text"),
      if ((a["reference"] as String? ?? "").isNotEmpty)
        AISection(
          title: AppStrings.cetTranslationReference,
          content: [{"en": a["reference"]}],
          type: "example",
        ),
    ];
    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text("$score",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 4),
            Text("/ 10", style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const Spacer(),
            Text(AppStrings.cetTranslationScore,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      AIAnalysisCard(
        title: AppStrings.cetTranslationAnalysis,
        icon: Icons.rate_review,
        sections: sections,
        tips: suggestions,
        accentColor: Colors.teal,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cetTranslationTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppStrings.cetTranslationHistory,
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 翻译")),
              ButtonSegment(value: "CET6", label: Text("CET6 翻译")),
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
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _sentences.length,
                        itemBuilder: (_, i) {
                          final s = _sentences[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: const Icon(Icons.translate, color: AppTheme.primaryColor),
                              title: Text(s["chinese"] ?? "",
                                  style: const TextStyle(fontSize: 14, height: 1.4)),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => _practice(s),
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
