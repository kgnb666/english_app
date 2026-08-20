import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_service.dart";
import "../services/api_service.dart";
import "../widgets/empty_state_view.dart";

class CetStudyPage extends StatefulWidget {
  const CetStudyPage({super.key});

  @override
  State<CetStudyPage> createState() => _CetStudyPageState();
}

class _CetStudyPageState extends State<CetStudyPage> {
  final _svc = CetService();
  Map<String, dynamic>? _data;
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
      final data = await _svc.getDashboard();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      debugPrint("CetStudyPage load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showGoalDialog() async {
    final formKey = GlobalKey<FormState>();
    final scoreCtrl = TextEditingController(text: "500");
    final minutesCtrl = TextEditingController(text: "30");
    String examType = "CET4";
    DateTime? examDate = DateTime.now().add(const Duration(days: 90));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(AppStrings.cetSetGoal),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "CET4", label: Text("CET4 四级")),
                      ButtonSegment(value: "CET6", label: Text("CET6 六级")),
                    ],
                    selected: {examType},
                    onSelectionChanged: (s) => setDialogState(() => examType = s.first),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: scoreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.cetTargetScore,
                      helperText: "425 - 710",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? "");
                      if (n == null || n < 425 || n > 710) return AppStrings.cetScoreInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: AppStrings.cetDailyMinutes,
                      suffixText: AppStrings.dailyMinutes,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? "");
                      if (n == null || n < 10 || n > 240) return AppStrings.cetMinutesInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: AppTheme.primaryColor),
                    title: Text(AppStrings.cetExamDate),
                    subtitle: Text(
                      "${examDate!.year}-${examDate!.month.toString().padLeft(2, "0")}-${examDate!.day.toString().padLeft(2, "0")}",
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: examDate,
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setDialogState(() => examDate = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final dateStr = "${examDate!.year}-${examDate!.month.toString().padLeft(2, "0")}-${examDate!.day.toString().padLeft(2, "0")}";
                Navigator.pop(ctx);
                await _svc.setGoal(
                  examType: examType,
                  targetScore: int.parse(scoreCtrl.text),
                  examDate: dateStr,
                  dailyMinutes: int.parse(minutesCtrl.text),
                );
                _load();
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelGoal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.cetCancelGoal),
        content: const Text(AppStrings.cetCancelHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.confirm, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _svc.cancelGoal();
        _load();
      } catch (e) {
        debugPrint("Cet cancel error: $e");
        ApiService.showError(AppStrings.operationFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cetTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _data?["goal"] == null ? _buildNoGoal(t) : _buildContent(t),
                ),
    );
  }

  Widget _buildNoGoal(ThemeData t) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: EmptyStateView(
            icon: Icons.emoji_events_outlined,
            title: AppStrings.cetNoGoal,
            subtitle: AppStrings.cetNoGoalHint,
            actionLabel: AppStrings.cetSetGoal,
            onAction: _showGoalDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData t) {
    final goal = _data!["goal"] as Map<String, dynamic>;
    final phases = (_data!["phases"] as List? ?? []).cast<Map<String, dynamic>>();
    final progress = _data!["progress"] as Map<String, dynamic>? ?? const {};
    final tasks = ((_data!["today_tasks"] as Map<String, dynamic>?)?["tasks"] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final currentPhase = _data!["current_phase"] as int?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _coachEntryCard(t),
        const SizedBox(height: 12),
        _goalCard(t, goal),
        const SizedBox(height: 12),
        _vocabEntryCard(t),
        const SizedBox(height: 12),
        _readingEntryCard(t),
        const SizedBox(height: 12),
        _writingEntryCard(t),
        const SizedBox(height: 12),
        _translationEntryCard(t),
        const SizedBox(height: 12),
        _listeningEntryCard(t),
        const SizedBox(height: 12),
        _speakingEntryCard(t),
        const SizedBox(height: 12),
        _progressCard(t, progress),
        const SizedBox(height: 12),
        _planCard(t, phases, currentPhase),
        const SizedBox(height: 12),
        _todayTasksCard(t, tasks),
      ],
    );
  }

  Widget _goalCard(ThemeData t, Map<String, dynamic> goal) {
    final isCet6 = goal["exam_type"] == "CET6";
    final color = isCet6 ? Colors.indigo : Colors.teal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                goal["exam_type"] as String,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${AppStrings.cetTargetScore}: ${goal["target_score"]}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _cancelGoal,
              child: Text(AppStrings.cetCancelGoal, style: TextStyle(fontSize: 12, color: t.colorScheme.error)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _goalItem(t, AppStrings.cetExamDate, goal["exam_date"]),
            _goalItem(t, AppStrings.cetDaysLeftLabel, "${goal["days_left"]} 天"),
            _goalItem(t, AppStrings.cetDailyMinutes, "${goal["daily_minutes"]} 分"),
          ]),
        ]),
      ),
    );
  }

  Widget _goalItem(ThemeData t, String label, String value) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]);

  Widget _coachEntryCard(ThemeData t) {
    return Card(
      color: AppTheme.accentColor.withAlpha(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/coach"),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: AppTheme.accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetCoachEntry,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(AppStrings.cetCoachHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _vocabEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/vocabulary"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book, color: Colors.indigo),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetVocabularyEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetVocabularyHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _readingEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/reading"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetReadingEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetReadingHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _writingEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/writing"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_note, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetWritingEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetWritingHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _translationEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/translation"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.translate, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetTranslationEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetTranslationHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _listeningEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/listening"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.headphones, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetListeningEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetListeningHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _speakingEntryCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/speaking"),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pink.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.record_voice_over, color: Colors.pink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppStrings.cetSpeakingEntry,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(AppStrings.cetSpeakingHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _progressCard(ThemeData t, Map<String, dynamic> progress) {
    final done = (progress["phase_done"] as num?)?.toInt() ?? 0;
    final total = (progress["total_phases"] as num?)?.toInt() ?? 4;
    final daysTotal = (progress["days_total"] as num?)?.toInt() ?? 0;
    final daysElapsed = (progress["days_elapsed"] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? done / total : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.cetProgress, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              color: AppTheme.primaryColor,
              backgroundColor: t.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${AppStrings.cetPhaseProgress(done, total)} · ${AppStrings.cetDayProgress(daysElapsed, daysTotal)}",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ]),
      ),
    );
  }

  Widget _planCard(ThemeData t, List<Map<String, dynamic>> phases, int? currentPhase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.cetPlan, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final p in phases) _phaseRow(p, p["phase"] == currentPhase, t),
        ]),
      ),
    );
  }

  Widget _phaseRow(Map<String, dynamic> p, bool isCurrent, ThemeData t) {
    final status = p["status"] as String? ?? "upcoming";
    final color = status == "done"
        ? Colors.green
        : status == "active"
            ? AppTheme.primaryColor
            : Colors.grey;
    final subtitle = [
      if ((p["daily_words"] as num? ?? 0) > 0) "词${p["daily_words"]}",
      if ((p["daily_reading"] as num? ?? 0) > 0) "阅读${p["daily_reading"]}篇",
      if ((p["daily_listening_minutes"] as num? ?? 0) > 0) "听${p["daily_listening_minutes"]}分",
      if ((p["daily_writing_minutes"] as num? ?? 0) > 0) "写${p["daily_writing_minutes"]}分",
    ].join(" · ");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: status == "done"
              ? Icon(Icons.check, size: 16, color: Colors.green.shade600)
              : Text("${p["phase"]}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("阶段${p["phase"]} · ${p["phase_name"]}",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(18), borderRadius: BorderRadius.circular(8)),
                  child: const Text("当前", style: TextStyle(fontSize: 10, color: AppTheme.primaryColor)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(p["focus"] as String? ?? "", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: TextStyle(fontSize: 11, color: color.withAlpha(180))),
          ]),
        ),
      ]),
    );
  }

  Widget _todayTasksCard(ThemeData t, List<Map<String, dynamic>> tasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.cetTodayTasks, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Text(AppStrings.noData, style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
          else
            for (final task in tasks) _taskRow(task, t),
        ]),
      ),
    );
  }

  Widget _taskRow(Map<String, dynamic> task, ThemeData t) {
    final type = task["task_type"] as String? ?? "";
    final target = (task["target_count"] as num?)?.toInt() ?? 0;
    final done = (task["completed_count"] as num?)?.toInt() ?? 0;
    final completed = task["status"] == "completed";
    final (icon, label) = switch (type) {
      "words" => (Icons.book, AppStrings.taskWordsDynamic(target)),
      "reading" => (Icons.article, AppStrings.taskReadingDynamic(target)),
      "ai_minutes" => (Icons.chat, AppStrings.taskAiDynamic(target)),
      "writing" => (Icons.edit, AppStrings.taskWritingDynamic(target)),
      _ => (Icons.check_circle_outline, type),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: completed ? Colors.green : AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(AppStrings.taskProgress(done, target),
            style: TextStyle(fontSize: 12, color: completed ? Colors.green : Colors.grey.shade600)),
        const SizedBox(width: 8),
        Icon(completed ? Icons.check_circle : Icons.circle_outlined,
            size: 18, color: completed ? Colors.green : Colors.grey.shade400),
      ]),
    );
  }
}
