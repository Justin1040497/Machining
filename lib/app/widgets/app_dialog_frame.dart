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
