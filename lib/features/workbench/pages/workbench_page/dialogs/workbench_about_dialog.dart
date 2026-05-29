import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class WorkbenchAboutDialog extends StatelessWidget {
  const WorkbenchAboutDialog({
    super.key,
    required this.onClose,
    required this.onCheckUpdate,
    required this.onOpenGitHub,
  });

  final VoidCallback onClose;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenGitHub;

  static const currentVersion = '1.1.5';

  @override
  Widget build(BuildContext context) {
    return WorkbenchDialogFrame(
      maxWidth: 390,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WorkbenchDialogTitle('关于'),
              const Spacer(),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: '打开 GitHub',
                  onPressed: onOpenGitHub,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF111111),
                    hoverColor: const Color(0xFFF2F2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.code_rounded, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const WorkbenchDialogBodyText(
            'FrameLean 是一款桌面视频压缩工具，提供视频导入、媒体分析、'
            '压缩配置、任务队列和导出管理。',
          ),
          const SizedBox(height: 14),
          const Text(
            '当前版本：$currentVersion',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              WorkbenchDialogActionButton(
                label: '检查更新',
                backgroundColor: const Color(0xFF6290FF),
                width: 86,
                onPressed: onCheckUpdate,
              ),
              const Spacer(),
              WorkbenchDialogActionButton(
                label: '关闭',
                backgroundColor: const Color(0xFFB8B8B8),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
