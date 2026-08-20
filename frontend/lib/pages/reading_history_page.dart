import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/reading_service.dart";
import "../widgets/reading_result_view.dart";
import "../widgets/empty_state_view.dart";

/// 阅读历史：文章列表 + 删除
class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  final _svc = ReadingService();
  List<ReadingHistoryItem> _items = [];
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
      final items = await _svc.getHistory();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      debugPrint("ReadingHistory load error: $e");
      if (!mounted) return;
      setState(() => _error = AppStrings.loadHistoryFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(ReadingHistoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.confirmDelete),
        content: Text(AppStrings.confirmDeleteHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRecord(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.deleted)));
    } catch (e) {
      debugPrint("ReadingHistory delete error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.deleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.readingHistory)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(t)
                : _items.isEmpty
                    ? _buildEmpty(t)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _buildCard(_items[i], t),
                      ),
      ),
    );
  }

  Widget _buildCard(ReadingHistoryItem item, ThemeData t) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.article_outlined, color: AppTheme.primaryColor),
          title: Text(item.articlePreview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            "${item.summaryCn.isEmpty ? AppStrings.noSummary : item.summaryCn}\n${item.createdAt.substring(0, 16)}",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          isThreeLine: true,
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: AppStrings.delete, onPressed: () => _delete(item)),
          onTap: () => context.push("/reading/history/detail", extra: item.id),
        ),
      );

  Widget _buildEmpty(ThemeData t) => EmptyStateView(
        icon: Icons.history,
        title: AppStrings.noReadingHistory,
        subtitle: AppStrings.noReadingHistoryHint,
        actionLabel: AppStrings.backToReading,
        onAction: () => context.pop(),
      );

  Widget _buildError(ThemeData t) => ErrorRetryView(message: _error!, onRetry: _load);
}

/// 阅读历史详情：原文 + AI 分析结果
class ReadingHistoryDetailPage extends StatefulWidget {
  final String recordId;
  const ReadingHistoryDetailPage({super.key, required this.recordId});

  @override
  State<ReadingHistoryDetailPage> createState() => _ReadingHistoryDetailPageState();
}

class _ReadingHistoryDetailPageState extends State<ReadingHistoryDetailPage> {
  final _svc = ReadingService();
  ReadingHistoryDetail? _detail;
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
      final detail = await _svc.getHistoryDetail(widget.recordId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      debugPrint("ReadingHistory detail error: $e");
      if (!mounted) return;
      setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text("")), body: const Center(child: CircularProgressIndicator()));
    }
    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("")),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_error ?? AppStrings.noData, style: TextStyle(color: t.colorScheme.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: Text(AppStrings.retry)),
          ]),
        ),
      );
    }
    final d = _detail!;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.readingHistoryDetail)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.description_outlined, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(AppStrings.originalArticle, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Text(d.articleContent, style: const TextStyle(fontSize: 14, height: 1.7)),
                  const SizedBox(height: 8),
                  Text(d.createdAt.substring(0, 16), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ReadingResultView(result: d.result),
        ],
      ),
    );
  }
}
