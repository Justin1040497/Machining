import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';

class ClearTasksDialog extends StatelessWidget {
  const ClearTasksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return AppDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDialogTitle('清空列表'),
          const SizedBox(height: 14),
          const AppDialogBodyText('确定要清空所有任务和任务夹吗？'),
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
                label: '清空',
                backgroundColor: colors.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
