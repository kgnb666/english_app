import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_reading_service.dart";
import "../widgets/empty_state_view.dart";

class CetReadingPage extends StatefulWidget {
  const CetReadingPage({super.key});

  @override
  State<CetReadingPage> createState() => _CetReadingPageState();
}

class _CetReadingPageState extends State<CetReadingPage> {
  final _svc = CetReadingService();
  String _examType = "CET4";
  List<Map<String, dynamic>> _articles = [];
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
      final articles = await _svc.getArticles(_examType);
      if (!mounted) return;
      setState(() => _articles = articles);
    } catch (e) {
      debugPrint("CetReadingPage load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ReadingHistorySheet(svc: _svc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cetReadingTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppStrings.readingHistory,
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 阅读")),
              ButtonSegment(value: "CET6", label: Text("CET6 阅读")),
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
                  ? ErrorRetryView(message: _error!, onRetry: _load)
                  : _articles.isEmpty
                      ? EmptyStateView(
                          icon: Icons.article_outlined,
                          title: AppStrings.noReadingHistory,
                          subtitle: AppStrings.noReadingHistoryHint,
                          actionLabel: AppStrings.retry,
                          onAction: _load,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _articles.length,
                            itemBuilder: (_, i) => _articleCard(_articles[i], t),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _articleCard(Map<String, dynamic> a, ThemeData t) {
    final isCet6 = _examType == "CET6";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/cet/reading/article", extra: {
          "articleId": a["id"],
          "examType": _examType,
        }).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isCet6 ? Colors.indigo : Colors.teal).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.article, color: isCet6 ? Colors.indigo : Colors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a["title"] ?? "",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  "${a["question_count"]} ${AppStrings.cetReadingQuestions}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

/// 阅读历史底部弹窗
class _ReadingHistorySheet extends StatefulWidget {
  final CetReadingService svc;
  const _ReadingHistorySheet({required this.svc});

  @override
  State<_ReadingHistorySheet> createState() => _ReadingHistorySheetState();
}

class _ReadingHistorySheetState extends State<_ReadingHistorySheet> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.svc.getHistory();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      debugPrint("CetReading history error: $e");
      if (mounted) setState(() => _items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => _items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                Text(AppStrings.readingHistory,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                if (_items!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(AppStrings.noReadingHistory)),
                  )
                else
                  for (final h in _items!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(h["title"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text("${h["exam_type"]} · ${h["score"]}/${h["total"]}"),
                      trailing: Text("${h["accuracy"]}%",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: (h["accuracy"] as num? ?? 0) >= 60
                                ? Colors.green
                                : Colors.orange,
                          )),
                    ),
              ],
            ),
    );
  }
}
