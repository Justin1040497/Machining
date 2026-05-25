import 'package:flutter/material.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

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
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: '任务名称',
              labelStyle: const TextStyle(
                color: Color(0xFF8C8C8C),
                fontSize: 12,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF6290FF)),
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
                backgroundColor: const Color(0xFFB8B8B8),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 16),
              WorkbenchDialogActionButton(
                label: '保存',
                backgroundColor: const Color(0xFF6290FF),
                onPressed: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
