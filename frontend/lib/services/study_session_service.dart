import "package:flutter/widgets.dart";
import "stats_service.dart";

/// 真实学习计时服务（单例）
///
/// - 进入学习页面时调用 [start]，离开时调用 [end]
/// - 用 Stopwatch 统计前台活跃秒数，App 进入后台自动暂停
/// - 结束时把真实活跃秒数上报给后端，由后端累计到 daily_stats
class StudySessionService with WidgetsBindingObserver {
  StudySessionService._();

  static final StudySessionService instance = StudySessionService._();

  final _svc = StatsService();
  String? _sessionId;
  String? _type;
  final Stopwatch _watch = Stopwatch();
  bool _started = false;

  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 开始一次学习计时（chat / words / reading / writing）
  Future<void> start(String type) async {
    if (_started) {
      if (_type == type) return;
      await end();
    }
    try {
      final s = await _svc.startSession(type);
      _sessionId = s["session_id"] as String?;
      _type = type;
      _watch
        ..reset()
        ..start();
      _started = true;
    } catch (e) {
      debugPrint("StudySessionService start error: $e");
    }
  }

  /// 结束当前计时并上报真实活跃秒数。
  /// [type] 用于区分是哪个页面发起的结束：切换 Tab 时新页面可能先于旧页面 dispose，
  /// 避免旧页面的 end() 误结束新页面刚开始的会话。
  Future<void> end([String? type]) async {
    if (!_started || _sessionId == null) return;
    if (type != null && type != _type) return;
    _watch.stop();
    final seconds = _watch.elapsedMilliseconds ~/ 1000;
    final id = _sessionId!;
    _sessionId = null;
    _type = null;
    _started = false;
    try {
      await _svc.endSession(id, seconds);
    } catch (e) {
      debugPrint("StudySessionService end error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      if (!_watch.isRunning) _watch.start();
    } else {
      if (_watch.isRunning) _watch.stop();
    }
  }
}
