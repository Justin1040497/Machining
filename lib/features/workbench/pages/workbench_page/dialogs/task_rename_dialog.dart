import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class TaskRenameDialog extends StatefulWidget {
  const TaskRenameDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<TaskRenameDialog> createState() => _TaskRenameDialogState();
}

class _TaskRenameDialogState extends State<TaskRenameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return WorkbenchDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('任务重命名'),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 1,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.flSp,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: '任务名称',
              labelStyle: TextStyle(
                color: colors.textTertiary,
                fontSize: 12.flSp,
              ),
              filled: true,
              fillColor: colors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: colors.primary),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              WorkbenchDialogActionButton(
                label: '取消',
                backgroundColor: colors.statusCancelled,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              WorkbenchDialogActionButton(
                label: '保存',
                backgroundColor: colors.primary,
                onPressed: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
