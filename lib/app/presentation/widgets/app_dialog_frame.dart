import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 410,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 21),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppDialogTitle extends StatelessWidget {
  const AppDialogTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Text(
      title,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 18.flSp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class AppDialogActionButton extends StatelessWidget {
  const AppDialogActionButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.width = 75,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final foregroundColor = _resolveForegroundColor(colors);

    return SizedBox(
      width: width,
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null
              ? backgroundColor.withAlpha(150)
              : backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontSize: 11.flSp, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }

  Color _resolveForegroundColor(FrameLeanColors colors) {
    if (backgroundColor == colors.primary) {
      return colors.onPrimary;
    }
    if (backgroundColor == colors.statusFailed) {
      return colors.onDanger;
    }
    if (backgroundColor == colors.statusRunning ||
        backgroundColor == colors.statusPending) {
      return colors.onWarning;
    }
    if (backgroundColor == colors.statusCancelled) {
      return colors.textPrimary;
    }

    return colors.onPrimary;
  }
}

/// 弹窗正文文字 — 13sp / secondary / 1.55 行高
class AppDialogBodyText extends StatelessWidget {
  const AppDialogBodyText(this.text, {super.key, this.fontSize = 13});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: fontSize.flSp,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

/// 带返回键的标题栏 — 用于二级页面型弹窗
class AppDialogBackHeader extends StatelessWidget {
  const AppDialogBackHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.trailing,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.keyboard_arrow_left_rounded,
                color: colors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15.flSp,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// 取消/保存按钮组 — 默认契约：左 leading + 右两按钮
class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.leading,
    this.cancelLabel = '取消',
    this.saveLabel = '保存',
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Widget? leading;
  final String cancelLabel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: leading ?? const SizedBox.shrink(),
          ),
        ),
        AppDialogActionButton(
          label: cancelLabel,
          backgroundColor: colors.statusCancelled,
          onPressed: onCancel,
        ),
        const SizedBox(width: 16),
        AppDialogActionButton(
          label: saveLabel,
          backgroundColor: colors.primary,
          onPressed: onSave,
        ),
      ],
    );
  }
}
