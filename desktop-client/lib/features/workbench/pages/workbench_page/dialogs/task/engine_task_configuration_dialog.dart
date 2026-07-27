import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/engine_configuration_editor_model.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_template.dart';

/// Opens the Engine-backed task configuration editor.
///
/// The dialog is deliberately a projection of [snapshot]. It does not
/// consult the legacy compression policies or construct a legacy task config.
Future<MediaTask?> showEngineTaskConfigurationEditor({
  required BuildContext context,
  required MediaTask task,
  required EngineAnalysisSnapshotDocument snapshot,
  required Future<MediaTask?> Function(EngineConfigurationSelection selection)
  onResolve,
  ImageProvider? thumbnail,
  Widget? sourceSummary,
  VoidCallback? onOpenSource,
}) {
  return showDialog<MediaTask>(
    context: context,
    builder: (dialogContext) {
      return _EngineTaskConfigurationDialog(
        task: task,
        snapshot: snapshot,
        onResolve: onResolve,
        thumbnail: thumbnail,
        sourceSummary: sourceSummary,
        onOpenSource: onOpenSource,
      );
    },
  );
}

class _EngineTaskConfigurationDialog extends StatefulWidget {
  const _EngineTaskConfigurationDialog({
    required this.task,
    required this.snapshot,
    required this.onResolve,
    this.thumbnail,
    this.sourceSummary,
    this.onOpenSource,
  });

  final MediaTask task;
  final EngineAnalysisSnapshotDocument snapshot;
  final Future<MediaTask?> Function(EngineConfigurationSelection selection)
  onResolve;
  final ImageProvider? thumbnail;
  final Widget? sourceSummary;
  final VoidCallback? onOpenSource;

  @override
  State<_EngineTaskConfigurationDialog> createState() =>
      _EngineTaskConfigurationDialogState();
}

class _EngineTaskConfigurationDialogState
    extends State<_EngineTaskConfigurationDialog> {
  late EngineConfigurationEditorModel _model;
  late EngineConfigurationEditorMode? _activeMode;
  late final TextEditingController _targetController;

  String? _errorText;
  String? _targetFieldError;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _model = EngineConfigurationEditorModel(
      snapshot: widget.snapshot,
      reference: widget.task.config.engineConfiguration,
    );
    _activeMode = _initialMode(_model);
    if (_activeMode == EngineConfigurationEditorMode.targetSize &&
        _model.mode != EngineConfigurationEditorMode.targetSize) {
      _model = _targetModelFromDefaults(_model);
    }
    _targetController = TextEditingController(
      text: _targetTextForModel(_model),
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saveEnabled = _canSave;
    final saveLabel = _resolving ? '处理中' : '保存';

    return TaskConfigDialogTemplate(
      task: widget.task,
      title: 'Engine 任务配置',
      onClose: () => Navigator.of(context).pop(),
      onOpenSource: widget.onOpenSource,
      thumbnail: widget.thumbnail,
      sourceSummary: widget.sourceSummary,
      selectedPurpose: _purposeForMode(widget.snapshot.taskMode),
      onPurposeChanged: (_) {},
      showPurposeSelector: false,
      primaryContent: _buildPrimaryContent(context),
      threadLimit: null,
      onThreadLimitChanged: (_) {},
      advancedContent: null,
      modified: false,
      saveEnabled: saveEnabled,
      saveLabel: saveLabel,
      onSave: _resolve,
    );
  }

  bool get _canSave {
    if (_resolving || !widget.snapshot.validity.isValid) {
      return false;
    }
    if (_activeMode == null || _model.mode != _activeMode) {
      return false;
    }
    if (_targetFieldError != null) {
      return false;
    }
    return _model.canResolve;
  }

  EngineConfigurationEditorMode? _initialMode(
    EngineConfigurationEditorModel model,
  ) {
    if (model.mode != null) {
      return model.mode;
    }
    if (model.availablePresets.isNotEmpty) {
      return EngineConfigurationEditorMode.preset;
    }
    if (model.candidateIds.isNotEmpty) {
      return EngineConfigurationEditorMode.manual;
    }
    return null;
  }

  EngineConfigurationEditorModel _baseModel() {
    return EngineConfigurationEditorModel(snapshot: widget.snapshot);
  }

  EngineConfigurationEditorModel _targetModelFromDefaults(
    EngineConfigurationEditorModel base,
  ) {
    final defaultBytes = base.customTargetSize.defaultBytes;
    if (defaultBytes == null) {
      return base;
    }
    return base.selectTargetSize(
      targetBytes: defaultBytes,
      allowResolutionChange: false,
      allowFrameRateChange: false,
    );
  }

  String _targetTextForModel(EngineConfigurationEditorModel model) {
    final value = model.targetBytes ?? model.customTargetSize.defaultBytes;
    return value?.toString() ?? '';
  }

  void _switchMode(EngineConfigurationEditorMode mode) {
    var next = _baseModel();
    if (mode == EngineConfigurationEditorMode.targetSize) {
      next = _targetModelFromDefaults(next);
    }
    setState(() {
      _activeMode = mode;
      _model = next;
      _errorText = null;
      _targetFieldError = null;
      _targetController.text = _targetTextForModel(next);
      _targetController.selection = TextSelection.collapsed(
        offset: _targetController.text.length,
      );
    });
  }

  Widget _buildPrimaryContent(BuildContext context) {
    final children = <Widget>[
      _buildTaskModeSummary(context),
      const SizedBox(height: 14),
    ];

    if (!widget.snapshot.validity.isValid) {
      children.add(
        _UnavailablePanel(
          title: '分析结果不可用',
          message: widget.snapshot.validity.message ?? '当前分析结果已失效，请重新分析源文件。',
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    if (_model.candidateIds.isEmpty) {
      children.add(
        _UnavailablePanel(
          title: '当前配置不可用',
          message: _model.validationMessage ?? '当前分析结果没有可执行候选方案。',
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    if (_model.availablePresets.isEmpty &&
        _activeMode != EngineConfigurationEditorMode.preset) {
      children.add(
        const _UnavailablePanel(
          title: '预设不可用',
          message: '当前分析结果没有可用预设。手动配置仍可使用，请勿使用旧预设回退。',
        ),
      );
      children.add(const SizedBox(height: 14));
    }

    children.add(_buildRecommendation(context));
    children.add(const SizedBox(height: 14));

    final modeChoices = _modeChoices;
    if (modeChoices.length > 1) {
      children.add(_buildModeSelector(context, modeChoices));
      children.add(const SizedBox(height: 14));
    }

    final activeMode = _activeMode;
    if (activeMode == null) {
      children.add(
        _UnavailablePanel(title: '请选择配置方式', message: '当前分析结果尚未选择预设或候选方案。'),
      );
    } else {
      children.add(switch (activeMode) {
        EngineConfigurationEditorMode.preset => _buildPresetMode(context),
        EngineConfigurationEditorMode.manual => _buildManualMode(context),
        EngineConfigurationEditorMode.targetSize => _buildTargetSizeMode(
          context,
        ),
      });
    }

    if (_errorText != null) {
      children.add(const SizedBox(height: 12));
      children.add(_ErrorPanel(message: _errorText!));
    }

    final validation = _activeValidationMessage;
    if (validation != null && _errorText == null) {
      children.add(const SizedBox(height: 12));
      children.add(_ValidationMessage(message: validation));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<EngineConfigurationEditorMode> get _modeChoices {
    final modes = <EngineConfigurationEditorMode>[
      EngineConfigurationEditorMode.preset,
      EngineConfigurationEditorMode.manual,
    ];
    if (_model.hasCompleteTargetSizeRange) {
      modes.add(EngineConfigurationEditorMode.targetSize);
    }
    return modes;
  }

  String? get _activeValidationMessage {
    if (_activeMode == null || _model.mode != _activeMode) {
      return null;
    }
    return _targetFieldError ?? _model.validationMessage;
  }

  Widget _buildTaskModeSummary(BuildContext context) {
    final colors = context.frameLeanColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: colors.iconMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '任务模式已由分析结果锁定：',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.flSp,
                ),
                children: [
                  TextSpan(
                    text: _taskModeLabel(widget.snapshot.taskMode),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation(BuildContext context) {
    final colors = context.frameLeanColors;
    final recommendation = widget.snapshot.recommendation;
    final estimate = recommendation.estimate;
    final title = recommendation.status == 'complete' ? '推荐方案' : '推荐方案不可用';
    final body = estimate == null
        ? (recommendation.reasons.isEmpty
              ? '分析结果没有提供推荐方案。'
              : recommendation.reasons.join('；'))
        : '预计输出 ${_formatBytes(estimate.expectedBytes)}'
              '（${estimate.confidence}）';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.primary.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.flSp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.flSp,
              height: 1.35,
            ),
          ),
          if (recommendation.reasons.isNotEmpty && estimate != null) ...[
            const SizedBox(height: 4),
            Text(
              recommendation.reasons.join('；'),
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 10.flSp,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeSelector(
    BuildContext context,
    List<EngineConfigurationEditorMode> modes,
  ) {
    final colors = context.frameLeanColors;
    final labels = <EngineConfigurationEditorMode, Widget>{
      EngineConfigurationEditorMode.preset: const Text('预设'),
      EngineConfigurationEditorMode.manual: const Text('手动配置'),
      if (modes.contains(EngineConfigurationEditorMode.targetSize))
        EngineConfigurationEditorMode.targetSize: const Text('目标体积'),
    };
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: CupertinoSlidingSegmentedControl<EngineConfigurationEditorMode>(
        groupValue: _activeMode,
        backgroundColor: colors.surfaceDisabled,
        thumbColor: colors.surface,
        padding: const EdgeInsets.all(3),
        children: labels,
        onValueChanged: (value) {
          if (value != null && !_resolving) {
            _switchMode(value);
          }
        },
      ),
    );
  }

  Widget _buildPresetMode(BuildContext context) {
    final presets = widget.snapshot.availablePresets;
    if (presets.isEmpty) {
      return const _UnavailablePanel(
        title: '预设不可用',
        message: '当前分析结果没有可用预设。请选择手动配置或重新分析。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '可用预设',
          style: TextStyle(
            color: context.frameLeanColors.textSecondary,
            fontSize: 11.flSp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final preset in presets) ...[
          _PresetCard(
            preset: preset,
            selected:
                _model.mode == EngineConfigurationEditorMode.preset &&
                _model.selectedPresetId == preset.id,
            onTap: _resolving ? null : () => _selectPreset(preset),
          ),
          if (preset != presets.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _selectPreset(EnginePresetOption preset) {
    setState(() {
      _activeMode = EngineConfigurationEditorMode.preset;
      _model = _model.selectPreset(preset.id);
      _errorText = null;
    });
  }

  Widget _buildManualMode(BuildContext context) {
    final candidateIds = _model.candidateIds;
    if (candidateIds.isEmpty) {
      return const _UnavailablePanel(
        title: '手动配置不可用',
        message: '当前分析结果没有可执行候选方案。',
      );
    }

    final isManual = _model.mode == EngineConfigurationEditorMode.manual;
    final selectedCandidate = isManual ? _model.selectedCandidateId : null;
    final candidateValues = <String>['', ...candidateIds];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigDropdown<String>(
          label: '执行候选方案',
          trailingText: '',
          value: selectedCandidate ?? '',
          values: candidateValues,
          itemLabel: (value) => value.isEmpty ? '请选择候选方案' : value,
          onChanged: _resolving
              ? (_) {}
              : (value) {
                  if (value != null && value.isNotEmpty) {
                    _selectManualCandidate(value);
                  }
                },
          height: 40,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
          enabled: !_resolving,
        ),
        if (!isManual || selectedCandidate == null) ...[
          const SizedBox(height: 8),
          Text(
            '手动参数将根据所选候选方案过滤。',
            style: TextStyle(
              color: context.frameLeanColors.textTertiary,
              fontSize: 10.flSp,
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildManualOverrides(context),
        ],
      ],
    );
  }

  void _selectManualCandidate(String candidateId) {
    final preserveOverrides =
        _model.mode == EngineConfigurationEditorMode.manual &&
        _model.selectedCandidateId == candidateId;
    setState(() {
      _activeMode = EngineConfigurationEditorMode.manual;
      _model = _model.selectManual(
        candidateId: candidateId,
        overrides: preserveOverrides
            ? _model.manualOverrides
            : const EngineManualOverrides(),
      );
      _errorText = null;
      _targetFieldError = null;
    });
  }

  Widget _buildManualOverrides(BuildContext context) {
    final fields = <Widget>[];
    _addOverrideDropdown(
      fields,
      field: 'containers',
      label: '输出容器',
      currentValue: _model.manualOverrides.container,
      onChanged: (value) =>
          _updateManualOverride(field: 'containers', value: value),
    );
    _addOverrideDropdown(
      fields,
      field: 'video_codecs',
      label: '视频编码',
      currentValue: _model.manualOverrides.videoCodec,
      onChanged: (value) =>
          _updateManualOverride(field: 'video_codecs', value: value),
    );
    _addOverrideDropdown(
      fields,
      field: 'audio_codecs',
      label: '音频编码',
      currentValue: _model.manualOverrides.audioCodec,
      onChanged: (value) =>
          _updateManualOverride(field: 'audio_codecs', value: value),
    );
    _addOverrideDropdown(
      fields,
      field: 'pixel_formats',
      label: '输出像素格式',
      currentValue: _model.manualOverrides.outputPixelFormat,
      onChanged: (value) =>
          _updateManualOverride(field: 'pixel_formats', value: value),
    );
    _addOverrideDropdown(
      fields,
      field: 'preserves_hdr',
      label: 'HDR 保留',
      currentValue: _model.manualOverrides.preservesHdr,
      onChanged: (value) =>
          _updateManualOverride(field: 'preserves_hdr', value: value),
      valueLabel: _formatOptionValue,
    );

    final readOnlyFields = <String, String>{
      'video_profiles': '视频 Profile',
      'video_encoders': '视频编码器',
      'audio_encoders': '音频编码器',
      'bit_depths': '位深',
      'hdr_modes': 'HDR 模式',
      'requires_tone_mapping': '色调映射',
    };
    for (final entry in readOnlyFields.entries) {
      final options = _model.optionsForField(entry.key);
      if (options.isEmpty) {
        continue;
      }
      fields.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _ReadOnlyOptionLine(
            label: entry.value,
            value: options
                .map((option) => _formatOptionValue(option.value))
                .join('、'),
          ),
        ),
      );
    }

    if (fields.isEmpty) {
      return Text(
        '当前候选方案没有可覆盖的配置项，将使用候选方案默认值。',
        style: TextStyle(
          color: context.frameLeanColors.textTertiary,
          fontSize: 11.flSp,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          fields[index],
        ],
      ],
    );
  }

  void _addOverrideDropdown(
    List<Widget> fields, {
    required String field,
    required String label,
    required Object? currentValue,
    required ValueChanged<Object?> onChanged,
    String Function(Object? value)? valueLabel,
  }) {
    final options = _model.optionsForField(field);
    if (options.isEmpty) {
      return;
    }
    final choices = <_EngineOptionChoice>[
      const _EngineOptionChoice(value: null, label: '候选方案默认'),
    ];
    final seen = <String>{};
    for (final option in options) {
      final key = _optionValueKey(option.value);
      if (!seen.add(key)) {
        continue;
      }
      choices.add(
        _EngineOptionChoice(
          value: option.value,
          label: (valueLabel ?? _formatOptionValue)(option.value),
        ),
      );
    }
    final selected = choices.firstWhere(
      (choice) => _sameOptionValue(choice.value, currentValue),
      orElse: () => choices.first,
    );
    fields.add(
      ConfigDropdown<_EngineOptionChoice>(
        label: label,
        trailingText: '',
        value: selected,
        values: choices,
        itemLabel: (choice) => choice.label,
        onChanged: _resolving ? (_) {} : (choice) => onChanged(choice?.value),
        height: 40,
        showTrailingText: false,
        labelFontSize: 12,
        valueFontSize: 12,
        enabled: !_resolving,
      ),
    );
  }

  void _updateManualOverride({required String field, required Object? value}) {
    final current = _model.manualOverrides;
    final next = EngineManualOverrides(
      container: field == 'containers' ? value as String? : current.container,
      videoCodec: field == 'video_codecs'
          ? value as String?
          : current.videoCodec,
      audioCodec: field == 'audio_codecs'
          ? value as String?
          : current.audioCodec,
      outputPixelFormat: field == 'pixel_formats'
          ? value as String?
          : current.outputPixelFormat,
      preservesHdr: field == 'preserves_hdr'
          ? value as bool?
          : current.preservesHdr,
    );
    final candidateId = _model.selectedCandidateId;
    if (candidateId == null) {
      return;
    }
    setState(() {
      _model = _model.selectManual(candidateId: candidateId, overrides: next);
      _errorText = null;
    });
  }

  Widget _buildTargetSizeMode(BuildContext context) {
    final target = _model.customTargetSize;
    if (!_model.hasCompleteTargetSizeRange) {
      return _UnavailablePanel(
        title: '目标体积不可用',
        message: target.unavailableReason ?? '当前分析结果不支持目标体积模式。',
      );
    }

    final candidateIds = _model.candidateIds;
    final selectedCandidate =
        _model.mode == EngineConfigurationEditorMode.targetSize
        ? _model.selectedCandidateId
        : null;
    final candidateValues = <String>['', ...candidateIds];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigDropdown<String>(
          label: '执行候选方案',
          trailingText: '',
          value: selectedCandidate ?? '',
          values: candidateValues,
          itemLabel: (value) => value.isEmpty ? '请选择候选方案' : value,
          onChanged: _resolving
              ? (_) {}
              : (value) {
                  if (value != null && value.isNotEmpty) {
                    _selectTargetCandidate(value);
                  }
                },
          height: 40,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
          enabled: !_resolving,
        ),
        const SizedBox(height: 12),
        Text(
          '目标体积（${target.displayUnit}）',
          style: TextStyle(
            color: context.frameLeanColors.textPrimary,
            fontSize: 12.flSp,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _targetController,
                enabled: !_resolving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onTargetTextChanged,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: target.displayUnit,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(
                      color: context.frameLeanColors.border,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TargetStepButton(
              icon: Icons.remove,
              tooltip: '减少目标体积',
              onPressed: _resolving ? null : () => _adjustTargetValue(-1),
            ),
            const SizedBox(width: 6),
            _TargetStepButton(
              icon: Icons.add,
              tooltip: '增加目标体积',
              onPressed: _resolving ? null : () => _adjustTargetValue(1),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '范围 ${target.minimumBytes}–${target.maximumBytes}，步长 ${target.stepBytes}',
          style: TextStyle(
            color: context.frameLeanColors.textTertiary,
            fontSize: 10.flSp,
          ),
        ),
        const SizedBox(height: 8),
        ConfigCheckbox(
          label: '允许调整分辨率',
          value: _model.allowResolutionChange,
          onChanged: _resolving
              ? (_) {}
              : (value) => _updateTargetFlags(allowResolutionChange: value),
        ),
        ConfigCheckbox(
          label: '允许调整帧率',
          value: _model.allowFrameRateChange,
          onChanged: _resolving
              ? (_) {}
              : (value) => _updateTargetFlags(allowFrameRateChange: value),
        ),
      ],
    );
  }

  void _selectTargetCandidate(String candidateId) {
    final target = _model.customTargetSize;
    final value =
        int.tryParse(_targetController.text) ??
        target.defaultBytes ??
        target.minimumBytes!;
    setState(() {
      _activeMode = EngineConfigurationEditorMode.targetSize;
      _model = _model.selectTargetSize(
        candidateId: candidateId,
        targetBytes: value,
        allowResolutionChange: _model.allowResolutionChange,
        allowFrameRateChange: _model.allowFrameRateChange,
      );
      _errorText = null;
    });
  }

  void _updateTargetFlags({
    bool? allowResolutionChange,
    bool? allowFrameRateChange,
  }) {
    final target = _model.customTargetSize;
    final value =
        int.tryParse(_targetController.text) ??
        target.defaultBytes ??
        target.minimumBytes!;
    setState(() {
      _model = _model.selectTargetSize(
        candidateId: _model.selectedCandidateId,
        targetBytes: value,
        allowResolutionChange:
            allowResolutionChange ?? _model.allowResolutionChange,
        allowFrameRateChange:
            allowFrameRateChange ?? _model.allowFrameRateChange,
      );
      _errorText = null;
    });
  }

  void _onTargetTextChanged(String text) {
    final parsed = int.tryParse(text);
    final target = _model.customTargetSize;
    String? fieldError;
    if (parsed == null || parsed <= 0) {
      fieldError = '请输入正整数目标体积。';
    } else if (target.minimumBytes != null &&
        target.maximumBytes != null &&
        (parsed < target.minimumBytes! || parsed > target.maximumBytes!)) {
      fieldError = '目标体积超出可用范围。';
    } else if (target.stepBytes != null &&
        target.minimumBytes != null &&
        (parsed - target.minimumBytes!) % target.stepBytes! != 0) {
      fieldError = '目标体积必须按 ${target.stepBytes} 的步长调整。';
    }

    setState(() {
      _targetFieldError = fieldError;
      if (parsed != null && parsed > 0) {
        _model = _model.selectTargetSize(
          candidateId: _model.selectedCandidateId,
          targetBytes: parsed,
          allowResolutionChange: _model.allowResolutionChange,
          allowFrameRateChange: _model.allowFrameRateChange,
        );
      }
      _errorText = null;
    });
  }

  void _adjustTargetValue(int direction) {
    final target = _model.customTargetSize;
    final current =
        int.tryParse(_targetController.text) ??
        target.defaultBytes ??
        target.minimumBytes!;
    final step = target.stepBytes!;
    final minimum = target.minimumBytes!;
    final maximum = target.maximumBytes!;
    final next = (current + direction * step).clamp(minimum, maximum);
    _targetController.text = next.toString();
    _targetController.selection = TextSelection.collapsed(
      offset: _targetController.text.length,
    );
    _onTargetTextChanged(_targetController.text);
  }

  Future<void> _resolve() async {
    if (_resolving) {
      return;
    }
    if (!widget.snapshot.validity.isValid) {
      setState(() {
        _errorText = widget.snapshot.validity.message ?? '分析结果已失效，请重新分析。';
      });
      return;
    }
    if (_targetFieldError != null) {
      setState(() {
        _errorText = _targetFieldError;
      });
      return;
    }
    final selection = _model.selection;
    if (selection == null || _activeMode != _model.mode) {
      setState(() {
        _errorText = _model.validationMessage ?? '请选择有效的 Engine 配置。';
      });
      return;
    }

    setState(() {
      _resolving = true;
      _errorText = null;
    });
    try {
      final updatedTask = await widget.onResolve(selection);
      if (!mounted) {
        return;
      }
      if (updatedTask != null) {
        Navigator.of(context).pop(updatedTask);
        return;
      }
      setState(() {
        _resolving = false;
        _errorText = '配置解析未返回可保存的任务。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _resolving = false;
        _errorText = '配置解析失败：${_errorMessage(error)}';
      });
    }
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final EnginePresetOption preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final estimate = preset.estimate;
    final borderColor = selected ? colors.primary : colors.border;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: BoxDecoration(
            color: selected ? colors.primarySoft : colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      preset.displayName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.flSp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: colors.primary, size: 16),
                ],
              ),
              if (preset.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  preset.description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.flSp,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Text(
                estimate == null
                    ? '预计输出：未提供'
                    : '预计输出：${_formatBytes(estimate.expectedBytes)}',
                style: TextStyle(color: colors.textTertiary, fontSize: 10.flSp),
              ),
              if (preset.risks.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '风险：${preset.risks.join('；')}',
                  style: TextStyle(
                    color: colors.statusFailed,
                    fontSize: 10.flSp,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: colors.failedSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.statusFailed.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.statusFailed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.flSp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.flSp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Text(
      message,
      style: TextStyle(
        color: colors.statusFailed,
        fontSize: 11.flSp,
        height: 1.35,
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: context.frameLeanColors.textTertiary,
        fontSize: 10.flSp,
      ),
    );
  }
}

class _ReadOnlyOptionLine extends StatelessWidget {
  const _ReadOnlyOptionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.flSp),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: colors.textTertiary, fontSize: 11.flSp),
          ),
        ),
      ],
    );
  }
}

class _TargetStepButton extends StatelessWidget {
  const _TargetStepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _EngineOptionChoice {
  const _EngineOptionChoice({required this.value, required this.label});

  final Object? value;
  final String label;

  @override
  bool operator ==(Object other) {
    return other is _EngineOptionChoice && _sameOptionValue(value, other.value);
  }

  @override
  int get hashCode => _optionValueKey(value).hashCode;
}

TaskPurpose _purposeForMode(EngineTaskMode mode) {
  return switch (mode) {
    EngineTaskMode.videoCompress ||
    EngineTaskMode.audioCompress ||
    EngineTaskMode.imageCompress => TaskPurpose.compression,
    EngineTaskMode.videoConvert ||
    EngineTaskMode.audioConvert ||
    EngineTaskMode.imageConvert => TaskPurpose.conversion,
  };
}

String _taskModeLabel(EngineTaskMode mode) {
  return switch (mode) {
    EngineTaskMode.videoCompress => '视频压缩',
    EngineTaskMode.videoConvert => '视频转换',
    EngineTaskMode.audioCompress => '音频压缩',
    EngineTaskMode.audioConvert => '音频转换',
    EngineTaskMode.imageCompress => '图片压缩',
    EngineTaskMode.imageConvert => '图片转换',
  };
}

String _formatOptionValue(Object? value) {
  if (value == null) {
    return '候选方案默认';
  }
  if (value is bool) {
    return value ? '是' : '否';
  }
  if (value is List) {
    return value.map(_formatOptionValue).join('、');
  }
  if (value is Map) {
    return jsonEncode(value);
  }
  return value.toString();
}

String _optionValueKey(Object? value) {
  try {
    return jsonEncode(value);
  } on JsonUnsupportedObjectError {
    return '${value.runtimeType}:$value';
  }
}

bool _sameOptionValue(Object? left, Object? right) {
  return _optionValueKey(left) == _optionValueKey(right);
}

String _errorMessage(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return text;
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return '-';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  if (unitIndex == 0) {
    return '${value.round()}${units[unitIndex]}';
  }
  final rendered = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$rendered${units[unitIndex]}';
}
