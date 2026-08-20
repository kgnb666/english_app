import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/stats_service.dart";
import "../widgets/empty_state_view.dart";

/// 学习统计：周学习时间、月度统计、学习日历、单词趋势
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _svc = StatsService();
  DashboardModel? _dash;
  List<Map<String, dynamic>> _weekly = [];
  Map<String, dynamic>? _monthly;
  List<Map<String, dynamic>> _calendar = [];
  late int _year;
  late int _month;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _svc.getDashboard(),
        _svc.getWeekly(),
        _svc.getMonthly(_year, _month),
        _svc.getCalendar(_year, _month),
      ]);
      if (!mounted) return;
      setState(() {
        _dash = results[0] as DashboardModel;
        _weekly = (results[1] as List).cast<Map<String, dynamic>>();
        _monthly = results[2] as Map<String, dynamic>;
        _calendar = (results[3] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("StatsPage load error: $e");
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMonth(int delta) async {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    setState(() {
      _month = m;
      _year = y;
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _svc.getMonthly(_year, _month),
        _svc.getCalendar(_year, _month),
      ]);
      if (!mounted) return;
      setState(() {
        _monthly = results[0] as Map<String, dynamic>;
        _calendar = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("StatsPage month error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _isEmpty {
    if (_dash == null) return false;
    final minutes = _weekly.fold<int>(
        0, (sum, d) => sum + ((d["study_minutes"] as num?)?.toInt() ?? 0));
    final words = _weekly.fold<int>(
        0, (sum, d) => sum + ((d["words_learned"] as num?)?.toInt() ?? 0));
    return minutes == 0 && words == 0;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.statsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
              ? ErrorRetryView(message: AppStrings.loadFailed, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _isEmpty ? _buildEmpty(t) : _buildContent(t),
                ),
    );
  }

  Widget _buildEmpty(ThemeData t) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: EmptyStateView(
              icon: Icons.insights_outlined,
              title: AppStrings.noStatsData,
              subtitle: AppStrings.noStatsHint,
              actionLabel: AppStrings.goStudy,
              onAction: () => context.go("/vocabulary"),
            ),
          ),
        ],
      );

  Widget _buildContent(ThemeData t) {
    final d = _dash!;
    final weekMinutes = _weekly.fold<int>(
        0, (sum, x) => sum + ((x["study_minutes"] as num?)?.toInt() ?? 0));
    final weekWords = _weekly.fold<int>(
        0, (sum, x) => sum + ((x["words_learned"] as num?)?.toInt() ?? 0));
    final weekAi = _weekly.fold<int>(
        0, (sum, x) => sum + ((x["ai_minutes"] as num?)?.toInt() ?? 0));
    final weekReading = _weekly.fold<int>(
        0, (sum, x) => sum + ((x["reading_count"] as num?)?.toInt() ?? 0));
    final weekWriting = _weekly.fold<int>(
        0, (sum, x) => sum + ((x["writing_count"] as num?)?.toInt() ?? 0));
    final todayMinutes = ((d.today["study_minutes"] as num?) ?? 0).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          _metricCard(t, Icons.local_fire_department, "${d.streakDays}",
              AppStrings.dayStreak, Colors.orange),
          const SizedBox(width: 12),
          _metricCard(t, Icons.schedule, "$weekMinutes",
              AppStrings.weeklyTime, AppTheme.primaryColor),
          const SizedBox(width: 12),
          _metricCard(t, Icons.menu_book, "$weekWords",
              AppStrings.weeklyWords, Colors.green),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _metricCard(t, Icons.smart_toy_outlined, "$weekAi",
              AppStrings.aiTime, Colors.indigo),
          const SizedBox(width: 12),
          _metricCard(t, Icons.article_outlined, "$weekReading",
              AppStrings.readingCount, Colors.teal),
          const SizedBox(width: 12),
          _metricCard(t, Icons.edit_outlined, "$weekWriting",
              AppStrings.writingCount, Colors.purple),
        ]),
        const SizedBox(height: 16),
        _weeklyTimeCard(t, todayMinutes, d),
        const SizedBox(height: 16),
        _wordsTrendCard(t, d),
        const SizedBox(height: 16),
        _monthlyCard(t),
        const SizedBox(height: 16),
        _calendarCard(t),
      ],
    );
  }

  Widget _weeklyTimeCard(ThemeData t, int todayMinutes, DashboardModel d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.weeklyTime,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            AppStrings.todayProgress,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _niceMax(
                    _weekly.map((x) => (x["study_minutes"] as num?)?.toInt() ?? 0).toList()),
                barTouchData: const BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: _titles(t, (i) => _dayLabel(i)),
                barGroups: _weekly.asMap().entries.map((e) {
                  final v = ((e.value["study_minutes"] as num?) ?? 0).toDouble();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: 18,
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              "${AppStrings.totalTime}: ${d.total["study_minutes"] ?? 0} ${AppStrings.dailyMinutes} 路 ${AppStrings.todayProgress}: $todayMinutes ${AppStrings.dailyMinutes}",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _wordsTrendCard(ThemeData t, DashboardModel d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppStrings.wordsTrend,
              style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _niceMax(
                    _weekly.map((x) => (x["words_learned"] as num?)?.toInt() ?? 0).toList()),
                barTouchData: const BarTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: _titles(t, (i) => _dayLabel(i)),
                barGroups: _weekly.asMap().entries.map((e) {
                  final v = ((e.value["words_learned"] as num?) ?? 0).toDouble();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: 18,
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.menu_book, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              "${AppStrings.wordsLabel}: ${d.total["words_learned"] ?? 0}",
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _monthlyCard(ThemeData t) {
    final total = _monthly?["total"] as Map<String, dynamic>? ?? const {};
    final studyDays = (total["study_days"] as num?)?.toInt() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(AppStrings.monthlyStats,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => _changeMonth(-1),
              visualDensity: VisualDensity.compact,
            ),
            Text("$_year 年 $_month 月",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => _changeMonth(1),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _monthlyStat(t, Icons.schedule, "${total["study_minutes"] ?? 0}",
                AppStrings.dailyMinutes, AppTheme.primaryColor),
            _monthlyStat(t, Icons.smart_toy_outlined, "${total["ai_minutes"] ?? 0}",
                AppStrings.aiTime, Colors.indigo),
            _monthlyStat(t, Icons.menu_book, "${total["words_learned"] ?? 0}",
                AppStrings.wordsLabel, Colors.green),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _monthlyStat(t, Icons.article_outlined, "${total["reading_count"] ?? 0}",
                AppStrings.readingCount, Colors.teal),
            _monthlyStat(t, Icons.edit_outlined, "${total["writing_count"] ?? 0}",
                AppStrings.writingCount, Colors.purple),
            _monthlyStat(t, Icons.local_fire_department, "$studyDays",
                AppStrings.studiedDays, Colors.orange),
          ]),
        ]),
      ),
    );
  }

  Widget _monthlyStat(ThemeData t, IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }

  Widget _calendarCard(ThemeData t) {
    final days = _calendar;
    final studied = days.where((x) => x["studied"] == true).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(AppStrings.calendarTitle,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(
              "$studied ${AppStrings.studiedDays}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    ["一", "二", "三", "四", "五", "六", "日"][i - 1],
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          _buildCalendarGrid(t, days),
          if (studied == 0) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                AppStrings.noStudyThisMonth,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData t, List<Map<String, dynamic>> days) {
    final first = DateTime(_year, _month, 1);
    final leading = first.weekday - 1; // 周一为首列
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox(),
      for (var i = 0; i < days.length; i++) _dayCell(t, days[i]),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    return Column(children: [
      for (var row = 0; row < cells.length ~/ 7; row++)
        Row(children: [
          for (var col = 0; col < 7; col++) Expanded(child: cells[row * 7 + col]),
        ]),
    ]);
  }

  Widget _dayCell(ThemeData t, Map<String, dynamic> day) {
    final dateStr = day["date"] as String? ?? "";
    final dayNum = int.tryParse(dateStr.length >= 10 ? dateStr.substring(8, 10) : "") ?? 0;
    final minutes = (day["study_minutes"] as num?)?.toInt() ?? 0;
    final studied = day["studied"] == true;
    final intensity = minutes == 0 ? 0.0 : (0.25 + (minutes / 60).clamp(0.0, 0.75));
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: studied
                ? Color.lerp(t.colorScheme.surfaceContainerHighest, AppTheme.primaryColor, intensity)
                : t.colorScheme.surfaceContainerHighest.withAlpha(90),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "$dayNum",
            style: TextStyle(
              fontSize: 12,
              fontWeight: studied ? FontWeight.w600 : FontWeight.w400,
              color: studied && intensity > 0.55 ? Colors.white : t.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard(ThemeData t, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }

  double _niceMax(List<int> values) {
    final m = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (m <= 0) return 1;
    return (m * 1.2).ceilToDouble();
  }

  String _dayLabel(int index) {
    const labels = ["一", "二", "三", "四", "五", "六", "日"];
    return labels[index % 7];
  }

  FlTitlesData _titles(ThemeData t, String Function(int) label) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) => Text(
            value.toInt().toString(),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (value, meta) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label(value.toInt()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ),
      ),
    );
  }
}
