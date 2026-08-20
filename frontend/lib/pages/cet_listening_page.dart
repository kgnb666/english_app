import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../l10n/zh_CN.dart";
import "../services/cet_listening_service.dart";

class CetListeningPage extends StatefulWidget {
  const CetListeningPage({super.key});

  @override
  State<CetListeningPage> createState() => _CetListeningPageState();
}

class _CetListeningPageState extends State<CetListeningPage> {
  final _svc = CetListeningService();
  String _examType = "CET4";
  List<Map<String, dynamic>> _items = [];
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
      final items = await _svc.getItems(_examType);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      debugPrint("CetListening load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => FutureBuilder(
        future: _svc.getHistory(),
        builder: (ctx, snap) {
          final items = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(AppStrings.cetListeningHistory,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.cetListeningTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: AppStrings.cetListeningHistory,
            onPressed: _showHistory,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 听力")),
              ButtonSegment(value: "CET6", label: Text("CET6 听力")),
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
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final a = _items[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: Icon(
                                Icons.headphones,
                                color: _examType == "CET6" ? Colors.indigo : Colors.teal,
                              ),
                              title: Text(a["title"] ?? "",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              subtitle: Text("${a["question_count"]} ${AppStrings.cetReadingQuestions}"),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () => context.push("/cet/listening/detail", extra: {
                                "itemId": a["id"],
                                "examType": _examType,
                              }).then((_) => _load()),
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
