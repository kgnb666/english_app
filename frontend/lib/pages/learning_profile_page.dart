import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/profile_service.dart";

class LearningProfilePage extends StatefulWidget {
  const LearningProfilePage({super.key});

  @override
  State<LearningProfilePage> createState() => _LearningProfilePageState();
}

class _LearningProfilePageState extends State<LearningProfilePage> {
  final _svc = ProfileService();
  final _goalCtrl = TextEditingController();
  final _vocabCtrl = TextEditingController();
  final _topicsCtrl = TextEditingController();
  List<ErrorLogItem> _errors = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _level = "beginner";
  final Set<String> _skills = {};
  final Set<String> _focus = {};

  static const _skillOptions = [
    ("口语", "speaking"),
    ("听力", "listening"),
    ("阅读", "reading"),
    ("写作", "writing"),
    ("语法", "grammar"),
    ("发音", "pronunciation"),
    ("词汇", "vocabulary"),
  ];
  static const _focusOptions = ["口语", "听力", "阅读", "写作", "语法", "词汇"];
  static const _levels = [
    "beginner",
    "elementary",
    "intermediate",
    "upper_intermediate",
    "advanced",
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _vocabCtrl.dispose();
    _topicsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_svc.getProfile(), _svc.getErrors()]);
      if (!mounted) return;
      final p = results[0] as LearningProfile;
      _level = p.englishLevel;
      _goalCtrl.text = p.goal ?? "";
      _vocabCtrl.text = p.vocabularySize > 0 ? "${p.vocabularySize}" : "";
      final prefs = p.preferences;
      final focus = (prefs["focus"] as List? ?? []).map((e) => e.toString()).toList();
      final topics = (prefs["topics"] as List? ?? []).map((e) => e.toString()).toList();
      _focus
        ..clear()
        ..addAll(focus.where(_focusOptions.contains));
      _topicsCtrl.text = topics.join("，");
      _skills
        ..clear()
        ..addAll(_skillOptions
            .where((s) => p.weakSkills.contains(s.$2))
            .map((s) => s.$2));
      _errors = (results[1] as List).cast<ErrorLogItem>();
    } catch (e) {
      debugPrint("LearningProfilePage load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final topics = _topicsCtrl.text
          .split(RegExp(r"[，,、]"))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await _svc.updateProfile({
        "english_level": _level,
        "goal": _goalCtrl.text.trim().isEmpty ? null : _goalCtrl.text.trim(),
        "vocabulary_size": int.tryParse(_vocabCtrl.text) ?? 0,
        "weak_skills": _skills.toList(),
        "preferences": {
          "focus": _focus.toList(),
          "topics": topics,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileSaved),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      debugPrint("LearningProfilePage save error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profileSaveFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteError(ErrorLogItem item) async {
    try {
      await _svc.deleteError(item.id);
      if (!mounted) return;
      setState(() => _errors.removeWhere((e) => e.id == item.id));
    } catch (e) {
      debugPrint("LearningProfilePage delete error: $e");
    }
  }

  void _pickLevel() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              AppStrings.selectLevel,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          for (final l in _levels)
            ListTile(
              title: Text(AppStrings.levelLabel(l)),
              trailing: _level == l
                  ? const Icon(Icons.check, color: AppTheme.primaryColor)
                  : null,
              onTap: () {
                setState(() => _level = l);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.learningProfile),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text(AppStrings.retry)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _basicCard(t),
                      const SizedBox(height: 12),
                      _skillsCard(t),
                      const SizedBox(height: 12),
                      _prefsCard(t),
                      const SizedBox(height: 12),
                      _errorsCard(t),
                    ],
                  ),
                ),
    );
  }

  Widget _basicCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(t, AppStrings.profileBasic),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school, color: AppTheme.primaryColor),
            title: const Text(AppStrings.englishLevel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.levelLabel(_level),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _pickLevel,
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          TextField(
            controller: _goalCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.profileGoal,
              hintText: AppStrings.profileGoalHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vocabCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.profileVocabulary,
              suffixText: AppStrings.planUnitWords,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _skillsCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(t, AppStrings.profileWeakSkills),
          const SizedBox(height: 4),
          Text(
            AppStrings.profileWeakSkillsHint,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, key) in _skillOptions)
                ChoiceChip(
                  label: Text(label),
                  selected: _skills.contains(key),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _skills.add(key);
                    } else {
                      _skills.remove(key);
                    }
                  }),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _prefsCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle(t, AppStrings.profilePreferences),
          const SizedBox(height: 4),
          Text(
            AppStrings.profileFocusHint,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in _focusOptions)
                FilterChip(
                  label: Text(label),
                  selected: _focus.contains(label),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _focus.add(label);
                    } else {
                      _focus.remove(label);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicsCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.profileTopics,
              hintText: AppStrings.profileTopicsHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errorsCard(ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _sectionTitle(t, AppStrings.profileErrors)),
            Text(
              AppStrings.profileErrorsHint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ]),
          const SizedBox(height: 8),
          if (_errors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  AppStrings.profileNoErrors,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            for (final e in _errors) _errorRow(e, t),
        ]),
      ),
    );
  }

  Widget _errorRow(ErrorLogItem e, ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: t.colorScheme.onSurface),
                    children: [
                      TextSpan(
                        text: e.wrongText,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.red,
                        ),
                      ),
                      const TextSpan(text: "  →  "),
                      TextSpan(
                        text: e.correctText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${e.errorTypeCn} ×${e.count}",
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.grey.shade500,
            visualDensity: VisualDensity.compact,
            onPressed: () => _deleteError(e),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData t, String title) => Text(
        title,
        style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      );
}
