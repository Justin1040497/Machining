import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';

class CompressionConfirmationDialog extends StatelessWidget {
  const CompressionConfirmationDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return AppDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDialogTitle('确认继续压缩'),
          const SizedBox(height: 14),
          AppDialogBodyText('$message\n继续后会使用更激进的压缩策略。'),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppDialogActionButton(
                label: '取消',
                backgroundColor: colors.statusCancelled,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 16),
              AppDialogActionButton(
                label: '继续压缩',
                backgroundColor: colors.primary,
                onPressed: () => Navigator.of(context).pop(true),
                width: 96,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
