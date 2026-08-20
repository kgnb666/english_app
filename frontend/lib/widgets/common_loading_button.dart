import "package:flutter/material.dart";

/// 全局统一按钮：normal / loading / disabled 三态。
/// - 点击时缩放反馈 + Material 水波纹
/// - loading 时显示进度圈并禁用（防重复点击）
class CommonLoadingButton extends StatefulWidget {
  final String label;
  final String? loadingLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? height;
  final bool expanded;

  const CommonLoadingButton({
    super.key,
    required this.label,
    this.loadingLabel,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.backgroundColor,
    this.foregroundColor,
    this.height,
    this.expanded = true,
  });

  @override
  State<CommonLoadingButton> createState() => _CommonLoadingButtonState();
}

class _CommonLoadingButtonState extends State<CommonLoadingButton> {
  bool _pressed = false;

  bool get _canTap =>
      widget.onPressed != null && !widget.loading && widget.enabled;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: _canTap ? widget.onPressed : null,
      icon: widget.loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : (widget.icon != null ? Icon(widget.icon, size: 18) : const SizedBox.shrink()),
      label: Text(
        widget.loading ? (widget.loadingLabel ?? widget.label) : widget.label,
        style: const TextStyle(fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor ?? Colors.white,
        minimumSize: Size.fromHeight(widget.height ?? 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _canTap ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _canTap ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _canTap ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.expanded
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
