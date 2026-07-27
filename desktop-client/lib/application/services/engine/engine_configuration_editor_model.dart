import 'dart:convert';

import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';

/// Snapshot-backed configuration state shared by single-task and folder flows.
enum EngineConfigurationEditorMode { preset, manual, targetSize }

final class EngineConfigurationEditorModel {
  factory EngineConfigurationEditorModel({
    required EngineAnalysisSnapshotDocument snapshot,
    EngineConfigurationReference? reference,
  }) {
    final candidateIds = snapshot.configurationOptions.candidateIds;
    final referenceMatches =
        reference != null &&
        reference.analysisId == snapshot.analysisId &&
        reference.analysisRevision == snapshot.analysisRevision;
    final referenceCandidateId =
        referenceMatches && candidateIds.contains(reference.candidateId)
        ? reference.candidateId
        : null;
    final recommendationCandidateId =
        snapshot.recommendation.configuration?.executionChainId;
    final selectedCandidateId =
        referenceCandidateId ??
        (candidateIds.contains(recommendationCandidateId)
            ? recommendationCandidateId
            : null) ??
        (candidateIds.length == 1 ? candidateIds.single : null);

    final model = EngineConfigurationEditorModel._(
      snapshot: snapshot,
      mode: null,
      selectedCandidateId: selectedCandidateId,
      selectedPresetId: null,
      manualOverrides: const EngineManualOverrides(),
      targetBytes: null,
      allowResolutionChange: false,
      allowFrameRateChange: false,
    );
    if (!referenceMatches) {
      return model;
    }
    return model._restoreReference(reference) ?? model;
  }

  const EngineConfigurationEditorModel._({
    required EngineAnalysisSnapshotDocument snapshot,
    required this.mode,
    required this.selectedCandidateId,
    required this.selectedPresetId,
    required this.manualOverrides,
    required this.targetBytes,
    required this.allowResolutionChange,
    required this.allowFrameRateChange,
  }) : _snapshot = snapshot;

  final EngineAnalysisSnapshotDocument _snapshot;
  final EngineConfigurationEditorMode? mode;
  final String? selectedCandidateId;
  final String? selectedPresetId;
  final EngineManualOverrides manualOverrides;
  final int? targetBytes;
  final bool allowResolutionChange;
  final bool allowFrameRateChange;

  String get analysisId => _snapshot.analysisId;

  int get analysisRevision => _snapshot.analysisRevision;

  List<EnginePresetOption> get availablePresets => _snapshot.availablePresets;

  List<String> get candidateIds => _snapshot.configurationOptions.candidateIds;

  EngineRecommendationDocument get recommendation => _snapshot.recommendation;

  EngineCustomTargetSizeDocument get customTargetSize =>
      _snapshot.customTargetSize;

  Map<String, List<EngineConfigurationOption>> get manualOptions {
    final candidateId = selectedCandidateId;
    if (candidateId == null || !candidateIds.contains(candidateId)) {
      return const {};
    }
    final result = <String, List<EngineConfigurationOption>>{};
    for (final entry in _snapshot.configurationOptions.optionsByField.entries) {
      result[entry.key] = List<EngineConfigurationOption>.unmodifiable(
        entry.value.where(
          (option) => option.candidateIds.contains(candidateId),
        ),
      );
    }
    return Map<String, List<EngineConfigurationOption>>.unmodifiable(result);
  }

  List<EngineConfigurationOption> optionsForField(String field) {
    return manualOptions[field] ?? const [];
  }

  bool get hasCompleteTargetSizeRange {
    final minimumBytes = customTargetSize.minimumBytes;
    final maximumBytes = customTargetSize.maximumBytes;
    final defaultBytes = customTargetSize.defaultBytes;
    final stepBytes = customTargetSize.stepBytes;
    return customTargetSize.available &&
        minimumBytes != null &&
        maximumBytes != null &&
        defaultBytes != null &&
        stepBytes != null &&
        minimumBytes <= maximumBytes &&
        defaultBytes >= minimumBytes &&
        defaultBytes <= maximumBytes &&
        stepBytes > 0;
  }

  EngineConfigurationSelection? get selection {
    return switch (mode) {
      EngineConfigurationEditorMode.preset => _presetSelection(),
      EngineConfigurationEditorMode.manual => _manualSelection(),
      EngineConfigurationEditorMode.targetSize => _targetSizeSelection(),
      null => null,
    };
  }

  bool get canResolve => selection != null;

  String? get validationMessage {
    if (candidateIds.isEmpty) {
      return '当前分析结果没有可执行候选方案。';
    }
    final currentMode = mode;
    if (currentMode == null) {
      return selectedCandidateId == null ? '请选择一个候选方案。' : '请选择配置方式。';
    }
    return switch (currentMode) {
      EngineConfigurationEditorMode.preset => _presetValidationMessage(),
      EngineConfigurationEditorMode.manual => _manualValidationMessage(),
      EngineConfigurationEditorMode.targetSize =>
        _targetSizeValidationMessage(),
    };
  }

  EngineConfigurationEditorModel selectPreset(
    String presetId, {
    EngineManualOverrides overrides = const EngineManualOverrides(),
  }) {
    final preset = _findAvailablePreset(presetId);
    return _copyWith(
      mode: EngineConfigurationEditorMode.preset,
      selectedCandidateId: preset?.candidate?.id,
      selectedPresetId: presetId,
      manualOverrides: overrides,
      targetBytes: null,
      allowResolutionChange: false,
      allowFrameRateChange: false,
    );
  }

  EngineConfigurationEditorModel selectManual({
    required String candidateId,
    EngineManualOverrides overrides = const EngineManualOverrides(),
  }) {
    return _copyWith(
      mode: EngineConfigurationEditorMode.manual,
      selectedCandidateId: candidateId,
      selectedPresetId: null,
      manualOverrides: overrides,
      targetBytes: null,
      allowResolutionChange: false,
      allowFrameRateChange: false,
    );
  }

  EngineConfigurationEditorModel selectTargetSize({
    String? candidateId,
    required int targetBytes,
    required bool allowResolutionChange,
    required bool allowFrameRateChange,
  }) {
    return _copyWith(
      mode: EngineConfigurationEditorMode.targetSize,
      selectedCandidateId: candidateId ?? selectedCandidateId,
      selectedPresetId: null,
      manualOverrides: const EngineManualOverrides(),
      targetBytes: targetBytes,
      allowResolutionChange: allowResolutionChange,
      allowFrameRateChange: allowFrameRateChange,
    );
  }

  EngineConfigurationEditorModel _copyWith({
    required EngineConfigurationEditorMode? mode,
    required String? selectedCandidateId,
    required String? selectedPresetId,
    required EngineManualOverrides manualOverrides,
    required int? targetBytes,
    required bool allowResolutionChange,
    required bool allowFrameRateChange,
  }) {
    return EngineConfigurationEditorModel._(
      snapshot: _snapshot,
      mode: mode,
      selectedCandidateId: selectedCandidateId,
      selectedPresetId: selectedPresetId,
      manualOverrides: manualOverrides,
      targetBytes: targetBytes,
      allowResolutionChange: allowResolutionChange,
      allowFrameRateChange: allowFrameRateChange,
    );
  }

  EngineConfigurationEditorModel? _restoreReference(
    EngineConfigurationReference reference,
  ) {
    final root = _decodeObject(reference.selectionJson);
    if (root == null) {
      return null;
    }
    final encodedMode = root['mode'];
    if (encodedMode != null &&
        (encodedMode is! String || encodedMode != reference.selectionMode)) {
      return null;
    }
    final selectionJson = root.containsKey('selection')
        ? _asObject(root['selection'])
        : root;
    if (selectionJson == null) {
      return null;
    }
    final encodedCandidateId = selectionJson['candidate_id'];
    if (encodedCandidateId != null &&
        (encodedCandidateId is! String ||
            encodedCandidateId != reference.candidateId)) {
      return null;
    }
    if (!candidateIds.contains(reference.candidateId)) {
      return null;
    }

    final restored = switch (reference.selectionMode) {
      'preset' => _restorePreset(reference, selectionJson),
      'manual' => _restoreManual(reference, selectionJson),
      'custom_target_size' => _restoreTargetSize(reference, selectionJson),
      _ => null,
    };
    return restored?.canResolve == true ? restored : null;
  }

  EngineConfigurationEditorModel? _restorePreset(
    EngineConfigurationReference reference,
    Map<String, Object?> selectionJson,
  ) {
    final presetId = selectionJson['preset_id'];
    if (presetId is! String || presetId.trim().isEmpty) {
      return null;
    }
    final overrides = _parseOverrides(selectionJson);
    if (overrides == null) {
      return null;
    }
    final restored = selectPreset(presetId, overrides: overrides);
    return restored.selectedCandidateId == reference.candidateId
        ? restored
        : null;
  }

  EngineConfigurationEditorModel? _restoreManual(
    EngineConfigurationReference reference,
    Map<String, Object?> selectionJson,
  ) {
    final overrides = _parseOverrides(selectionJson);
    if (overrides == null) {
      return null;
    }
    return selectManual(
      candidateId: reference.candidateId,
      overrides: overrides,
    );
  }

  EngineConfigurationEditorModel? _restoreTargetSize(
    EngineConfigurationReference reference,
    Map<String, Object?> selectionJson,
  ) {
    final targetBytes = selectionJson['target_bytes'];
    final allowResolutionChange = selectionJson['allow_resolution_change'];
    final allowFrameRateChange = selectionJson['allow_frame_rate_change'];
    if (targetBytes is! int ||
        allowResolutionChange is! bool ||
        allowFrameRateChange is! bool) {
      return null;
    }
    return selectTargetSize(
      candidateId: reference.candidateId,
      targetBytes: targetBytes,
      allowResolutionChange: allowResolutionChange,
      allowFrameRateChange: allowFrameRateChange,
    );
  }

  EnginePresetSelection? _presetSelection() {
    if (_presetValidationMessage() != null) {
      return null;
    }
    final preset = _findAvailablePreset(selectedPresetId!);
    return EnginePresetSelection(
      presetId: preset!.id,
      candidateId: preset.candidate!.id,
      overrides: manualOverrides,
    );
  }

  EngineManualConfigurationSelection? _manualSelection() {
    if (_manualValidationMessage() != null) {
      return null;
    }
    return EngineManualConfigurationSelection(
      candidateId: selectedCandidateId!,
      overrides: manualOverrides,
    );
  }

  EngineTargetSizeSelection? _targetSizeSelection() {
    if (_targetSizeValidationMessage() != null) {
      return null;
    }
    return EngineTargetSizeSelection(
      candidateId: selectedCandidateId!,
      targetBytes: targetBytes!,
      allowResolutionChange: allowResolutionChange,
      allowFrameRateChange: allowFrameRateChange,
    );
  }

  String? _presetValidationMessage() {
    final presetId = selectedPresetId;
    if (presetId == null) {
      return '请选择一个可用预设。';
    }
    final preset = _findAvailablePreset(presetId);
    final candidateId = preset?.candidate?.id;
    if (preset == null ||
        candidateId == null ||
        !candidateIds.contains(candidateId) ||
        selectedCandidateId != candidateId) {
      return '所选预设已不适用于当前分析结果。';
    }
    return _overrideValidationMessage(candidateId, manualOverrides);
  }

  String? _manualValidationMessage() {
    final candidateId = selectedCandidateId;
    if (candidateId == null || !candidateIds.contains(candidateId)) {
      return '请选择一个可执行候选方案。';
    }
    return _overrideValidationMessage(candidateId, manualOverrides);
  }

  String? _targetSizeValidationMessage() {
    final candidateId = selectedCandidateId;
    if (candidateId == null || !candidateIds.contains(candidateId)) {
      return '请选择一个可执行候选方案。';
    }
    if (!hasCompleteTargetSizeRange) {
      return customTargetSize.unavailableReason ?? '当前分析结果不支持目标体积模式。';
    }
    final value = targetBytes;
    if (value == null) {
      return '请输入目标体积。';
    }
    final minimumBytes = customTargetSize.minimumBytes!;
    final maximumBytes = customTargetSize.maximumBytes!;
    if (value <= 0 || value < minimumBytes || value > maximumBytes) {
      return '目标体积超出可用范围。';
    }
    return null;
  }

  String? _overrideValidationMessage(
    String candidateId,
    EngineManualOverrides overrides,
  ) {
    final fields = <(String, Object?)>[
      ('containers', overrides.container),
      ('video_codecs', overrides.videoCodec),
      ('audio_codecs', overrides.audioCodec),
      ('pixel_formats', overrides.outputPixelFormat),
      ('preserves_hdr', overrides.preservesHdr),
    ];
    for (final (field, value) in fields) {
      if (value != null && !_supportsValue(candidateId, field, value)) {
        return '所选参数不属于当前候选方案。';
      }
    }
    return null;
  }

  bool _supportsValue(String candidateId, String field, Object value) {
    final options = _snapshot.configurationOptions.optionsByField[field];
    if (options == null) {
      return false;
    }
    return options.any(
      (option) =>
          option.candidateIds.contains(candidateId) && option.value == value,
    );
  }

  EnginePresetOption? _findAvailablePreset(String presetId) {
    for (final preset in availablePresets) {
      if (preset.id == presetId) {
        return preset;
      }
    }
    return null;
  }
}

Map<String, Object?>? _decodeObject(String value) {
  try {
    return _asObject(jsonDecode(value));
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? _asObject(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      return null;
    }
    result[key] = entry.value;
  }
  return result;
}

EngineManualOverrides? _parseOverrides(Map<String, Object?> selectionJson) {
  final value = selectionJson['overrides'];
  if (value == null) {
    return const EngineManualOverrides();
  }
  final overrides = _asObject(value);
  if (overrides == null) {
    return null;
  }
  final container = _optionalString(overrides, 'container');
  final videoCodec = _optionalString(overrides, 'video_codec');
  final audioCodec = _optionalString(overrides, 'audio_codec');
  final outputPixelFormat = _optionalString(overrides, 'output_pixel_format');
  final preservesHdr = _optionalBool(overrides, 'preserves_hdr');
  if (!container.valid ||
      !videoCodec.valid ||
      !audioCodec.valid ||
      !outputPixelFormat.valid ||
      !preservesHdr.valid) {
    return null;
  }
  return EngineManualOverrides(
    container: container.value,
    videoCodec: videoCodec.value,
    audioCodec: audioCodec.value,
    outputPixelFormat: outputPixelFormat.value,
    preservesHdr: preservesHdr.value,
  );
}

({bool valid, String? value}) _optionalString(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  return (
    valid: value == null || value is String,
    value: value is String ? value : null,
  );
}

({bool valid, bool? value}) _optionalBool(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  return (
    valid: value == null || value is bool,
    value: value is bool ? value : null,
  );
}
