import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class UpdateRestartWarningDialog extends StatelessWidget {
  const UpdateRestartWarningDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '重启并安装更新',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '当前还有未完成任务。重启会暂停这些任务，应用重启后可以在工作台点击继续。',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogActionButton(
                    label: '取消',
                    backgroundColor: colors.statusCancelled,
                    foregroundColor: colors.textPrimary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 16),
                  _DialogActionButton(
                    label: '重启更新',
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    onPressed: () => Navigator.of(context).pop(true),
                    width: 88,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.width = 75,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
