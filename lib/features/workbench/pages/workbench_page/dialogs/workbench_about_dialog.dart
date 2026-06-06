import 'package:flutter/material.dart';
import 'package:framelean/application/services/framelean_build_info.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class WorkbenchAboutDialog extends StatelessWidget {
  const WorkbenchAboutDialog({
    super.key,
    required this.onClose,
    required this.onOpenGitHub,
    required this.onOpenGitee,
  });

  final VoidCallback onClose;
  final VoidCallback onOpenGitHub;
  final VoidCallback onOpenGitee;

  @override
  Widget build(BuildContext context) {
    return WorkbenchDialogFrame(
      maxWidth: 390,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('关于'),
          const SizedBox(height: 16),
          const WorkbenchDialogBodyText(
            'FrameLean 是一款桌面媒体处理工具，提供媒体导入、媒体分析、'
            '处理配置、任务队列和导出管理。',
          ),
          const SizedBox(height: 14),
          const Text(
            '当前版本：${FrameLeanBuildInfo.currentVersionLabel}',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RepositoryIconButton(
                    tooltip: '打开 GitHub',
                    assetPath: 'assets/icons/github.png',
                    onPressed: onOpenGitHub,
                  ),
                  const SizedBox(width: 8),
                  _RepositoryIconButton(
                    tooltip: '打开 Gitee',
                    assetPath: 'assets/icons/gitee.png',
                    onPressed: onOpenGitee,
                  ),
                ],
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

class _RepositoryIconButton extends StatelessWidget {
  const _RepositoryIconButton({
    required this.tooltip,
    required this.assetPath,
    required this.onPressed,
  });

  final String tooltip;
  final String assetPath;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          hoverColor: const Color(0xFFF2F2F2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Image.asset(
          assetPath,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
