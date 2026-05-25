import 'package:flutter/material.dart';

class CompressionConfirmationDialog extends StatelessWidget {
  const CompressionConfirmationDialog({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('确认继续压缩'),
      content: Text('$message\n\n继续后会使用更激进的压缩策略。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('继续压缩'),
        ),
      ],
    );
  }
}
