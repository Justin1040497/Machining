import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

class AppSettingsSectionLabel extends StatelessWidget {
  const AppSettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Text(
      label,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 12.flSp,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class AppSettingsSourceDirectoryCheckbox extends StatelessWidget {
  const AppSettingsSourceDirectoryCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: Checkbox(
            value: value,
            onChanged: (value) {
              onChanged(value ?? false);
            },
            side: BorderSide(color: colors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          '保存到原文件旁',
          style: TextStyle(color: colors.textTertiary, fontSize: 11.flSp),
        ),
      ],
    );
  }
}

class AppSettingsActions extends StatelessWidget {
  const AppSettingsActions({
    super.key,
    required this.advancedVisible,
    required this.saving,
    required this.onToggleAdvanced,
    required this.onCancel,
    required this.onSave,
  });

  final bool advancedVisible;
  final bool saving;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Row(
      children: [
        WorkbenchDialogActionButton(
          label: advancedVisible ? '关闭高级选项' : '高级设置',
          backgroundColor: colors.statusRunning,
          width: advancedVisible ? 92 : 75,
          onPressed: onToggleAdvanced,
        ),
        const Spacer(),
        WorkbenchDialogActionButton(
          label: '取消',
          backgroundColor: colors.statusCancelled,
          onPressed: saving ? null : onCancel,
        ),
        const SizedBox(width: 16),
        WorkbenchDialogActionButton(
          label: '保存',
          backgroundColor: colors.primary,
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}
