import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: const Text('任务重命名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 1,
        decoration: const InputDecoration(
          labelText: '任务名称',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
