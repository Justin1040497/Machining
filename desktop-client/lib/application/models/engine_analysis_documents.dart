enum EngineTaskMode {
  videoCompress,
  videoConvert,
  audioCompress,
  audioConvert,
  imageCompress,
  imageConvert,
}

enum EngineMediaAnalysisStatus { complete, partial, failed }

enum EngineConfigurationStatus { available, unavailable, notEvaluated }

enum EngineSnapshotValidityStatus { valid, invalid }

final class EngineDocumentException implements Exception {
  const EngineDocumentException({required this.path, required this.message});

  final String path;
  final String message;

  @override
  String toString() => 'Malformed engine document at $path: $message';
}

final class EngineExecutionCandidateDocument {
  EngineExecutionCandidateDocument._({
    required this.id,
    required this.outputContainer,
    required this.raw,
  });

  factory EngineExecutionCandidateDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final id = _requireNonEmptyString(json, 'id', path);
    _requireNonEmptyString(json, 'demuxer', path);
    _requireList(json, 'video_decoders', path);
    _requireList(json, 'audio_decoders', path);
    _requireList(json, 'processors', path);
    _requireNonEmptyString(json, 'muxer', path);
    _requireNonEmptyString(json, 'output_container', path);
    _requireNonEmptyString(json, 'output_hdr_mode', path);
    _requireBool(json, 'preserves_hdr', path);
    _requireBool(json, 'requires_tone_mapping', path);
    _readNullableString(json, 'video_encoder', path);
    _readNullableString(json, 'audio_encoder', path);
    _readNullableString(json, 'output_video_codec', path);
    _readNullableString(json, 'output_video_profile', path);
    _readNullableString(json, 'output_audio_codec', path);
    _readNullableString(json, 'output_pixel_format', path);
    _readNullableInt(json, 'output_bit_depth', path);

    return EngineExecutionCandidateDocument._(
      id: id,
      outputContainer: _requireNonEmptyString(json, 'output_container', path),
      raw: _freezeMap(json, path),
    );
  }

  final String id;
  final String outputContainer;
  final Map<String, Object?> raw;
}

final class EngineResolvedConfigurationDocument {
  EngineResolvedConfigurationDocument._({
    required this.executionChainId,
    required this.raw,
  });

  factory EngineResolvedConfigurationDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    _requireNonEmptyString(json, 'selection_source', path);
    final executionChainId = _requireNonEmptyString(
      json,
      'execution_chain_id',
      path,
    );
    _requireNonEmptyString(json, 'container', path);
    _requireNonEmptyString(json, 'demuxer_backend', path);
    _requireList(json, 'video_decoders', path);
    _requireList(json, 'audio_decoders', path);
    _requireList(json, 'processors', path);
    _requireNonEmptyString(json, 'muxer_backend', path);
    _requireNonEmptyString(json, 'output_hdr_mode', path);
    _requireBool(json, 'preserves_hdr', path);
    _requireBool(json, 'requires_tone_mapping', path);

    return EngineResolvedConfigurationDocument._(
      executionChainId: executionChainId,
      raw: _freezeMap(json, path),
    );
  }

  final String executionChainId;
  final Map<String, Object?> raw;
}

final class EngineSizeEstimateDocument {
  EngineSizeEstimateDocument._({
    required this.expectedBytes,
    required this.minimumBytes,
    required this.maximumBytes,
    required this.confidence,
    required this.basis,
    required this.raw,
  });

  factory EngineSizeEstimateDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final expectedBytes = _requireNonNegativeInt(json, 'expected_bytes', path);
    final minimumBytes = _readNullableNonNegativeInt(
      json,
      'minimum_bytes',
      path,
    );
    final maximumBytes = _readNullableNonNegativeInt(
      json,
      'maximum_bytes',
      path,
    );
    final confidence = _requireNonEmptyString(json, 'confidence', path);
    final basis = _requireStringList(json, 'basis', path);

    if (minimumBytes != null && maximumBytes != null) {
      if (minimumBytes > maximumBytes) {
        _malformed('$path.minimum_bytes', 'must not exceed maximum_bytes');
      }
      if (expectedBytes < minimumBytes || expectedBytes > maximumBytes) {
        _malformed(
          '$path.expected_bytes',
          'must be inside the declared estimate range',
        );
      }
    }

    return EngineSizeEstimateDocument._(
      expectedBytes: expectedBytes,
      minimumBytes: minimumBytes,
      maximumBytes: maximumBytes,
      confidence: confidence,
      basis: List.unmodifiable(basis),
      raw: _freezeMap(json, path),
    );
  }

  final int expectedBytes;
  final int? minimumBytes;
  final int? maximumBytes;
  final String confidence;
  final List<String> basis;
  final Map<String, Object?> raw;
}

final class EngineCustomTargetSizeDocument {
  EngineCustomTargetSizeDocument._({
    required this.available,
    required this.unavailableReason,
    required this.minimumBytes,
    required this.maximumBytes,
    required this.defaultBytes,
    required this.stepBytes,
    required this.displayUnit,
    required this.raw,
  });

  factory EngineCustomTargetSizeDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final available = _requireBool(json, 'available', path);
    final unavailableReason = _readNullableString(
      json,
      'unavailable_reason',
      path,
    );
    final minimumBytes = _readNullableNonNegativeInt(
      json,
      'minimum_bytes',
      path,
    );
    final maximumBytes = _readNullableNonNegativeInt(
      json,
      'maximum_bytes',
      path,
    );
    final defaultBytes = _readNullableNonNegativeInt(
      json,
      'default_bytes',
      path,
    );
    final stepBytes = _readNullableNonNegativeInt(json, 'step_bytes', path);
    final displayUnit = _requireNonEmptyString(json, 'display_unit', path);

    if (available &&
        (minimumBytes == null ||
            maximumBytes == null ||
            defaultBytes == null ||
            stepBytes == null)) {
      _malformed(
        path,
        'available target size options must include minimum, maximum, default, and step bytes',
      );
    }
    if (minimumBytes != null &&
        maximumBytes != null &&
        minimumBytes > maximumBytes) {
      _malformed('$path.minimum_bytes', 'must not exceed maximum_bytes');
    }
    if (defaultBytes != null &&
        ((minimumBytes != null && defaultBytes < minimumBytes) ||
            (maximumBytes != null && defaultBytes > maximumBytes))) {
      _malformed(
        '$path.default_bytes',
        'must be inside the declared target size range',
      );
    }
    if (stepBytes != null && stepBytes == 0) {
      _malformed('$path.step_bytes', 'must be greater than zero');
    }

    return EngineCustomTargetSizeDocument._(
      available: available,
      unavailableReason: unavailableReason,
      minimumBytes: minimumBytes,
      maximumBytes: maximumBytes,
      defaultBytes: defaultBytes,
      stepBytes: stepBytes,
      displayUnit: displayUnit,
      raw: _freezeMap(json, path),
    );
  }

  final bool available;
  final String? unavailableReason;
  final int? minimumBytes;
  final int? maximumBytes;
  final int? defaultBytes;
  final int? stepBytes;
  final String displayUnit;
  final Map<String, Object?> raw;
}

final class EnginePresetOption {
  EnginePresetOption._({
    required this.id,
    required this.displayName,
    required this.description,
    required this.applicable,
    required this.unavailableReason,
    required this.candidate,
    required this.configuration,
    required this.estimate,
    required this.risks,
    required this.raw,
  });

  factory EnginePresetOption.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final id = _requireNonEmptyString(json, 'id', path);
    final displayName = _requireNonEmptyString(json, 'display_name', path);
    final description = _requireString(json, 'description', path);
    final applicable = _requireBool(json, 'applicable', path);
    final unavailableReason = _readNullableString(
      json,
      'unavailable_reason',
      path,
    );
    _requireNonNegativeInt(json, 'policy_version', path);
    _requireObject(json, 'policy', path);

    final candidateJson = _readNullableObject(json, 'candidate', path);
    final configurationJson = _readNullableObject(json, 'configuration', path);
    final estimateJson = _readNullableObject(json, 'estimate', path);
    final risks = _requireStringList(json, 'risks', path);

    final candidate = candidateJson == null
        ? null
        : EngineExecutionCandidateDocument.fromJson(
            candidateJson,
            path: '$path.candidate',
          );
    final configuration = configurationJson == null
        ? null
        : EngineResolvedConfigurationDocument.fromJson(
            configurationJson,
            path: '$path.configuration',
          );
    final estimate = estimateJson == null
        ? null
        : EngineSizeEstimateDocument.fromJson(
            estimateJson,
            path: '$path.estimate',
          );

    if (applicable &&
        (candidate == null || configuration == null || estimate == null)) {
      _malformed(
        path,
        'an applicable preset must include candidate, configuration, and estimate',
      );
    }
    if (candidate != null &&
        configuration != null &&
        candidate.id != configuration.executionChainId) {
      _malformed(
        '$path.configuration.execution_chain_id',
        'must match the preset candidate id',
      );
    }

    return EnginePresetOption._(
      id: id,
      displayName: displayName,
      description: description,
      applicable: applicable,
      unavailableReason: unavailableReason,
      candidate: candidate,
      configuration: configuration,
      estimate: estimate,
      risks: List.unmodifiable(risks),
      raw: _freezeMap(json, path),
    );
  }

  final String id;
  final String displayName;
  final String description;
  final bool applicable;
  final String? unavailableReason;
  final EngineExecutionCandidateDocument? candidate;
  final EngineResolvedConfigurationDocument? configuration;
  final EngineSizeEstimateDocument? estimate;
  final List<String> risks;
  final Map<String, Object?> raw;
}

final class EngineConfigurationOption {
  EngineConfigurationOption._({
    required this.value,
    required this.candidateIds,
  });

  factory EngineConfigurationOption.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    final value = json['value'];
    if (!json.containsKey('value') || value == null) {
      _malformed('$path.value', 'is required');
    }
    return EngineConfigurationOption._(
      value: _freezeJson(value, '$path.value')!,
      candidateIds: List.unmodifiable(
        _requireStringList(json, 'candidate_ids', path),
      ),
    );
  }

  final Object value;
  final List<String> candidateIds;
}

final class EngineConfigurationOptionGraphDocument {
  EngineConfigurationOptionGraphDocument._({
    required this.candidateIds,
    required this.optionsByField,
    required this.raw,
  });

  factory EngineConfigurationOptionGraphDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final candidateIds = _requireStringList(json, 'candidate_ids', path);
    final optionsByField = <String, List<EngineConfigurationOption>>{};
    for (final field in _optionFields) {
      final values = _requireList(json, field, path);
      optionsByField[field] = List.unmodifiable(
        values.indexed.map((entry) {
          final (index, value) = entry;
          return EngineConfigurationOption.fromJson(
            _expectObject(value, '$path.$field[$index]'),
            path: '$path.$field[$index]',
          );
        }),
      );
    }
    return EngineConfigurationOptionGraphDocument._(
      candidateIds: List.unmodifiable(candidateIds),
      optionsByField: Map.unmodifiable(optionsByField),
      raw: _freezeMap(json, path),
    );
  }

  static const _optionFields = <String>[
    'containers',
    'video_codecs',
    'video_profiles',
    'audio_codecs',
    'video_encoders',
    'audio_encoders',
    'pixel_formats',
    'bit_depths',
    'hdr_modes',
    'preserves_hdr',
    'requires_tone_mapping',
  ];

  final List<String> candidateIds;
  final Map<String, List<EngineConfigurationOption>> optionsByField;
  final Map<String, Object?> raw;
}

final class EngineRecommendationDocument {
  EngineRecommendationDocument._({
    required this.status,
    required this.configuration,
    required this.estimate,
    required this.reasons,
    required this.raw,
  });

  factory EngineRecommendationDocument.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final status = _requireNonEmptyString(json, 'status', path);
    if (!const {'complete', 'partial', 'unavailable'}.contains(status)) {
      _malformed('$path.status', 'has unsupported value "$status"');
    }
    final configurationJson = _readNullableObject(json, 'configuration', path);
    final estimateJson = _readNullableObject(json, 'estimate', path);
    final configuration = configurationJson == null
        ? null
        : EngineResolvedConfigurationDocument.fromJson(
            configurationJson,
            path: '$path.configuration',
          );
    final estimate = estimateJson == null
        ? null
        : EngineSizeEstimateDocument.fromJson(
            estimateJson,
            path: '$path.estimate',
          );
    if (status == 'complete' && (configuration == null || estimate == null)) {
      _malformed(
        path,
        'a complete recommendation must include configuration and estimate',
      );
    }
    return EngineRecommendationDocument._(
      status: status,
      configuration: configuration,
      estimate: estimate,
      reasons: List.unmodifiable(_requireStringList(json, 'reasons', path)),
      raw: _freezeMap(json, path),
    );
  }

  final String status;
  final EngineResolvedConfigurationDocument? configuration;
  final EngineSizeEstimateDocument? estimate;
  final List<String> reasons;
  final Map<String, Object?> raw;
}

final class EngineSnapshotValidity {
  EngineSnapshotValidity._({
    required this.status,
    required this.reasonCode,
    required this.message,
  });

  factory EngineSnapshotValidity.fromJson(
    Map<String, Object?> json, {
    String path = r'$',
  }) {
    final statusValue = _requireNonEmptyString(json, 'status', path);
    final status = switch (statusValue) {
      'valid' => EngineSnapshotValidityStatus.valid,
      'invalid' => EngineSnapshotValidityStatus.invalid,
      _ => _malformed('$path.status', 'has unsupported value "$statusValue"'),
    };
    return EngineSnapshotValidity._(
      status: status,
      reasonCode: _readNullableString(json, 'reason_code', path),
      message: _readNullableString(json, 'message', path),
    );
  }

  final EngineSnapshotValidityStatus status;
  final String? reasonCode;
  final String? message;

  bool get isValid => status == EngineSnapshotValidityStatus.valid;
}

final class EngineAnalysisSnapshotDocument {
  EngineAnalysisSnapshotDocument._({
    required this.schemaVersion,
    required this.analysisId,
    required this.analysisRevision,
    required this.decisionModelRevision,
    required this.estimatorModelRevision,
    required this.taskMode,
    required this.executionCandidates,
    required this.presets,
    required this.configurationOptions,
    required this.recommendation,
    required this.customTargetSize,
    required this.validity,
    required this.raw,
  });

  factory EngineAnalysisSnapshotDocument.fromJson(Map<String, Object?> json) {
    const path = r'$';
    final schemaVersion = _requireNonEmptyString(json, 'schema_version', path);
    final analysisId = _requireNonEmptyString(json, 'analysis_id', path);
    final analysisRevision = _requireNonNegativeInt(
      json,
      'analysis_revision',
      path,
    );
    final decisionModelRevision = _requireNonNegativeInt(
      json,
      'decision_model_revision',
      path,
    );
    final estimatorModelRevision = _requireNonNegativeInt(
      json,
      'estimator_model_revision',
      path,
    );
    final taskMode = _parseTaskMode(
      _requireNonEmptyString(json, 'task_mode', path),
      '$path.task_mode',
    );
    _requireObject(json, 'media', path);
    _requireObject(json, 'source_fingerprint', path);
    _requireObject(json, 'requirements', path);
    _requireObject(json, 'environment_summary', path);
    _requireObject(json, 'engine_backend_summary', path);

    final capabilities = _requireObject(json, 'capabilities', path);
    _requireBool(capabilities, 'available', '$path.capabilities');
    final candidateValues = _requireList(
      capabilities,
      'execution_chains',
      '$path.capabilities',
    );
    final candidates = <String, EngineExecutionCandidateDocument>{};
    for (final (index, value) in candidateValues.indexed) {
      final candidate = EngineExecutionCandidateDocument.fromJson(
        _expectObject(value, '$path.capabilities.execution_chains[$index]'),
        path: '$path.capabilities.execution_chains[$index]',
      );
      if (candidates.containsKey(candidate.id)) {
        _malformed(
          '$path.capabilities.execution_chains[$index].id',
          'duplicates candidate id "${candidate.id}"',
        );
      }
      candidates[candidate.id] = candidate;
    }

    final configurationOptions =
        EngineConfigurationOptionGraphDocument.fromJson(
          _requireObject(json, 'configuration_options', path),
          path: '$path.configuration_options',
        );
    _validateOptionGraph(configurationOptions, candidates);

    final recommendation = EngineRecommendationDocument.fromJson(
      _requireObject(json, 'recommendation', path),
      path: '$path.recommendation',
    );
    _validateRecommendation(recommendation, candidates);

    final presetValues = _requireList(json, 'presets', path);
    final presets = <EnginePresetOption>[];
    final presetIds = <String>{};
    for (final (index, value) in presetValues.indexed) {
      final preset = EnginePresetOption.fromJson(
        _expectObject(value, '$path.presets[$index]'),
        path: '$path.presets[$index]',
      );
      if (!presetIds.add(preset.id)) {
        _malformed(
          '$path.presets[$index].id',
          'duplicates preset id "${preset.id}"',
        );
      }
      _validatePreset(preset, candidates, '$path.presets[$index]');
      presets.add(preset);
    }

    final customTargetSize = EngineCustomTargetSizeDocument.fromJson(
      _requireObject(json, 'custom_target_size', path),
      path: '$path.custom_target_size',
    );
    _requireList(json, 'warnings', path);
    final validity = EngineSnapshotValidity.fromJson(
      _requireObject(json, 'validity', path),
      path: '$path.validity',
    );

    return EngineAnalysisSnapshotDocument._(
      schemaVersion: schemaVersion,
      analysisId: analysisId,
      analysisRevision: analysisRevision,
      decisionModelRevision: decisionModelRevision,
      estimatorModelRevision: estimatorModelRevision,
      taskMode: taskMode,
      executionCandidates: Map.unmodifiable(candidates),
      presets: List.unmodifiable(presets),
      configurationOptions: configurationOptions,
      recommendation: recommendation,
      customTargetSize: customTargetSize,
      validity: validity,
      raw: _freezeMap(json, path),
    );
  }

  final String schemaVersion;
  final String analysisId;
  final int analysisRevision;
  final int decisionModelRevision;
  final int estimatorModelRevision;
  final EngineTaskMode taskMode;
  final Map<String, EngineExecutionCandidateDocument> executionCandidates;
  final List<EnginePresetOption> presets;
  final EngineConfigurationOptionGraphDocument configurationOptions;
  final EngineRecommendationDocument recommendation;
  final EngineCustomTargetSizeDocument customTargetSize;
  final EngineSnapshotValidity validity;
  final Map<String, Object?> raw;

  List<EnginePresetOption> get availablePresets =>
      List.unmodifiable(presets.where((preset) => preset.applicable));
}

final class EngineAnalysisResponseDocument {
  EngineAnalysisResponseDocument._({
    required this.schemaVersion,
    required this.analysisId,
    required this.analysisRevision,
    required this.taskMode,
    required this.mediaAnalysisStatus,
    required this.configurationStatus,
    required this.errorCode,
    required this.errorMessage,
    required this.errorRetryable,
    required this.raw,
  });

  factory EngineAnalysisResponseDocument.fromJson(Map<String, Object?> json) {
    const path = r'$';
    final statusValue = _requireNonEmptyString(
      json,
      'media_analysis_status',
      path,
    );
    final mediaAnalysisStatus = switch (statusValue) {
      'complete' => EngineMediaAnalysisStatus.complete,
      'partial' => EngineMediaAnalysisStatus.partial,
      'failed' => EngineMediaAnalysisStatus.failed,
      _ => _malformed(
        '$path.media_analysis_status',
        'has unsupported value "$statusValue"',
      ),
    };
    final configurationStatus = _parseConfigurationStatus(
      _requireNonEmptyString(json, 'configuration_status', path),
      '$path.configuration_status',
    );
    final error = _readNullableObject(json, 'error', path);

    if (mediaAnalysisStatus != EngineMediaAnalysisStatus.failed) {
      for (final field in const [
        'media',
        'source_fingerprint',
        'requirements',
        'environment_summary',
        'engine_backend_summary',
        'capabilities',
        'configuration_options',
        'recommendation',
      ]) {
        _requireObject(json, field, path);
      }
    }
    _requireList(json, 'presets', path);
    _requireList(json, 'warnings', path);

    return EngineAnalysisResponseDocument._(
      schemaVersion: _requireNonEmptyString(json, 'schema_version', path),
      analysisId: _requireNonEmptyString(json, 'analysis_id', path),
      analysisRevision: _requireNonNegativeInt(json, 'analysis_revision', path),
      taskMode: _parseTaskMode(
        _requireNonEmptyString(json, 'task_mode', path),
        '$path.task_mode',
      ),
      mediaAnalysisStatus: mediaAnalysisStatus,
      configurationStatus: configurationStatus,
      errorCode: error == null
          ? null
          : _readNullableString(error, 'code', '$path.error'),
      errorMessage: error == null
          ? null
          : _readNullableString(error, 'message', '$path.error'),
      errorRetryable: error == null
          ? null
          : _readNullableBool(error, 'retryable', '$path.error'),
      raw: _freezeMap(json, path),
    );
  }

  final String schemaVersion;
  final String analysisId;
  final int analysisRevision;
  final EngineTaskMode taskMode;
  final EngineMediaAnalysisStatus mediaAnalysisStatus;
  final EngineConfigurationStatus configurationStatus;
  final String? errorCode;
  final String? errorMessage;
  final bool? errorRetryable;
  final Map<String, Object?> raw;

  bool get hasSnapshot =>
      mediaAnalysisStatus != EngineMediaAnalysisStatus.failed;
}

final class EngineConfigurationResolutionDocument {
  EngineConfigurationResolutionDocument._({
    required this.schemaVersion,
    required this.analysisId,
    required this.analysisRevision,
    required this.configurationStatus,
    required this.resolvedConfiguration,
    required this.raw,
  });

  factory EngineConfigurationResolutionDocument.fromJson(
    Map<String, Object?> json,
  ) {
    const path = r'$';
    final resolvedJson = _readNullableObject(
      json,
      'resolved_configuration',
      path,
    );
    return EngineConfigurationResolutionDocument._(
      schemaVersion: _requireNonEmptyString(json, 'schema_version', path),
      analysisId: _requireNonEmptyString(json, 'analysis_id', path),
      analysisRevision: _requireNonNegativeInt(json, 'analysis_revision', path),
      configurationStatus: _parseConfigurationStatus(
        _requireNonEmptyString(json, 'configuration_status', path),
        '$path.configuration_status',
      ),
      resolvedConfiguration: resolvedJson == null
          ? null
          : EngineResolvedConfigurationDocument.fromJson(
              resolvedJson,
              path: '$path.resolved_configuration',
            ),
      raw: _freezeMap(json, path),
    );
  }

  final String schemaVersion;
  final String analysisId;
  final int analysisRevision;
  final EngineConfigurationStatus configurationStatus;
  final EngineResolvedConfigurationDocument? resolvedConfiguration;
  final Map<String, Object?> raw;
}

void _validatePreset(
  EnginePresetOption preset,
  Map<String, EngineExecutionCandidateDocument> candidates,
  String path,
) {
  final candidate = preset.candidate;
  if (candidate == null) {
    return;
  }
  final authoritative = candidates[candidate.id];
  if (authoritative == null) {
    _malformed(
      '$path.candidate.id',
      'does not reference an advertised execution candidate',
    );
  }
  if (!_deepJsonEquals(candidate.raw, authoritative.raw)) {
    _malformed(
      '$path.candidate',
      'does not match the authoritative execution candidate',
    );
  }
}

void _validateRecommendation(
  EngineRecommendationDocument recommendation,
  Map<String, EngineExecutionCandidateDocument> candidates,
) {
  final configuration = recommendation.configuration;
  if (configuration != null &&
      !candidates.containsKey(configuration.executionChainId)) {
    _malformed(
      r'$.recommendation.configuration.execution_chain_id',
      'does not reference an advertised execution candidate',
    );
  }
}

void _validateOptionGraph(
  EngineConfigurationOptionGraphDocument graph,
  Map<String, EngineExecutionCandidateDocument> candidates,
) {
  if (!_sameStringSet(graph.candidateIds, candidates.keys)) {
    _malformed(
      r'$.configuration_options.candidate_ids',
      'must match the advertised execution candidate ids',
    );
  }
  for (final entry in graph.optionsByField.entries) {
    for (final (index, option) in entry.value.indexed) {
      for (final candidateId in option.candidateIds) {
        if (!candidates.containsKey(candidateId)) {
          _malformed(
            r'$.configuration_options.'
                '${entry.key}[$index].candidate_ids',
            'contains unknown candidate id "$candidateId"',
          );
        }
      }
    }
  }
}

EngineTaskMode _parseTaskMode(String value, String path) {
  return switch (value) {
    'video_compress' => EngineTaskMode.videoCompress,
    'video_convert' => EngineTaskMode.videoConvert,
    'audio_compress' => EngineTaskMode.audioCompress,
    'audio_convert' => EngineTaskMode.audioConvert,
    'image_compress' => EngineTaskMode.imageCompress,
    'image_convert' => EngineTaskMode.imageConvert,
    _ => _malformed(path, 'has unsupported value "$value"'),
  };
}

EngineConfigurationStatus _parseConfigurationStatus(String value, String path) {
  return switch (value) {
    'available' => EngineConfigurationStatus.available,
    'unavailable' => EngineConfigurationStatus.unavailable,
    'not_evaluated' => EngineConfigurationStatus.notEvaluated,
    _ => _malformed(path, 'has unsupported value "$value"'),
  };
}

bool _sameStringSet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == left.length &&
      rightSet.length == right.length &&
      leftSet.length == rightSet.length &&
      leftSet.containsAll(rightSet);
}

bool _deepJsonEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepJsonEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

Map<String, Object?> _freezeMap(Map<String, Object?> value, String path) {
  return Map.unmodifiable(
    value.map((key, child) => MapEntry(key, _freezeJson(child, '$path.$key'))),
  );
}

Object? _freezeJson(Object? value, String path) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.indexed.map((entry) => _freezeJson(entry.$2, '$path[${entry.$1}]')),
    );
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        _malformed(path, 'contains a non-string object key');
      }
      result[key] = _freezeJson(entry.value, '$path.$key');
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  _malformed(path, 'contains a non-JSON value');
}

Map<String, Object?> _requireObject(
  Map<String, Object?> json,
  String key,
  String path,
) {
  return _expectObject(json[key], '$path.$key');
}

Map<String, Object?>? _readNullableObject(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = json[key];
  return value == null ? null : _expectObject(value, '$path.$key');
}

Map<String, Object?> _expectObject(Object? value, String path) {
  if (value is! Map) {
    _malformed(path, 'must be an object');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      _malformed(path, 'contains a non-string object key');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _requireList(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! List) {
    _malformed('$path.$key', 'must be an array');
  }
  return List<Object?>.from(value);
}

List<String> _requireStringList(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final values = _requireList(json, key, path);
  return values.indexed
      .map((entry) {
        final (index, value) = entry;
        if (value is! String || value.trim().isEmpty) {
          _malformed('$path.$key[$index]', 'must be a non-empty string');
        }
        return value;
      })
      .toList(growable: false);
}

String _requireString(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! String) {
    _malformed('$path.$key', 'must be a string');
  }
  return value;
}

String _requireNonEmptyString(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = _requireString(json, key, path);
  if (value.trim().isEmpty) {
    _malformed('$path.$key', 'must not be empty');
  }
  return value;
}

String? _readNullableString(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    _malformed('$path.$key', 'must be a string or null');
  }
  return value;
}

bool _requireBool(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! bool) {
    _malformed('$path.$key', 'must be a boolean');
  }
  return value;
}

bool? _readNullableBool(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    _malformed('$path.$key', 'must be a boolean or null');
  }
  return value;
}

int _requireNonNegativeInt(Map<String, Object?> json, String key, String path) {
  final value = _readInt(json, key, path);
  if (value < 0) {
    _malformed('$path.$key', 'must not be negative');
  }
  return value;
}

int? _readNullableNonNegativeInt(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = _readNullableInt(json, key, path);
  if (value != null && value < 0) {
    _malformed('$path.$key', 'must not be negative');
  }
  return value;
}

int _readInt(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! int) {
    _malformed('$path.$key', 'must be an integer');
  }
  return value;
}

int? _readNullableInt(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    _malformed('$path.$key', 'must be an integer or null');
  }
  return value;
}

Never _malformed(String path, String message) {
  throw EngineDocumentException(path: path, message: message);
}
