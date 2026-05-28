import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class TaskCompletedDialog extends StatelessWidget {
  const TaskCompletedDialog({
    super.key,
    required this.outputPath,
    required this.sourceFileSize,
    required this.outputFileSize,
    required this.onClose,
    required this.onReveal,
  });

  final String? outputPath;
  final int? sourceFileSize;
  final int? outputFileSize;
  final VoidCallback onClose;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final hasOutputPath = outputPath != null && outputPath!.isNotEmpty;

    return WorkbenchDialogFrame(
      maxWidth: 390,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0x176290FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF6290FF),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const WorkbenchDialogTitle('压缩完成'),
            ],
          ),
          const SizedBox(height: 18),
          _SizeSummary(
            sourceFileSize: sourceFileSize,
            outputFileSize: outputFileSize,
          ),
          const SizedBox(height: 14),
          _OutputPathLine(
            label: '导出位置',
            path: hasOutputPath ? outputPath! : '-',
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              WorkbenchDialogActionButton(
                label: '取消',
                backgroundColor: const Color(0xFFB8B8B8),
                onPressed: onClose,
              ),
              const SizedBox(width: 14),
              WorkbenchDialogActionButton(
                label: '打开文件存放位置',
                backgroundColor: const Color(0xFF6290FF),
                onPressed: onReveal,
                width: 126,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeSummary extends StatelessWidget {
  const _SizeSummary({
    required this.sourceFileSize,
    required this.outputFileSize,
  });

  final int? sourceFileSize;
  final int? outputFileSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _SizeMetric(
                label: '压缩前',
                value: WorkbenchFormatters.formatBytes(sourceFileSize),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF9AA3B2),
                size: 18,
              ),
            ),
            Expanded(
              child: _SizeMetric(
                label: '压缩后',
                value: WorkbenchFormatters.formatBytes(outputFileSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeMetric extends StatelessWidget {
  const _SizeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B8493),
            fontSize: 11,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF171B22),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _OutputPathLine extends StatelessWidget {
  const _OutputPathLine({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B8493),
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 30,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFE4E8EF)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                path,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF4E5867),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
