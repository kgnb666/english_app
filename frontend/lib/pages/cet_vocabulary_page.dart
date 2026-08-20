import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/vocab_service.dart";
import "../services/tts_service.dart";
import "../widgets/empty_state_view.dart";

class CetVocabularyPage extends StatefulWidget {
  const CetVocabularyPage({super.key});

  @override
  State<CetVocabularyPage> createState() => _CetVocabularyPageState();
}

class _CetVocabularyPageState extends State<CetVocabularyPage> {
  final _svc = VocabService();
  String _examType = "CET4";
  String? _level;
  List<VocabWordModel> _words = [];
  bool _loading = true;
  String? _error;
  int _total = 0;

  static const _levels = [
    (null, "全部"),
    ("core", "核心词"),
    ("high_freq", "高频词"),
    ("rare_meaning", "熟词僻义"),
    ("error_prone", "易错词"),
  ];

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
      final r = await _svc.getWords(examType: _examType, wordLevel: _level);
      if (!mounted) return;
      setState(() {
        _words = r;
        _total = r.length;
      });
    } catch (e) {
      debugPrint("CetVocabularyPage load error: $e");
      if (mounted) setState(() => _error = AppStrings.loadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _levelCn(String? level) {
    switch (level) {
      case "core":
        return "核心词";
      case "high_freq":
        return "高频词";
      case "rare_meaning":
        return "熟词僻义";
      case "error_prone":
        return "易错词";
      default:
        return "";
    }
  }

  Color _levelColor(String? level) {
    switch (level) {
      case "core":
        return Colors.blue;
      case "high_freq":
        return Colors.orange;
      case "rare_meaning":
        return Colors.purple;
      case "error_prone":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cetVocabularyTitle)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "CET4", label: Text("CET4 四级词汇")),
              ButtonSegment(value: "CET6", label: Text("CET6 六级词汇")),
            ],
            selected: {_examType},
            onSelectionChanged: (s) {
              setState(() => _examType = s.first);
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (key, label) in _levels)
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _level == key,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() => _level = key);
                      _load();
                    },
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildBody(t)),
      ]),
    );
  }

  Widget _buildBody(ThemeData t) {
    if (_error != null) {
      return ErrorRetryView(message: _error!, onRetry: _load);
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return EmptyStateView(
        icon: Icons.menu_book,
        title: AppStrings.noWords,
        subtitle: "$_examType ${_levelCn(_level)}",
        actionLabel: AppStrings.retry,
        onAction: _load,
      );
    }
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _words.length,
            itemBuilder: (_, i) => _buildWordCard(_words[i], t),
          ),
        ),
      ),
      if (_total > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            AppStrings.searchResultCount(_total),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
    ]);
  }

  Widget _buildWordCard(VocabWordModel w, ThemeData t) {
    final level = w.wordLevel;
    final color = _levelColor(level);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push("/vocabulary/detail", extra: w.id).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(w.word, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (w.phonetic != null)
                    Text(w.phonetic!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  if (level != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_levelCn(level),
                          style: TextStyle(fontSize: 10, color: color)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(
                  w.chineseDefinition ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.colorScheme.onSurface.withAlpha(180)),
                ),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 20, color: AppTheme.primaryColor),
              tooltip: AppStrings.pronunciationListen,
              onPressed: () => TtsService.instance.speakWord(w.word, w.audioUrl),
            ),
          ]),
        ),
      ),
    );
  }
}
