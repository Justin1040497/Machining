import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';

class RestartUnelevatedDialog extends StatelessWidget {
  const RestartUnelevatedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return AppDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDialogTitle('普通模式重启'),
          const SizedBox(height: 14),
          const AppDialogBodyText(
            '当前有任务正在处理。普通模式重启会关闭当前管理员窗口，并中断正在执行的任务。',
          ),
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
                label: '重启',
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
