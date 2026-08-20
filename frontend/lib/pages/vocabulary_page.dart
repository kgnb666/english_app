import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../l10n/zh_CN.dart";
import "../services/vocab_service.dart";
import "../services/study_session_service.dart";
import "../services/api_service.dart";
import "../services/tts_service.dart";
import "../config/theme.dart";
import "../widgets/empty_state_view.dart";

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});
  @override State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> with SingleTickerProviderStateMixin {
  final _svc = VocabService();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  late final TabController _tabCtrl;
  List<VocabWordModel> _words = [];
  VocabSummaryModel? _summary;
  bool _loading = true;
  bool _loadingMore = false;
  String _search = "";
  String? _error;
  Timer? _debounce;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  int _loadSeq = 0;
  List<String> _recentSearches = [];
  SharedPreferences? _prefs;

  static const _recentKey = "recent_searches";

  static final _tabs = [
    {"label": AppStrings.allWords, "key": null},
    {"label": AppStrings.newWords, "key": "new"},
    {"label": AppStrings.learning, "key": "learning"},
    {"label": AppStrings.toReview, "key": "review"},
    {"label": AppStrings.mastered, "key": "mastered"},
    {"label": AppStrings.wordBook, "key": "bookmarks"},
  ];

  @override
  void initState() {
    super.initState();
    StudySessionService.instance.start("words");
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _scroll.addListener(_onScroll);
    _loadRecent();
    _load();
  }

  @override
  void dispose() {
    StudySessionService.instance.end("words");
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  /// 竞态防护：仅最新一次请求的结果允许写入
  Future<void> _load({bool reset = true}) async {
    final seq = ++_loadSeq;
    if (reset) {
      _page = 1;
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final status = _tabs[_tabCtrl.index]["key"];
      List<VocabWordModel> items;
      int total;
      if (status == "bookmarks") {
        final list = await _svc.getBookmarks();
        items = list;
        total = list.length;
      } else if (status != null) {
        final list = await _svc.getMyProgress(status: status);
        items = list;
        total = list.length;
      } else {
        final r = await _svc.getWordsPage(search: _search, page: _page);
        items = r.$1;
        total = r.$2;
      }
      if (seq != _loadSeq || !mounted) return;

      if (reset) {
        _words = items;
      } else {
        final existing = _words.map((w) => w.id).toSet();
        _words.addAll(items.where((w) => !existing.contains(w.id)));
      }
      _total = total;
      _hasMore = _words.length < total;

      // 空词库自动播种（仅全部 tab 且未搜索时）
      if (items.isEmpty && _tabCtrl.index == 0 && _search.isEmpty) {
        try {
          await ApiService().dio.post("/vocabulary/seed");
          final r = await _svc.getWordsPage(search: _search, page: 1);
          if (seq != _loadSeq || !mounted) return;
          _words = r.$1;
          _total = r.$2;
          _hasMore = false;
        } catch (e) {
          debugPrint("Vocabulary seed error: $e");
        }
      }

      _summary = await _svc.getSummary();
      unawaited(_preloadAudio());
    } catch (e) {
      debugPrint("VocabularyPage load error: $e");
      if (seq == _loadSeq && mounted) {
        setState(() => _error = AppStrings.loadFailed);
      }
    } finally {
      if (seq == _loadSeq && mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final status = _tabs[_tabCtrl.index]["key"];
    if (status != null || !_hasMore || _loadingMore || _loading) return;
    _page += 1;
    await _load(reset: false);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = value.trim();
      setState(() => _search = q);
      _saveRecent(q);
      _load();
    });
  }

  Future<void> _loadRecent() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _recentSearches = _prefs?.getStringList(_recentKey) ?? [];
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("VocabularyPage recent load error: $e");
    }
  }

  void _saveRecent(String q) {
    if (q.isEmpty) return;
    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.sublist(0, 8);
    }
    _prefs?.setStringList(_recentKey, _recentSearches);
    if (mounted) setState(() {});
  }

  void _applyRecent(String q) {
    _searchCtrl.text = q;
    _searchCtrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _search = q);
    _load();
  }

  /// 预加载当前列表音频：有固定音频的直接预载；没有的后台生成绑定后预载
  Future<void> _preloadAudio() async {
    final withUrl = _words
        .where((w) => w.audioUrl != null && w.audioUrl!.isNotEmpty)
        .take(10)
        .map((w) => w.audioUrl!)
        .toList();
    if (withUrl.isNotEmpty) {
      await TtsService.instance.preloadUrls(withUrl);
    }
    final noUrl = _words
        .where((w) => w.audioUrl == null || w.audioUrl!.isEmpty)
        .take(10)
        .toList();
    var inflight = 0;
    for (final w in noUrl) {
      while (inflight >= 3) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      inflight += 1;
      unawaited(() async {
        try {
          final r = await _svc.ensureAudio(w.id);
          final url = r["audio_url"] as String?;
          if (url != null && url.isNotEmpty) {
            await TtsService.instance.preloadUrls([url]);
          }
        } catch (e) {
          debugPrint("VocabularyPage ensureAudio error: $e");
        } finally {
          inflight -= 1;
        }
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isAllTab = _tabCtrl.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.vocabulary),
        actions: [
          IconButton(icon: const Icon(Icons.quiz_outlined), tooltip: AppStrings.quizTitle, onPressed: () => context.push("/quiz")),
        ],
        bottom: TabBar(controller: _tabCtrl, isScrollable: true, tabAlignment: TabAlignment.start, tabs: _tabs.map((tb) => Tab(text: tb["label"] as String)).toList()),
      ),
      body: Column(children: [
        // 搜索仅"全部"tab 生效
        if (isAllTab) _buildSearchArea(t),
        if (_summary != null) _buildSummaryBar(_summary!, t),
        if (_summary != null) _buildStatsRow(_summary!, t),
        Expanded(child: _buildBody(t)),
      ]),
    );
  }

  Widget _buildSearchArea(ThemeData t) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: AppStrings.searchWordsCn,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _onSearchChanged(""); }),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      if (_recentSearches.isNotEmpty && _search.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final q in _recentSearches)
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _applyRecent(q),
                  ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildBody(ThemeData t) {
    if (_error != null && _words.isEmpty) {
      return ErrorRetryView(message: _error!, onRetry: _load);
    }
    if (_loading && _words.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return _buildEmpty(t);
    }
    return Column(children: [
      if (_loading || _loadingMore)
        const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _words.length + (_hasMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _words.length) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return _buildWordCard(_words[i], t);
            },
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

  Widget _buildSummaryBar(VocabSummaryModel s, ThemeData t) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: t.colorScheme.surfaceContainerHighest.withAlpha(80), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    _chip(t, AppStrings.newWords, s.newCount, Colors.blue), _chip(t, AppStrings.learning, s.learning, Colors.orange), _chip(t, AppStrings.toReview, s.review, Colors.purple), _chip(t, AppStrings.mastered, s.mastered, Colors.green), _chip(t, AppStrings.todayReview, s.todayReview, Colors.red),
  ]));

  Widget _buildStatsRow(VocabSummaryModel s, ThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(children: [
          _stat(t, AppStrings.learnedCount, s.learnedCount, Colors.indigo),
          _stat(t, AppStrings.masteredCount, s.masteredCount, Colors.green),
          _stat(t, AppStrings.reviewCountLabel, s.reviewCount, AppTheme.primaryColor),
          _stat(t, AppStrings.errorCountLabel, s.errorCount, Colors.orange),
        ]),
      );

  Widget _stat(ThemeData t, String label, int value, Color color) => Expanded(
        child: Column(children: [
          Text("$value",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
      );

  Widget _chip(ThemeData t, String label, int count, Color color) => Column(children: [Text("$count", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)), Text(label, style: TextStyle(fontSize: 11, color: t.colorScheme.onSurface.withAlpha(150)))]);

  Widget _buildEmpty(ThemeData t) {
    final isBook = _tabs[_tabCtrl.index]["key"] == "bookmarks";
    if (_search.isNotEmpty) {
      return EmptyStateView(
        icon: Icons.search_off,
        title: AppStrings.searchNoResult,
        subtitle: '“$_search”',
        actionLabel: AppStrings.retry,
        onAction: _load,
      );
    }
    return EmptyStateView(
        icon: isBook ? Icons.bookmark_border : Icons.menu_book,
        title: isBook ? AppStrings.noBookmarks : AppStrings.noWords,
        subtitle: isBook ? "" : AppStrings.loadingWords,
        actionLabel: AppStrings.retry,
        onAction: _load,
      );
  }

  Widget _buildWordCard(VocabWordModel w, ThemeData t) {
    final status = w.statusStr, isNew = status == "New", isMastered = status == "Mastered";
    final chipColor = isNew ? Colors.grey : isMastered ? Colors.green : AppTheme.primaryColor;
    final statusText = AppStrings.wordStatusLabel(w.progress?["status"] as String? ?? "new");
    final source = w.bookmarkSource ?? "";
    final highlight = _tabCtrl.index == 0 ? _search : "";
    return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: InkWell(borderRadius: BorderRadius.circular(12),
      onTap: () => context.push("/vocabulary/detail", extra: w.id).then((_) => _load()),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                  children: _highlight(w.word, highlight),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (w.phonetic != null) Text(w.phonetic!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            if (source.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sourceLabel(source),
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
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
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: chipColor.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: chipColor.withAlpha(80))), child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: chipColor))),
      ]))));
  }

  /// 高亮匹配片段
  List<TextSpan> _highlight(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
      ));
      start = idx + q.length;
    }
    return spans;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case "reading":
        return "阅读";
      case "chat":
        return "聊天";
      default:
        return "手动";
    }
  }
}
