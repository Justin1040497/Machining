import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/app/library.dart';
import 'package:path/path.dart' as path;

/// 导入结果弹窗 成功数、失败数，以及每个失败项的详细原因
class ImportFailureDialog extends StatelessWidget {
  const ImportFailureDialog({
    super.key,
    required this.successCount,
    required this.failures,
  });

  final int successCount;
  final List<DroppedImportFailure> failures;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return AppDialogFrame(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppDialogTitle('导入结果'),
          const SizedBox(height: 10),
          _SummaryRow(
            successCount: successCount,
            failureCount: failures.length,
            colors: colors,
          ),
          if (failures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '以下文件未能导入：',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.flSp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
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
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: failures.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.border,
                  ),
                  itemBuilder: (context, index) {
                    final failure = failures[index];
                    final fileName = path.basename(failure.path);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12.flSp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            failure.path,
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: 11.flSp,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.statusFailed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              failure.reason,
                              style: TextStyle(
                                color: colors.statusFailed,
                                fontSize: 11.flSp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppDialogActionButton(
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.successCount,
    required this.failureCount,
    required this.colors,
  });

  final int successCount;
  final int failureCount;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(
          label: '成功 $successCount 个',
          color: colors.primary,
        ),
        const SizedBox(width: 10),
        _SummaryChip(
          label: '失败 $failureCount 个',
          color: failureCount > 0
              ? colors.statusFailed
              : colors.textTertiary,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.flSp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
