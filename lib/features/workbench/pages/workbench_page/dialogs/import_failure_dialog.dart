import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:path/path.dart' as path;

class ImportFailureDialog extends StatelessWidget {
  const ImportFailureDialog({super.key, required this.failures});

  final List<DroppedImportFailure> failures;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
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
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  logText,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.flSp,
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
                backgroundColor: colors.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
