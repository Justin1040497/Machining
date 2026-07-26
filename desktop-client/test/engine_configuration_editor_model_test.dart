import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/engine_configuration_editor_model.dart';

void main() {
  group('EngineConfigurationEditorModel presets', () {
    test('restores and creates the exact advertised preset selection', () {
      final snapshot = _snapshot(recommendationCandidateId: 'candidate-a');
      final reference = _reference(
        candidateId: 'candidate-b',
        mode: 'preset',
        selection: <String, Object?>{
          'preset_id': 'preset-b',
          'candidate_id': 'candidate-b',
          'overrides': <String, Object?>{'container': 'mov'},
        },
      );

      final restored = EngineConfigurationEditorModel(
        snapshot: snapshot,
        reference: reference,
      );

      expect(restored.mode, EngineConfigurationEditorMode.preset);
      expect(restored.selectedCandidateId, 'candidate-b');
      expect(restored.canResolve, isTrue);
      final restoredSelection = restored.selection! as EnginePresetSelection;
      expect(restoredSelection.presetId, 'preset-b');
      expect(restoredSelection.candidateId, 'candidate-b');
      expect(restoredSelection.overrides.container, 'mov');

      final selected = EngineConfigurationEditorModel(
        snapshot: snapshot,
      ).selectPreset('preset-a');
      final selectedSelection = selected.selection! as EnginePresetSelection;
      expect(selectedSelection.presetId, 'preset-a');
      expect(selectedSelection.candidateId, 'candidate-a');
    });
  });

  group('EngineConfigurationEditorModel manual selection', () {
    test('filters graph options and builds only the explicit candidate', () {
      final model = EngineConfigurationEditorModel(snapshot: _snapshot());

      expect(model.selectedCandidateId, isNull);

      final selected = model.selectManual(
        candidateId: 'candidate-b',
        overrides: const EngineManualOverrides(
          container: 'mov',
          videoCodec: 'hevc',
          audioCodec: 'aac',
          outputPixelFormat: 'p010le',
          preservesHdr: true,
        ),
      );

      expect(
        selected.optionsForField('containers').map((option) => option.value),
        ['mov'],
      );
      expect(
        selected.optionsForField('video_codecs').map((option) => option.value),
        ['hevc'],
      );
      expect(selected.canResolve, isTrue);
      final selection =
          selected.selection! as EngineManualConfigurationSelection;
      expect(selection.candidateId, 'candidate-b');
      expect(selection.overrides.container, 'mov');
      expect(selection.overrides.videoCodec, 'hevc');
      expect(selection.overrides.audioCodec, 'aac');
      expect(selection.overrides.outputPixelFormat, 'p010le');
      expect(selection.overrides.preservesHdr, isTrue);
    });

    test('does not accept an option advertised for another candidate', () {
      final selected = EngineConfigurationEditorModel(snapshot: _snapshot())
          .selectManual(
            candidateId: 'candidate-b',
            overrides: const EngineManualOverrides(container: 'mp4'),
          );

      expect(selected.canResolve, isFalse);
      expect(selected.selection, isNull);
      expect(selected.validationMessage, isNotNull);
    });

    test('restores the legacy flat manual selection payload', () {
      final reference = EngineConfigurationReference(
        analysisId: 'analysis-1',
        analysisRevision: 4,
        candidateId: 'candidate-b',
        selectionMode: 'manual',
        selectionJson: jsonEncode(<String, Object?>{
          'candidate_id': 'candidate-b',
          'overrides': <String, Object?>{
            'container': 'mov',
            'video_codec': 'hevc',
          },
        }),
      );

      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(),
        reference: reference,
      );

      expect(model.mode, EngineConfigurationEditorMode.manual);
      expect(model.canResolve, isTrue);
      final selection = model.selection! as EngineManualConfigurationSelection;
      expect(selection.candidateId, 'candidate-b');
      expect(selection.overrides.videoCodec, 'hevc');
    });
  });

  group('EngineConfigurationEditorModel target size', () {
    test('builds target selection only inside the advertised range', () {
      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(recommendationCandidateId: 'candidate-a'),
      );

      expect(model.selectedCandidateId, 'candidate-a');
      expect(model.hasCompleteTargetSizeRange, isTrue);

      final selected = model.selectTargetSize(
        targetBytes: 200,
        allowResolutionChange: true,
        allowFrameRateChange: false,
      );
      expect(selected.canResolve, isTrue);
      final selection = selected.selection! as EngineTargetSizeSelection;
      expect(selection.candidateId, 'candidate-a');
      expect(selection.targetBytes, 200);
      expect(selection.allowResolutionChange, isTrue);
      expect(selection.allowFrameRateChange, isFalse);

      final outOfRange = model.selectTargetSize(
        targetBytes: 99,
        allowResolutionChange: false,
        allowFrameRateChange: false,
      );
      expect(outOfRange.canResolve, isFalse);
      expect(outOfRange.validationMessage, isNotNull);
    });

    test('does not build a selection when target size is unavailable', () {
      final model =
          EngineConfigurationEditorModel(
            snapshot: _snapshot(
              recommendationCandidateId: 'candidate-a',
              targetSizeAvailable: false,
            ),
          ).selectTargetSize(
            targetBytes: 200,
            allowResolutionChange: false,
            allowFrameRateChange: false,
          );

      expect(model.hasCompleteTargetSizeRange, isFalse);
      expect(model.canResolve, isFalse);
      expect(model.validationMessage, 'TARGET_SIZE_UNAVAILABLE');
    });
  });

  group('EngineConfigurationEditorModel candidate defaults', () {
    test(
      'ignores damaged reference state without losing its valid candidate',
      () {
        final reference = EngineConfigurationReference(
          analysisId: 'analysis-1',
          analysisRevision: 4,
          candidateId: 'candidate-b',
          selectionMode: 'manual',
          selectionJson: '{',
        );

        final model = EngineConfigurationEditorModel(
          snapshot: _snapshot(recommendationCandidateId: 'candidate-a'),
          reference: reference,
        );

        expect(model.selectedCandidateId, 'candidate-b');
        expect(model.mode, isNull);
        expect(model.selection, isNull);
        expect(model.canResolve, isFalse);
      },
    );

    test('treats an explicitly null saved selection as damaged', () {
      final reference = EngineConfigurationReference(
        analysisId: 'analysis-1',
        analysisRevision: 4,
        candidateId: 'candidate-b',
        selectionMode: 'manual',
        selectionJson: '{"mode":"manual","selection":null}',
      );

      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(recommendationCandidateId: 'candidate-a'),
        reference: reference,
      );

      expect(model.selectedCandidateId, 'candidate-b');
      expect(model.mode, isNull);
      expect(model.canResolve, isFalse);
    });

    test('keeps multiple candidates ambiguous without an authority', () {
      final ambiguous = EngineConfigurationEditorModel(snapshot: _snapshot());
      final unique = EngineConfigurationEditorModel(
        snapshot: _snapshot(candidateIds: const ['candidate-a']),
      );

      expect(ambiguous.selectedCandidateId, isNull);
      expect(ambiguous.canResolve, isFalse);
      expect(ambiguous.validationMessage, '请选择一个候选方案。');
      expect(unique.selectedCandidateId, 'candidate-a');
      expect(unique.canResolve, isFalse);
      expect(unique.validationMessage, '请选择配置方式。');
    });

    test('reports no executable candidate without fabricating options', () {
      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(candidateIds: const []),
      );

      expect(model.availablePresets, isEmpty);
      expect(model.candidateIds, isEmpty);
      expect(model.manualOptions, isEmpty);
      expect(model.selection, isNull);
      expect(model.canResolve, isFalse);
      expect(model.validationMessage, '当前分析结果没有可执行候选方案。');
    });
  });
}

EngineConfigurationReference _reference({
  required String candidateId,
  required String mode,
  required Map<String, Object?> selection,
}) {
  return EngineConfigurationReference(
    analysisId: 'analysis-1',
    analysisRevision: 4,
    candidateId: candidateId,
    selectionMode: mode,
    selectionJson: jsonEncode(<String, Object?>{
      'mode': mode,
      'selection': selection,
    }),
  );
}

EngineAnalysisSnapshotDocument _snapshot({
  List<String> candidateIds = const ['candidate-a', 'candidate-b'],
  String? recommendationCandidateId,
  bool targetSizeAvailable = true,
}) {
  final candidates = <String, Map<String, Object?>>{
    for (final candidateId in candidateIds)
      candidateId: _candidate(candidateId),
  };
  final recommendation = recommendationCandidateId == null
      ? <String, Object?>{
          'status': 'unavailable',
          'configuration': null,
          'estimate': null,
          'reasons': <Object?>['no recommendation'],
        }
      : <String, Object?>{
          'status': 'complete',
          'configuration': _configuration(recommendationCandidateId),
          'estimate': _estimate(),
          'reasons': <Object?>['recommended'],
        };
  return EngineAnalysisSnapshotDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 4,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': 'video_compress',
    'media': <String, Object?>{},
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{
      'available': candidateIds.isNotEmpty,
      'execution_chains': candidates.values.toList(),
    },
    'configuration_options': _configurationOptions(candidateIds),
    'recommendation': recommendation,
    'presets': <Object?>[
      if (candidates.containsKey('candidate-a'))
        _preset(id: 'preset-a', candidate: candidates['candidate-a']!),
      if (candidates.containsKey('candidate-b'))
        _preset(id: 'preset-b', candidate: candidates['candidate-b']!),
    ],
    'custom_target_size': targetSizeAvailable
        ? <String, Object?>{
            'available': true,
            'unavailable_reason': null,
            'minimum_bytes': 100,
            'maximum_bytes': 300,
            'default_bytes': 200,
            'step_bytes': 10,
            'display_unit': 'bytes',
          }
        : <String, Object?>{
            'available': false,
            'unavailable_reason': 'TARGET_SIZE_UNAVAILABLE',
            'minimum_bytes': null,
            'maximum_bytes': null,
            'default_bytes': null,
            'step_bytes': null,
            'display_unit': 'bytes',
          },
    'warnings': <Object?>[],
    'validity': <String, Object?>{
      'status': 'valid',
      'reason_code': null,
      'message': null,
    },
  });
}

Map<String, Object?> _candidate(String id) {
  final second = id == 'candidate-b';
  return <String, Object?>{
    'id': id,
    'demuxer': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'video_encoder': second ? 'hevc-encoder' : 'h264-encoder',
    'audio_encoder': 'aac-encoder',
    'muxer': second ? 'mov-muxer' : 'mp4-muxer',
    'output_container': second ? 'mov' : 'mp4',
    'output_video_codec': second ? 'hevc' : 'h264',
    'output_video_profile': null,
    'output_audio_codec': 'aac',
    'output_pixel_format': second ? 'p010le' : 'yuv420p',
    'output_bit_depth': second ? 10 : 8,
    'output_hdr_mode': second ? 'preserve' : 'sdr',
    'preserves_hdr': second,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _configuration(String candidateId) {
  final second = candidateId == 'candidate-b';
  return <String, Object?>{
    'selection_source': 'recommendation',
    'execution_chain_id': candidateId,
    'container': second ? 'mov' : 'mp4',
    'demuxer_backend': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'muxer_backend': second ? 'mov-muxer' : 'mp4-muxer',
    'output_hdr_mode': second ? 'preserve' : 'sdr',
    'preserves_hdr': second,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _estimate() {
  return <String, Object?>{
    'expected_bytes': 200,
    'minimum_bytes': 150,
    'maximum_bytes': 250,
    'confidence': 'medium',
    'basis': <Object?>['test'],
  };
}

Map<String, Object?> _preset({
  required String id,
  required Map<String, Object?> candidate,
}) {
  return <String, Object?>{
    'id': id,
    'display_name': id,
    'description': id,
    'applicable': true,
    'unavailable_reason': null,
    'policy_version': 1,
    'policy': <String, Object?>{},
    'candidate': Map<String, Object?>.from(candidate),
    'configuration': _configuration(candidate['id']! as String),
    'estimate': _estimate(),
    'risks': <Object?>[],
  };
}

Map<String, Object?> _configurationOptions(List<String> candidateIds) {
  List<Object?> option(Object value, List<String> supportedCandidates) {
    final candidates = supportedCandidates
        .where(candidateIds.contains)
        .toList(growable: false);
    return candidates.isEmpty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{'value': value, 'candidate_ids': candidates},
          ];
  }

  return <String, Object?>{
    'candidate_ids': candidateIds,
    'containers': <Object?>[
      ...option('mp4', const ['candidate-a']),
      ...option('mov', const ['candidate-b']),
    ],
    'video_codecs': <Object?>[
      ...option('h264', const ['candidate-a']),
      ...option('hevc', const ['candidate-b']),
    ],
    'video_profiles': <Object?>[],
    'audio_codecs': option('aac', const ['candidate-a', 'candidate-b']),
    'video_encoders': <Object?>[],
    'audio_encoders': <Object?>[],
    'pixel_formats': <Object?>[
      ...option('yuv420p', const ['candidate-a']),
      ...option('p010le', const ['candidate-b']),
    ],
    'bit_depths': <Object?>[],
    'hdr_modes': <Object?>[],
    'preserves_hdr': <Object?>[
      ...option(false, const ['candidate-a']),
      ...option(true, const ['candidate-b']),
    ],
    'requires_tone_mapping': <Object?>[],
  };
}
