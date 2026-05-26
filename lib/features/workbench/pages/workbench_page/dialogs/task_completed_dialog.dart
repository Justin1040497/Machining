import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class TaskCompletedDialog extends StatelessWidget {
  const TaskCompletedDialog({
    super.key,
    required this.fileName,
    required this.outputPath,
    required this.onClose,
    required this.onReveal,
  });

  final String fileName;
  final String? outputPath;
  final VoidCallback onClose;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final hasOutputPath = outputPath != null && outputPath!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0x176290FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF6290FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '压缩完成',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasOutputPath
                              ? '文件已保存，可以打开所在位置查看。'
                              : '任务已完成，但没有记录输出路径。',
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E4E4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasOutputPath) ...[
                      const SizedBox(height: 7),
                      SelectableText(
                        outputPath!,
                        style: const TextStyle(
                          color: Color(0xFF8C8C8C),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReveal != null) ...[
                    WorkbenchDialogActionButton(
                      label: '打开文件所在位置',
                      backgroundColor: const Color(0xFF6290FF),
                      onPressed: onReveal!,
                      width: 118,
                    ),
                    const SizedBox(width: 12),
                  ],
                  WorkbenchDialogActionButton(
                    label: '知道了',
                    backgroundColor: const Color(0xFFB8B8B8),
                    onPressed: onClose,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
