import "package:flutter/material.dart";
import "../config/theme.dart";
import "../l10n/zh_CN.dart";

/// AI 内容块：标题 + 内容 + 类型
class AISection {
  final String title;
  final dynamic content;
  final String type; // text / list / example / pair / word

  const AISection({required this.title, this.content, this.type = "text"});
}

/// 统一 AI 内容卡片：标题、概述、内容块、建议、可折叠。
/// 所有 AI 生成内容用此组件渲染，禁止直接 Text(aiResponse)。
class AIAnalysisCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String? summary;
  final List<AISection> sections;
  final List<String> tips;
  final bool collapsible;
  final Color? accentColor;

  const AIAnalysisCard({
    super.key,
    required this.title,
    required this.icon,
    this.summary,
    this.sections = const [],
    this.tips = const [],
    this.collapsible = true,
    this.accentColor,
  });

  @override
  State<AIAnalysisCard> createState() => _AIAnalysisCardState();
}

class _AIAnalysisCardState extends State<AIAnalysisCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final accent = widget.accentColor ?? AppTheme.primaryColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 标题
          Row(children: [
            Icon(widget.icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  height: 1.3,
                ),
              ),
            ),
            if (widget.collapsible)
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
          ]),
          if (!_expanded) ...[
            const SizedBox(height: 8),
            if (widget.summary != null && widget.summary!.isNotEmpty)
              Text(
                widget.summary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
          ] else ...[
            // 概述
            if (widget.summary != null && widget.summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.summary!, style: const TextStyle(fontSize: 15, height: 1.7)),
            ],
            // 内容块
            for (final s in widget.sections) _section(s, t, accent),
            // 建议
            if (widget.tips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    AppStrings.aiTips,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                  ),
                  const SizedBox(height: 4),
                  for (final tip in widget.tips)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text("💡  $tip", style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                ]),
              ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _section(AISection s, ThemeData t, Color accent) {
    if (s.title.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            s.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: accent,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          _content(s, t, accent),
        ]),
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 6), child: _content(s, t, accent));
  }

  Widget _content(AISection s, ThemeData t, Color accent) {
    switch (s.type) {
      case "list":
        final items = (s.content is List ? s.content : [s.content]).cast<dynamic>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3, right: 8),
                    child: Text("•", style: TextStyle(fontSize: 15)),
                  ),
                  Expanded(
                    child: Text("$item", style: const TextStyle(fontSize: 15, height: 1.6)),
                  ),
                ]),
              ),
          ],
        );
      case "example":
        final items = (s.content is List ? s.content : [s.content]).cast<Map<String, dynamic>>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    (e["en"] ?? e["original"] ?? "").toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: t.colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                  if (((e["cn"] ?? e["translation_cn"]) as String? ?? "").isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        (e["cn"] ?? e["translation_cn"]).toString(),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                      ),
                    ),
                ]),
              ),
          ],
        );
      case "pair":
        final items = (s.content is List ? s.content : [s.content]).cast<Map<String, dynamic>>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 15, height: 1.5, color: t.colorScheme.onSurface),
                    children: [
                      TextSpan(
                        text: (p["original"] ?? p["wrong"] ?? "").toString(),
                        style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red),
                      ),
                      const TextSpan(text: "  →  "),
                      TextSpan(
                        text: (p["correct"] ?? "").toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      case "word":
        final items = (s.content is List ? s.content : [s.content]).cast<Map<String, dynamic>>();
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final w in items)
              Chip(
                label: Text(
                  "${w["word"]}  ${w["definition_cn"] ?? ""}",
                  style: const TextStyle(fontSize: 13),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: accent.withAlpha(10),
              ),
          ],
        );
      default:
        // text
        return Text(
          s.content?.toString() ?? "",
          style: const TextStyle(fontSize: 15, height: 1.7),
        );
    }
  }
}
