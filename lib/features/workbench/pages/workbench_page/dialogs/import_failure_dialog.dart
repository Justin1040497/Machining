import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:path/path.dart' as path;

class ImportFailureDialog extends StatelessWidget {
  const ImportFailureDialog({super.key, required this.failures});

  final List<DroppedImportFailure> failures;

  @override
  Widget build(BuildContext context) {
    final logText = failures
        .map((failure) {
          final fileName = path.basename(failure.path);
          return '$fileName\n${failure.path}\n原因：${failure.reason}';
        })
        .join('\n\n');

    return WorkbenchDialogFrame(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('导入失败日志'),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E4E4)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  logText,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              WorkbenchDialogActionButton(
                label: '知道了',
                backgroundColor: const Color(0xFF6290FF),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
