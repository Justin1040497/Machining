import 'package:flutter/material.dart';

class ClearTasksDialog extends StatelessWidget {
  const ClearTasksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('清空列表'),
      content: const Text('确定要清空列表吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('清空'),
        ),
      ],
    );
  }
}
