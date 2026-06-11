part of '../app_settings_page.dart';

class _SectionActions extends StatelessWidget {
  const _SectionActions({
    required this.dirty,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              side: BorderSide(color: colors.borderStrong),
              foregroundColor: colors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: (dirty && !saving) ? onCancel : null,
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 28,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: (dirty && !saving) ? onSave : null,
            child: saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ),
      ],
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    this.width = 235,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ConfigDropdown<T>(
        label: label,
        trailingText: itemLabel(value),
        value: value,
        values: values,
        itemLabel: itemLabel,
        onChanged: onChanged,
        height: _AppSettingsViewState._fieldHeight,
        showTrailingText: false,
        labelFontSize: 12,
        valueFontSize: 12,
      ),
    );
  }
}

class _SettingsPathField extends StatelessWidget {
  const _SettingsPathField({
    required this.controller,
    required this.enabled,
    required this.highlighted,
    required this.hintText,
    required this.trailingTooltip,
    required this.onTrailingTap,
    required this.onDraggingChanged,
    required this.onDropped,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool highlighted;
  final String hintText;
  final String trailingTooltip;
  final VoidCallback onTrailingTap;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<List<DropItem>> onDropped;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: PathField(
        controller: controller,
        enabled: enabled,
        highlighted: highlighted,
        hintText: hintText,
        height: _AppSettingsViewState._fieldHeight,
        fontSize: 12,
        hintFontSize: 12,
        trailingIcon: Icons.more_horiz_rounded,
        trailingTooltip: trailingTooltip,
        onTrailingTap: onTrailingTap,
        onDraggingChanged: onDraggingChanged,
        onDropped: onDropped,
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 235,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormFieldLabel(label),
          const SizedBox(height: 8),
          SizedBox(
            height: _AppSettingsViewState._fieldHeight,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: TextStyle(color: colors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                filled: true,
                fillColor: colors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCheckbox extends StatelessWidget {
  const _SettingsCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 15,
            child: Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
              side: BorderSide(color: colors.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: children[0]),
        ),
        const SizedBox(width: 36),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: children[1]),
        ),
      ],
    );
  }
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Text(
      label,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
