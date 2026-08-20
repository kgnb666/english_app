import "package:flutter/material.dart";

import "../l10n/zh_CN.dart";

/// 统一空状态 / 错误状态组件：插图 + 提示文字 + 操作按钮
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = isError ? t.colorScheme.error : t.colorScheme.primary;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: color.withAlpha(14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: t.colorScheme.onSurface.withAlpha(190),
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(isError ? Icons.refresh : Icons.arrow_forward, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 快捷创建“加载失败，点击重试”的错误状态
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetryView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.cloud_off_outlined,
      title: message.isEmpty ? AppStrings.loadFailed : message,
      subtitle: AppStrings.retryHint,
      actionLabel: AppStrings.retry,
      onAction: onRetry,
      isError: true,
    );
  }
}
