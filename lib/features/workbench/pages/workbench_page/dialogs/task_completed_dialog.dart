import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_formatters.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

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
    final colors = context.frameLeanColors;
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
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: colors.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const WorkbenchDialogTitle('处理完成'),
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
                backgroundColor: colors.statusCancelled,
                onPressed: onClose,
              ),
              const SizedBox(width: 14),
              WorkbenchDialogActionButton(
                label: '打开文件存放位置',
                backgroundColor: colors.primary,
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
    final colors = context.frameLeanColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _SizeMetric(
                label: '源文件',
                value: WorkbenchFormatters.formatBytes(sourceFileSize),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: colors.textTertiary,
                size: 18,
              ),
            ),
            Expanded(
              child: _SizeMetric(
                label: '输出文件',
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
    final colors = context.frameLeanColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 11.flSp,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.flSp,
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
    final colors = context.frameLeanColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11.flSp,
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
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                path,
                maxLines: 1,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.flSp,
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
