import 'package:flutter/material.dart';
import 'package:framelean/app/presentation/widgets/app_dialog_frame.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

/// 二次确认弹窗模板。
///
/// 契约：`show()` 返回 `true` = 确认，`false` 或 `null`（关闭按钮）= 取消。
///
/// 适用于结构为「标题 + 正文 + 取消/确认两按钮」的标准确认弹窗。
/// 带自定义内容区（如失败列表）的弹窗请直接使用 [AppDialogFrame] 组合。
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    this.body,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.confirmWidth = 75,
    this.maxWidth = 410,
  });

  final String title;
  final String? body;
  final String confirmLabel;
  final String cancelLabel;
  final double confirmWidth;
  final double maxWidth;

  /// 便捷调用入口。
  ///
  /// 返回 `true` 表示用户点了确认按钮；`false` 表示取消或关闭。
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? body,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    double confirmWidth = 75,
    double maxWidth = 410,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmWidth: confirmWidth,
        maxWidth: maxWidth,
      ),
    ).then((confirmed) => confirmed == true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return AppDialogFrame(
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDialogTitle(title),
          if (body != null) ...[
            const SizedBox(height: 14),
            AppDialogBodyText(body!),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppDialogActionButton(
                label: cancelLabel,
                backgroundColor: colors.statusCancelled,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 16),
              AppDialogActionButton(
                label: confirmLabel,
                backgroundColor: colors.primary,
                onPressed: () => Navigator.of(context).pop(true),
                width: confirmWidth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
