import "package:flutter/material.dart";

import "../config/theme.dart";
import "../l10n/zh_CN.dart";
import "../services/writing_service.dart";

/// 作文批改结果展示（主页面与历史详情复用）
class WritingResultView extends StatelessWidget {
  final WritingResult result;
  const WritingResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = result;
    final scoreColor = r.score >= 7 ? Colors.green : r.score >= 4 ? Colors.orange : Colors.red;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withAlpha(30), border: Border.all(color: scoreColor, width: 3)),
              child: Center(child: Text("${r.score}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scoreColor))),
            ),
            const SizedBox(width: 16),
            Text(AppStrings.overallScore, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (r.suggestions.isNotEmpty) ...[
        _card(t, AppStrings.suggestions, Icons.tips_and_updates, r.suggestions),
        const SizedBox(height: 12),
      ],
      if (r.errors.isNotEmpty) ...[
        _buildErrors(r.errors, t),
        const SizedBox(height: 12),
      ],
      if (r.optimized.isNotEmpty) _card(t, AppStrings.optimizedVersion, Icons.auto_fix_high, r.optimized),
    ]);
  }

  Widget _card(ThemeData t, String title, IconData icon, String content) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
              ]),
              const SizedBox(height: 8),
              Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
            ],
          ),
        ),
      );

  Widget _buildErrors(List<ErrorItem> errors, ThemeData t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text(AppStrings.grammarErrors, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.red.shade400)),
          ]),
          const SizedBox(height: 12),
          ...errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withAlpha(10), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RichText(
                      text: TextSpan(style: const TextStyle(fontSize: 13), children: [
                        TextSpan(text: e.original, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.red)),
                        const TextSpan(text: "  ->  "),
                        TextSpan(text: e.correction, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                      ]),
                    ),
                    if (e.explanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.explanation, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ]),
                ),
              )),
        ]),
      ),
    );
  }
}
