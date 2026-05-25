import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class CompressionConfirmationDialog extends StatelessWidget {
  const CompressionConfirmationDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WorkbenchDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('确认继续压缩'),
          const SizedBox(height: 14),
          WorkbenchDialogBodyText('$message\n继续后会使用更激进的压缩策略。'),
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
                label: '继续压缩',
                backgroundColor: const Color(0xFF6290FF),
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
