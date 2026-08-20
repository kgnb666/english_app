import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_coach_service.dart";
import "../widgets/ai_content_renderer.dart";

class CetCoachPage extends StatefulWidget {
  const CetCoachPage({super.key});

  @override
  State<CetCoachPage> createState() => _CetCoachPageState();
}

class _CetCoachPageState extends State<CetCoachPage> {
  final _svc = CetCoachService();
  Map<String, dynamic>? _suggestion;
  Map<String, dynamic>? _profile;
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
      final results = await Future.wait([_svc.getSuggestion(), _svc.getProfile()]);
      if (!mounted) return;
      setState(() {
        _suggestion = results[0];
        _profile = results[1];
      });
    } catch (e) {
      debugPrint("CetCoach load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cetCoachTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.retry,
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _suggestionCard(t),
                      const SizedBox(height: 12),
                      if (_profile != null) _profileCard(t),
                    ],
                  ),
                ),
    );
  }

  Widget _suggestionCard(ThemeData t) {
    final s = _suggestion ?? {};
    final suggestions = (s["suggestions"] as List? ?? []).cast<Map<String, dynamic>>();
    final sections = suggestions.asMap().entries.map((e) {
      final item = e.value;
      return AISection(
        title: "${e.key + 1}. ${item["title"] ?? ""}",
        content: [
          item["detail"] ?? "",
          if ((item["reason"] as String? ?? "").isNotEmpty) "理由：${item["reason"]}",
        ].join("\n"),
        type: "text",
      );
    }).toList();
    return AIAnalysisCard(
      title: AppStrings.cetCoachToday,
      icon: Icons.smart_toy,
      summary: (s["summary"] as String? ?? ""),
      sections: sections,
      tips: const [],
      collapsible: false,
      accentColor: AppTheme.accentColor,
    );
  }

  Widget _profileCard(ThemeData t) {
    final p = _profile!;
    final weak = (p["weak_skills"] as List? ?? []).cast<String>();
    final errors = (p["error_types"] as List? ?? []).cast<Map<String, dynamic>>();
    final history = p["exam_history"] as Map<String, dynamic>? ?? const {};
    final vocab = p["vocabulary_stats"] as Map<String, dynamic>? ?? const {};
    final sections = <AISection>[
      if (weak.isNotEmpty)
        AISection(title: AppStrings.cetCoachWeak, content: weak.map((w) => _weakCn(w)).toList(), type: "list"),
      if (errors.isNotEmpty)
        AISection(
          title: AppStrings.cetCoachErrors,
          content: errors.map((e) => "${e["type"]} ×${e["count"]}").toList(),
          type: "list",
        ),
      AISection(
        title: AppStrings.cetCoachHistory,
        content: [
          "阅读：${_pct(history["reading"])}",
          "听力：${_pct(history["listening"])}",
          "翻译：${_pct(history["translation"])}",
          "口语：${_pct(history["speaking"])}",
        ],
        type: "list",
      ),
      AISection(
        title: AppStrings.cetCoachVocab,
        content: "掌握 ${vocab["mastered"] ?? 0} · 学习中 ${vocab["learning"] ?? 0} · 待复习 ${vocab["review"] ?? 0}",
        type: "text",
      ),
    ];
    return AIAnalysisCard(
      title: AppStrings.cetCoachProfile,
      icon: Icons.person_search,
      sections: sections,
      tips: const [],
      accentColor: AppTheme.primaryColor,
    );
  }

  String _pct(dynamic v) => v == null ? "--" : "$v%";

  String _weakCn(String key) {
    switch (key) {
      case "reading":
        return "阅读";
      case "listening":
        return "听力";
      case "translation":
        return "翻译";
      case "speaking":
        return "口语";
      default:
        return key;
    }
  }
}
