import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
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

    return AlertDialog(
      title: const Text('导入失败日志'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 360),
        child: SingleChildScrollView(child: SelectableText(logText)),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}
