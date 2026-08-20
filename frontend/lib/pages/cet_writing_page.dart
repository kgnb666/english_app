import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_writing_service.dart";
import "../services/api_service.dart";
import "../widgets/common_loading_button.dart";
import "../widgets/ai_content_renderer.dart";

class CetWritingPage extends StatefulWidget {
  const CetWritingPage({super.key});

  @override
  State<CetWritingPage> createState() => _CetWritingPageState();
}

class _CetWritingPageState extends State<CetWritingPage> {
  final _svc = CetWritingService();
  final _essayCtrl = TextEditingController();
  String _examType = "CET4";
  bool _submitting = false;
  bool _aiTemplateLoading = false;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _essayCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final t = await _svc.getTemplates();
      if (mounted) setState(() => _templates = t);
    } catch (e) {
      debugPrint("CetWriting templates error: $e");
    }
  }

  Future<void> _submit() async {
    final essay = _essayCtrl.text.trim();
    if (essay.length < 10) {
      ApiService.showError(AppStrings.articleTooShort);
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await _svc.reviewEssay(essay: essay, examType: _examType);
      if (!mounted) return;
      setState(() => _result = r);
      ApiService.showSuccess(AppStrings.cetWritingDone);
    } catch (e) {
      debugPrint("CetWriting submit error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveAsTemplate() async {
    final essay = _essayCtrl.text.trim();
    if (essay.isEmpty) return;
    final titleCtrl = TextEditingController(text: "我的$_examType作文模板");
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.cetWritingSaveTemplate),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: AppStrings.cetTemplateTitle,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.createTemplate(title: titleCtrl.text, content: essay);
                _loadTemplates();
              } catch (e) {
                debugPrint("CetWriting save template error: $e");
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _aiRecommend() async {
    setState(() => _aiTemplateLoading = true);
    try {
      final t = await _svc.aiRecommend(examType: _examType);
      if (!mounted) return;
      setState(() => _templates.insert(0, t));
      ApiService.showError(AppStrings.cetTemplateRecommended);
    } catch (e) {
      debugPrint("CetWriting ai recommend error: $e");
      if (mounted) ApiService.showError(AppStrings.operationFailed);
    } finally {
      if (mounted) setState(() => _aiTemplateLoading = false);
    }
  }

  void _showTemplate(Map<String, dynamic> t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t["title"] ?? "",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await _svc.deleteTemplate(t["id"] as String);
                _loadTemplates();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ]),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
            child: SingleChildScrollView(
              child: Text(t["content"] ?? "",
                  style: const TextStyle(fontSize: 14, height: 1.6)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _essayCtrl.text = t["content"] ?? "";
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text(AppStrings.cetTemplateUse),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cetWritingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 作文")),
              ButtonSegment(value: "CET6", label: Text("CET6 作文")),
            ],
            selected: {_examType},
            onSelectionChanged: (s) => setState(() => _examType = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _essayCtrl,
            maxLines: 8,
            minLines: 5,
            decoration: InputDecoration(
              hintText: AppStrings.cetWritingHint,
              labelText: AppStrings.cetWritingEssay,
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: CommonLoadingButton(
                label: AppStrings.cetWritingReview,
                loadingLabel: AppStrings.cetWritingScoring,
                icon: Icons.rate_review,
                backgroundColor: AppTheme.primaryColor,
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _essayCtrl.text.trim().isEmpty ? null : _saveAsTemplate,
              child: const Text(AppStrings.cetWritingSaveTemplate),
            ),
          ]),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _resultCard(t, _result!),
          ],
          const SizedBox(height: 20),
          _templatesCard(t),
        ],
      ),
    );
  }

  Widget _resultCard(ThemeData t, Map<String, dynamic> r) {
    final scores = r["scores"] as Map<String, dynamic>? ?? const {};
    final errors = (r["errors"] as List? ?? []).cast<Map<String, dynamic>>();
    final suggestions = (r["suggestions"] as List? ?? []).cast<String>();
    final score = (r["score"] as num?)?.toInt() ?? 0;
    final color = score >= 11 ? Colors.green : score >= 8 ? Colors.orange : Colors.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text("$score", style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 4),
            Text("/ 15", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const Spacer(),
            Text(AppStrings.cetWritingScore,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _scoreBar(t, AppStrings.cetWritingStructure, scores["structure"], 4),
            _scoreBar(t, AppStrings.cetWritingVocabulary, scores["vocabulary"], 4),
            _scoreBar(t, AppStrings.cetWritingGrammar, scores["grammar"], 4),
            _scoreBar(t, AppStrings.cetWritingLogic, scores["logic"], 4),
          ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      AIAnalysisCard(
        title: AppStrings.cetWritingReview,
        icon: Icons.rate_review,
        sections: [
          if (errors.isNotEmpty)
            AISection(
              title: AppStrings.cetWritingErrors,
              content: errors
                  .map((e) => {"original": e["original"], "correct": e["correction"]})
                  .toList(),
              type: "pair",
            ),
          if ((r["optimized"] as String? ?? "").isNotEmpty)
            AISection(
              title: AppStrings.cetWritingOptimized,
              content: r["optimized"] as String,
              type: "text",
            ),
        ],
        tips: suggestions,
        accentColor: Colors.deepOrange,
      ),
    ]);
  }

  Widget _scoreBar(ThemeData t, String label, dynamic value, int max) {
    final v = (value as num?)?.toInt() ?? 0;
    return Column(children: [
      Text("$v/$max", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }

  Widget _templatesCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(AppStrings.cetWritingTemplates,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: _aiTemplateLoading ? null : _aiRecommend,
              icon: _aiTemplateLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: const Text(AppStrings.cetTemplateAi),
            ),
          ]),
          const SizedBox(height: 6),
          if (_templates.isEmpty)
            Text(AppStrings.cetTemplatesEmpty,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
          else
            for (final tpl in _templates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  tpl["is_ai_recommended"] == true
                      ? Icons.auto_awesome
                      : Icons.description_outlined,
                  size: 20,
                  color: tpl["is_ai_recommended"] == true
                      ? AppTheme.accentColor
                      : AppTheme.primaryColor,
                ),
                title: Text(tpl["title"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(tpl["category"] ?? ""),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showTemplate(tpl),
              ),
        ]),
      ),
    );
  }
}
