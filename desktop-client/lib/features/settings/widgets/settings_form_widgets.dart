part of '../pages/app_settings_page.dart';

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
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;
  final double width;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedValue = values.contains(value) ? value : values.first;

    return SizedBox(
      width: width,
      child: ConfigDropdown<T>(
        label: label,
        trailingText: itemLabel(selectedValue),
        value: selectedValue,
        values: values,
        itemLabel: itemLabel,
        onChanged: onChanged,
        height: _AppSettingsViewState._fieldHeight,
        showTrailingText: false,
        labelFontSize: 12,
        valueFontSize: 12,
        enabled: enabled,
      ),
    );
  }
}

class _SettingsOutputFormatField extends StatelessWidget {
  const _SettingsOutputFormatField({
    required this.label,
    required this.keepOriginalLabel,
    required this.value,
    required this.values,
    required this.keepOriginal,
    required this.onKeepOriginalChanged,
    required this.onChanged,
  });

  final String label;
  final String keepOriginalLabel;
  final MediaOutputFormat value;
  final List<MediaOutputFormat> values;
  final bool keepOriginal;
  final ValueChanged<bool> onKeepOriginalChanged;
  final ValueChanged<MediaOutputFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = values.contains(value) ? value : values.first;

    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormFieldLabel(label),
          const SizedBox(height: 8),
          _SettingsCheckbox(
            label: keepOriginalLabel,
            value: keepOriginal,
            onChanged: onKeepOriginalChanged,
          ),
          const SizedBox(height: 8),
          ConfigDropdown<MediaOutputFormat>(
            label: label,
            trailingText: selectedValue.label,
            value: selectedValue,
            values: values,
            itemLabel: (value) => value.label,
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
            height: _AppSettingsViewState._fieldHeight,
            showLabel: false,
            showTrailingText: false,
            labelFontSize: 12,
            valueFontSize: 12,
            enabled: !keepOriginal,
          ),
        ],
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

class _NotificationPolicyTable extends StatelessWidget {
  const _NotificationPolicyTable({
    required this.policies,
    required this.onChanged,
  });

  final Map<NotificationEventType, NotificationDeliveryMode> policies;
  final void Function(
    NotificationEventType event,
    NotificationDeliveryMode mode,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: colors.surfaceMuted,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '通知类型',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Center(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '投递方式',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final event in NotificationEventType.values)
            _NotificationPolicyTableRow(
              event: event,
              value: policies[event] ?? defaultNotificationPolicies[event]!,
              onChanged: (value) => onChanged(event, value),
            ),
        ],
      ),
    );
  }
}

class _NotificationPolicyTableRow extends StatelessWidget {
  const _NotificationPolicyTableRow({
    required this.event,
    required this.value,
    required this.onChanged,
  });

  final NotificationEventType event;
  final NotificationDeliveryMode value;
  final ValueChanged<NotificationDeliveryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                event.settingsLabel,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConfigDropdown<NotificationDeliveryMode>(
                  label: event.settingsLabel,
                  trailingText: '',
                  value: value,
                  values: NotificationDeliveryMode.values,
                  itemLabel: (value) => value.settingsLabel,
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                  height: _AppSettingsViewState._fieldHeight,
                  showLabel: false,
                  showTrailingText: false,
                  labelFontSize: 12,
                  valueFontSize: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutBindingRow extends StatelessWidget {
  const _ShortcutBindingRow({
    required this.action,
    required this.binding,
    required this.onRecord,
  });

  final AppShortcutAction action;
  final AppShortcutBinding binding;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.settingsLabel,
              style: TextStyle(color: colors.textPrimary, fontSize: 12),
            ),
          ),
          OutlinedButton(
            onPressed: onRecord,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(132, 28),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: colors.borderStrong),
            ),
            child: Text(shortcutBindingLabel(binding)),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRecorderDialog extends StatefulWidget {
  const _ShortcutRecorderDialog({required this.action});

  final AppShortcutAction action;

  @override
  State<_ShortcutRecorderDialog> createState() =>
      _ShortcutRecorderDialogState();
}

class _ShortcutRecorderDialogState extends State<_ShortcutRecorderDialog> {
  AppShortcutBinding? _recordedBinding;
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'ShortcutRecorderDialog',
  );
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _cancelRecording() {
    if (_completed) return;
    _completed = true;
    Navigator.of(context).pop();
  }

  void _completeRecording(AppShortcutBinding binding) {
    if (_completed) return;
    _completed = true;
    Navigator.of(context).pop(binding);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Actions(
      actions: <Type, Action<Intent>>{
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _cancelRecording();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelRecording();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AppDialogFrame(
          maxWidth: 410,
          child: Stack(
            children: [
              Offstage(
                child: HotKeyRecorder(
                  onHotKeyRecorded: (hotKey) {
                    if (hotKey.logicalKey == LogicalKeyboardKey.escape) {
                      _cancelRecording();
                      return;
                    }
                    if (hotKeyIsOnlyModifier(hotKey)) {
                      return;
                    }
                    final binding = shortcutBindingFromHotKey(hotKey);
                    setState(() {
                      _recordedBinding = binding;
                    });
                    _completeRecording(binding);
                  },
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppDialogTitle('设置“${widget.action.settingsLabel}”快捷键'),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.primary),
                    ),
                    child: Text(
                      _recordedBinding == null
                          ? '请按下新的快捷键组合\n按 Esc 取消'
                          : '已录入 ${shortcutBindingLabel(_recordedBinding!)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppDialogActionButton(
                        label: '取消',
                        backgroundColor: colors.statusCancelled,
                        onPressed: _cancelRecording,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
