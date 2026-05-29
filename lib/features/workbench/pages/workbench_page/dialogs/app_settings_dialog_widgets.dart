import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

class AppSettingsSectionLabel extends StatelessWidget {
  const AppSettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 12,
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
            side: const BorderSide(color: Color(0xFFDCDCDC)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          '保存到原文件旁',
          style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
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
    return Row(
      children: [
        WorkbenchDialogActionButton(
          label: advancedVisible ? '关闭高级选项' : '高级设置',
          backgroundColor: const Color(0xFFFF6B00),
          width: advancedVisible ? 92 : 75,
          onPressed: onToggleAdvanced,
        ),
        const Spacer(),
        WorkbenchDialogActionButton(
          label: '取消',
          backgroundColor: const Color(0xFFB8B8B8),
          onPressed: saving ? null : onCancel,
        ),
        const SizedBox(width: 16),
        WorkbenchDialogActionButton(
          label: '保存',
          backgroundColor: const Color(0xFF6290FF),
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}
