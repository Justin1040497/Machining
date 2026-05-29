import 'package:flutter/material.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({
    super.key,
    required this.currentVersionLabel,
    required this.release,
    required this.onClose,
    required this.onOpenReleasePage,
  });

  final String currentVersionLabel;
  final AppUpdateRelease release;
  final VoidCallback onClose;
  final VoidCallback onOpenReleasePage;

  @override
  Widget build(BuildContext context) {
    final releaseNotes = release.releaseNotes.trim();

    return WorkbenchDialogFrame(
      maxWidth: 430,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 21),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkbenchDialogTitle('发现新版本'),
          const SizedBox(height: 15),
          _VersionLine(label: '当前版本', value: currentVersionLabel),
          const SizedBox(height: 7),
          _VersionLine(label: '最新版本', value: release.version.toString()),
          if (releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  releaseNotes,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Spacer(),
              WorkbenchDialogActionButton(
                label: '稍后',
                backgroundColor: const Color(0xFFB8B8B8),
                onPressed: onClose,
              ),
              const SizedBox(width: 14),
              WorkbenchDialogActionButton(
                label: '打开发布页',
                backgroundColor: const Color(0xFF6290FF),
                width: 92,
                onPressed: onOpenReleasePage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
