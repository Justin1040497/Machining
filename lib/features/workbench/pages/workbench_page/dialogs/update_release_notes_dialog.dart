import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/widgets/simple_markdown_view.dart';
import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_notes.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class UpdateReleaseNotesDialog extends StatelessWidget {
  const UpdateReleaseNotesDialog.current({
    super.key,
    required this.updateState,
    required this.onStartDownload,
    required this.onPauseDownload,
    required this.onInstallUpdate,
    required this.onOpenMore,
    this.manualMacosUpdate = false,
  }) : historicalNotes = null;

  const UpdateReleaseNotesDialog.history({
    super.key,
    required AppReleaseNotes notes,
    required this.onOpenMore,
  }) : updateState = null,
       historicalNotes = notes,
       onStartDownload = null,
       onPauseDownload = null,
       onInstallUpdate = null,
       manualMacosUpdate = false;

  final AppUpdateState? updateState;
  final AppReleaseNotes? historicalNotes;
  final VoidCallback? onStartDownload;
  final VoidCallback? onPauseDownload;
  final VoidCallback? onInstallUpdate;
  final VoidCallback onOpenMore;
  final bool manualMacosUpdate;

  bool get _isHistory => historicalNotes != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final state = updateState;
    final release = state?.release;
    final history = historicalNotes;
    final title = _isHistory
        ? history!.version
        : release == null
        ? '新版本'
        : '新版本！${release.version}';
    final markdown = _isHistory
        ? history!.markdown
        : release?.releaseNotesMarkdown ?? '';

    return WorkbenchDialogFrame(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkbenchDialogBackHeader(
              title: title,
              onClose: () => Navigator.of(context).pop(),
              trailing: _isHistory
                  ? TextButton(
                      onPressed: onOpenMore,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textTertiary,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('查看更多'),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SimpleMarkdownView(markdown: markdown),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isHistory)
              Align(
                alignment: Alignment.centerRight,
                child: WorkbenchDialogActionButton(
                  label: '关闭',
                  backgroundColor: colors.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
            else
              _CurrentUpdateActions(
                state: state ?? AppUpdateState.initial(),
                manualMacosUpdate: manualMacosUpdate,
                onStartDownload: onStartDownload,
                onPauseDownload: onPauseDownload,
                onInstallUpdate: onInstallUpdate,
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentUpdateActions extends StatelessWidget {
  const _CurrentUpdateActions({
    required this.state,
    required this.manualMacosUpdate,
    required this.onStartDownload,
    required this.onPauseDownload,
    required this.onInstallUpdate,
  });

  final AppUpdateState state;
  final bool manualMacosUpdate;
  final VoidCallback? onStartDownload;
  final VoidCallback? onPauseDownload;
  final VoidCallback? onInstallUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final status = state.status;
    final primaryLabel = switch (status) {
      AppUpdateStatus.downloading => '暂停',
      AppUpdateStatus.paused => '继续',
      AppUpdateStatus.downloaded => manualMacosUpdate ? '打开 DMG' : '重启更新',
      AppUpdateStatus.installing => manualMacosUpdate ? '打开中' : '安装中',
      _ => manualMacosUpdate ? '下载 DMG' : '下载',
    };
    final primaryAction = switch (status) {
      AppUpdateStatus.downloading => onPauseDownload,
      AppUpdateStatus.downloaded => onInstallUpdate,
      AppUpdateStatus.installing => null,
      _ => onStartDownload,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: status == AppUpdateStatus.available ? 0 : state.progress,
            minHeight: 6,
            backgroundColor: colors.surfaceMuted,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${state.progressPercent}%',
          textAlign: TextAlign.right,
          style: TextStyle(color: colors.textTertiary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            WorkbenchDialogActionButton(
              label: primaryLabel,
              backgroundColor: colors.primary,
              onPressed: primaryAction,
              width: 88,
            ),
            const SizedBox(width: 12),
            WorkbenchDialogActionButton(
              label: '后台下载',
              backgroundColor: colors.statusCancelled,
              onPressed: () => Navigator.of(context).pop(),
              width: 88,
            ),
          ],
        ),
      ],
    );
  }
}
