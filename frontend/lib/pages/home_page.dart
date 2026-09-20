import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/stats_service.dart";
import "../services/cet_service.dart";
import "package:go_router/go_router.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _svc = StatsService();
  final _cetSvc = CetService();
  DashboardModel? _dash;
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic>? _cetGoal;
  bool _loading = true;
  String? _error;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait(
          [_svc.getDashboard(), _svc.getTodayTasks(), _cetSvc.getDashboard()]);
      _dash = results[0] as DashboardModel;
      _tasks = ((results[1] as Map<String, dynamic>)["tasks"] as List? ?? [])
          .cast<Map<String, dynamic>>();
      _cetGoal = (results[2] as Map<String, dynamic>)["goal"] as Map<String, dynamic>?;
    }
    catch (e) { debugPrint("HomePage load error: $e"); _error = AppStrings.loadFailed; }
    if (!mounted) return;
    setState(()=>_loading=false);
  }

  @override
  Widget build(BuildContext ctx) {
    final t = Theme.of(ctx), d = _dash;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.appName), actions: [IconButton(icon: const Icon(Icons.notifications_outlined), tooltip: AppStrings.reminderSettings, onPressed: () => ctx.push("/reminder"))]),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) ...[
          Material(
            color: t.colorScheme.errorContainer.withAlpha(120),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(Icons.cloud_off_outlined, size: 18, color: t.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(fontSize: 13, color: t.colorScheme.error))),
                TextButton(onPressed: _load, child: Text(AppStrings.retry)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading) const LinearProgressIndicator(),
        _todayCard(t, d), const SizedBox(height: 16),
        _cetCard(t), const SizedBox(height: 16),
        _speakingCard(t), const SizedBox(height: 16),
        _statsCard(t, d), const SizedBox(height: 16),
        _tasksCard(t, d),
      ])),
    );
  }

  Widget _cetCard(ThemeData t) {
    final goal = _cetGoal;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet").then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.cetTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal == null
                        ? AppStrings.cetNoGoalHint
                        : "${goal["exam_type"]} ${goal["target_score"]} 分 · 距考试 ${goal["days_left"]} 天",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _speakingCard(ThemeData t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/pronunciation"),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.record_voice_over, color: AppTheme.accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.pronunciationTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.pronunciationHomeHint,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }

  Widget _todayCard(ThemeData t, DashboardModel? d) {
    final today = d?.today ?? {};
    final pct = d != null ? ((today["study_minutes"]??0)/30).clamp(0.0,1.0) : 0.0;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.whatshot, color: Colors.orange.shade400), const SizedBox(width: 8), Text(AppStrings.todayProgress, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
      const SizedBox(height: 16),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: t.colorScheme.surfaceContainerHighest)),
      const SizedBox(height: 8),
      Text("${today["study_minutes"]??0} / 30 min", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _si(Icons.chat, "${today["chat_messages"]??0}", AppStrings.chatsLabel),
        _si(Icons.book, "${today["words_learned"]??0}", AppStrings.wordsLabel),
        _si(Icons.refresh, "${today["words_reviewed"]??0}", AppStrings.reviewsLabel),
      ]),
    ])));
  }

  Widget _si(IconData i, String v, String l) => Column(children: [Icon(i, size: 24, color: AppTheme.primaryColor), const SizedBox(height: 4), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(l, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]);

  Widget _statsCard(ThemeData t, DashboardModel? d) {
    final total = d?.total ?? {}, words = d?.words ?? {};
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppStrings.learningStats, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _bs(String.fromCharCode(0x1F525), (d?.streakDays??0).toString(), AppStrings.dayStreak),
        _bs(String.fromCharCode(0x1F4DA), ((words["mastered"] as num? ?? 0).toInt()).toString(), AppStrings.wordsMastered),
        _bs(String.fromCharCode(0x23F0), "${(total["study_minutes"] as num? ?? 0).toInt()}m", AppStrings.totalTime),
      ]),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.school, size: 16, color: AppTheme.primaryColor), const SizedBox(width: 8),
          Text("${AppStrings.yourLevel}: ${AppStrings.levelLabel(d?.englishLevel??"beginner")}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
        ])),
    ])));
  }

  Widget _bs(String e, String v, String l) => Column(children: [Text(e, style: const TextStyle(fontSize: 28)), const SizedBox(height: 4), Text("$v", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]);

  Widget _tasksCard(ThemeData t, DashboardModel? d) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(AppStrings.todayTasks, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text(AppStrings.noData, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
        )
      else
        ..._tasks.map((task) => _taskRow(task, t)),
    ])));
  }

  Widget _taskRow(Map<String, dynamic> task, ThemeData t) {
    final type = task["task_type"] as String? ?? "";
    final target = (task["target_count"] as num?)?.toInt() ?? 0;
    final done = (task["completed_count"] as num?)?.toInt() ?? 0;
    final completed = task["status"] == "completed";
    late final IconData icon;
    late final String title;
    late final String route;
    switch (type) {
      case "words":
        icon = Icons.book;
        title = AppStrings.taskWordsDynamic(target);
        route = "/vocabulary";
        break;
      case "ai_minutes":
        icon = Icons.chat;
        title = AppStrings.taskAiDynamic(target);
        route = "/chat";
        break;
      case "reading":
        icon = Icons.article;
        title = AppStrings.taskReadingDynamic(target);
        route = "/reading";
        break;
      case "writing":
        icon = Icons.edit;
        title = AppStrings.taskWritingDynamic(target);
        route = "/writing";
        break;
      default:
        icon = Icons.check_circle_outline;
        title = type;
        route = "/home";
    }
    final pct = target > 0 ? (done / target).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 22, color: completed ? Colors.green : AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
                color: completed ? Colors.green : AppTheme.primaryColor,
              ),
            ),
          ])),
          const SizedBox(width: 12),
          Text(
            AppStrings.taskProgress(done, target),
            style: TextStyle(fontSize: 12, color: completed ? Colors.green : Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Icon(completed ? Icons.check_circle : Icons.circle_outlined, size: 20, color: completed ? Colors.green : Colors.grey.shade400),
        ]),
      ),
    );
  }
}
