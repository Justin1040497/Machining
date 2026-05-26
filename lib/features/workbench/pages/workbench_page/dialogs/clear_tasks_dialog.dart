import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class ClearTasksDialog extends StatelessWidget {
  const ClearTasksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkbenchDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('清空列表'),
          const SizedBox(height: 14),
          const WorkbenchDialogBodyText('确定要清空列表吗？'),
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
                label: '清空',
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
