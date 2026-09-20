/// 后端报错文案的本地化映射
///
/// 服务端返回的 detail/message 会直接展示给用户，历史上这些文案是英文的
/// （例如 "Invalid username or password"）。这里做一次统一转换：
///
/// 1. 已经是中文的原文直接透传；
/// 2. 命中映射表的英文原文按表转换；
/// 3. 命中动态规则（含用户名、邮箱等变量）按规则拼中文；
/// 4. 其余未知英文一律退回到调用方给的兜底文案，避免再冒出英文。
///
/// 注意：本文件保持纯 Dart（不依赖 Flutter），方便单测。
class ServerMessages {
  ServerMessages._();

  static const String defaultFallback = "操作失败，请稍后重试";

  /// 固定英文文案 -> 中文
  static const Map<String, String> _exact = {
    "Invalid username or password": "用户名或密码错误",
    "Invalid or expired refresh token": "登录已过期，请重新登录",
    "User not found": "用户不存在",
    "Current password is incorrect": "当前密码不正确",
    "New password must be at least 6 characters": "新密码至少需要 6 位",
    "Session not found": "会话不存在",
    "No messages": "没有消息",
    "Article not found": "文章不存在",
    "Listening item not found": "听力材料不存在",
    "Record not found": "记录不存在",
    "Word not found": "单词不存在",
    "Word is required": "请先选择单词",
    "Error log not found": "错题记录不存在",
    "Study session not found": "学习会话不存在",
    "Study session already ended": "该学习会话已结束",
    "Reading record not found": "阅读记录不存在",
    "Writing record not found": "写作记录不存在",
    "Template not found": "模板不存在",
    "Audio generation failed": "音频生成失败，请稍后重试",
    "AI template generation failed": "AI 模板生成失败，请稍后重试",
    "Empty audio file": "录音内容为空，请重新录制",
    "Audio too large": "录音文件过大，请缩短录音时长",
    "TTS synthesis returned no audio": "语音合成失败，请稍后重试",
    "target_text is required": "缺少跟读文本",
    "chinese_text and user_translation are required": "请填写原文和你的翻译",
    "user_answer is required": "请先填写答案",
    "title and content are required": "请填写标题和正文",
    "Unauthorized": "登录已过期，请重新登录",
    "Not authenticated": "请先登录",
    "Forbidden": "没有权限执行该操作",
    "Not Found": "请求的内容不存在",
  };

  /// 动态英文文案 -> 中文（按顺序匹配，命中即返回）
  static final List<(RegExp, String Function(RegExpMatch))> _patterns = [
    (
      RegExp(r"^Username '(.+)' already exists$"),
      (m) => "用户名「${m.group(1)}」已被注册",
    ),
    (
      RegExp(r"^Email '(.+)' already registered$"),
      (m) => "邮箱「${m.group(1)}」已被注册",
    ),
    (
      RegExp(r"^exam_type must be CET4 or CET6$"),
      (m) => "考试类型只能是四级或六级",
    ),
    (
      RegExp(r"^target_score must be between (\d+) and (\d+)$"),
      (m) => "目标分数需在 ${m.group(1)} - ${m.group(2)} 之间",
    ),
    (
      RegExp(r"^exam_date must be in the future$"),
      (m) => "考试日期必须晚于今天",
    ),
    (
      RegExp(r"^Unsupported task type: (.+)$"),
      (m) => "不支持的学习任务类型：${m.group(1)}",
    ),
    (
      RegExp(r"^Unsupported session type: (.+)$"),
      (m) => "不支持的会话类型：${m.group(1)}",
    ),
    (
      RegExp(r"^Unsupported voice: (.+)$"),
      (m) => "不支持的发音人：${m.group(1)}",
    ),
    (
      RegExp(r"^Transcription failed.*$"),
      (m) => "语音识别失败，请重试",
    ),
    (
      RegExp(r"^TTS service error.*$"),
      (m) => "语音合成失败，请稍后重试",
    ),
  ];

  /// 把后端返回的报错文案转成中文
  ///
  /// [raw] 可以是 detail、message 或任意错误对象；
  /// [fallback] 是未知英文/空值时的兜底文案。
  static String localize(Object? raw, {String fallback = defaultFallback}) {
    final text = raw?.toString().trim() ?? "";
    if (text.isEmpty) return fallback;
    // 已经是中文（或其他非 ASCII 文案）就不动它
    if (_hasCjk(text)) return text;

    final exact = _exact[text];
    if (exact != null) return exact;

    for (final (pattern, build) in _patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return build(match);
    }
    return fallback;
  }

  static bool _hasCjk(String text) {
    for (final rune in text.runes) {
      // CJK 统一表意文字 + 中文标点所在区间
      if (rune >= 0x3000 && rune <= 0x9FFF) return true;
      if (rune >= 0xF900 && rune <= 0xFAFF) return true;
    }
    return false;
  }
}
