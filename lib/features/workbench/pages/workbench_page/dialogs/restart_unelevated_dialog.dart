import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class RestartUnelevatedDialog extends StatelessWidget {
  const RestartUnelevatedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkbenchDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('普通模式重启'),
          const SizedBox(height: 14),
          const WorkbenchDialogBodyText(
            '当前有任务正在处理。普通模式重启会关闭当前管理员窗口，并中断正在执行的任务。',
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              WorkbenchDialogActionButton(
                label: '取消',
                backgroundColor: const Color(0xFFB8B8B8),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 16),
              WorkbenchDialogActionButton(
                label: '重启',
                backgroundColor: const Color(0xFF6290FF),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
