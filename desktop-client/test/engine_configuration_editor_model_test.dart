import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/services/engine/engine_configuration_editor_model.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/engine/engine_task_folder_selection_planner.dart';
import 'package:framelean/application/use_cases/media_tasks/save_engine_task_configuration_use_case.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';

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
          audioStreams: [
            EngineAudioStreamOverride(
              streamIndex: 1,
              bitrateBps: 192000,
              sampleRateHz: 32000,
              channelCount: 2,
            ),
          ],
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
      expect(selection.overrides.audioStreams, hasLength(1));
      expect(selection.overrides.audioStreams!.single.bitrateBps, 192000);
      expect(selection.overrides.audioStreams!.single.sampleRateHz, 32000);
      expect(selection.overrides.audioStreams!.single.channelCount, 2);
      expect(selection.overrides.outputPixelFormat, 'p010le');
      expect(selection.overrides.preservesHdr, isTrue);
      final encoded = engineConfigurationSelectionToJson(selection);
      final encodedSelection = encoded['selection']! as Map<String, Object?>;
      final encodedOverrides =
          encodedSelection['overrides']! as Map<String, Object?>;
      expect(encodedOverrides['audio_streams'], [
        <String, Object?>{
          'stream_index': 1,
          'bitrate_bps': 192000,
          'sample_rate_hz': 32000,
          'channel_count': 2,
        },
      ]);
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

    test('restores the per-stream manual selection payload', () {
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
            'audio_streams': <Object?>[
              <String, Object?>{
                'stream_index': 1,
                'bitrate_bps': 192000,
                'sample_rate_hz': 32000,
                'channel_count': 2,
              },
            ],
          },
        }),
      );

      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(),
        reference: reference,
      );

      expect(model.mode, EngineConfigurationEditorMode.manual);
      expect(model.canResolve, isTrue);
      expect(model.manualOverrides.audioStreams, hasLength(1));
      expect(model.manualOverrides.audioStreams!.single.bitrateBps, 192000);
      expect(model.manualOverrides.audioStreams!.single.sampleRateHz, 32000);
      expect(model.manualOverrides.audioStreams!.single.channelCount, 2);
      final selection = model.selection! as EngineManualConfigurationSelection;
      expect(selection.candidateId, 'candidate-b');
      expect(selection.overrides.videoCodec, 'hevc');
    });

    test('defaults to every candidate audio stream in source order', () {
      final model = EngineConfigurationEditorModel(
        snapshot: _snapshot(),
      ).selectManual(candidateId: 'candidate-b');

      expect(
        model.selectedCandidateAudioInputs.map((stream) => stream.streamIndex),
        [1, 2],
      );
      expect(model.effectiveAudioStreams.map((stream) => stream.streamIndex), [
        1,
        2,
      ]);
      expect(model.manualOverrides.audioStreams, isNull);
      expect(model.canResolve, isTrue);
    });

    test('rejects empty duplicate and unsorted audio stream selections', () {
      final base = EngineConfigurationEditorModel(snapshot: _snapshot());
      for (final streams in <List<EngineAudioStreamOverride>>[
        const [],
        const [
          EngineAudioStreamOverride(streamIndex: 1),
          EngineAudioStreamOverride(streamIndex: 1),
        ],
        const [
          EngineAudioStreamOverride(streamIndex: 2),
          EngineAudioStreamOverride(streamIndex: 1),
        ],
      ]) {
        final model = base.selectManual(
          candidateId: 'candidate-b',
          overrides: EngineManualOverrides(audioStreams: streams),
        );
        expect(model.canResolve, isFalse);
        expect(model.selection, isNull);
      }
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

  group('EngineTaskFolderSelectionPlanner', () {
    test('maps a shared preset to each snapshot candidate', () {
      final planner = EngineTaskFolderSelectionPlanner({
        'first': _snapshot(
          candidateIds: const ['candidate-a'],
          sharedPresetId: 'balanced',
        ),
        'second': _snapshot(
          candidateIds: const ['candidate-b'],
          sharedPresetId: 'balanced',
        ),
      });

      final selections = planner.resolve(
        const EnginePresetSelection(
          presetId: 'balanced',
          candidateId: 'candidate-a',
        ),
      );

      expect(
        (selections['first']! as EnginePresetSelection).candidateId,
        'candidate-a',
      );
      expect(
        (selections['second']! as EnginePresetSelection).candidateId,
        'candidate-b',
      );
    });

    test('rejects a manual candidate absent from any folder snapshot', () {
      final planner = EngineTaskFolderSelectionPlanner({
        'first': _snapshot(candidateIds: const ['candidate-a']),
        'second': _snapshot(candidateIds: const ['candidate-b']),
      });

      expect(
        () => planner.resolve(
          const EngineManualConfigurationSelection(candidateId: 'candidate-a'),
        ),
        throwsA(isA<EngineTaskFolderSelectionException>()),
      );
    });
  });

  group('SaveTaskFolderEngineConfigurationUseCase', () {
    test(
      'maps one shared preset to each snapshot candidate before persisting',
      () async {
        final first = _readyFolderTask('task-a', 'folder-1');
        final second = _readyFolderTask('task-b', 'folder-1');
        final repository = _MemoryMediaTaskRepository([first, second]);

        await SaveTaskFolderEngineConfigurationUseCase(
          repository: repository,
          analysisProjectionRepository: _MemoryProjectionRepository([
            _projection(first.id),
            _projection(second.id),
          ]),
        ).call(
          folderId: 'folder-1',
          snapshots: {
            first.id: _snapshot(
              candidateIds: const ['candidate-a'],
              sharedPresetId: 'shared-preset',
            ),
            second.id: _snapshot(
              candidateIds: const ['candidate-b'],
              sharedPresetId: 'shared-preset',
            ),
          },
          selection: const EnginePresetSelection(
            presetId: 'shared-preset',
            candidateId: 'candidate-a',
          ),
        );

        expect(repository.insertCalls, 1);
        expect(
          repository.taskById(first.id).config.engineConfiguration?.candidateId,
          'candidate-a',
        );
        expect(
          repository
              .taskById(second.id)
              .config
              .engineConfiguration
              ?.candidateId,
          'candidate-b',
        );
        final secondSelection =
            jsonDecode(
                  repository
                      .taskById(second.id)
                      .config
                      .engineConfiguration!
                      .selectionJson,
                )
                as Map<String, dynamic>;
        final secondSelectionPayload =
            secondSelection['selection'] as Map<String, dynamic>;
        expect(secondSelectionPayload['candidate_id'], 'candidate-b');
        expect(secondSelectionPayload['preset_id'], 'shared-preset');
      },
    );

    test(
      'rejects a manual candidate missing from one snapshot without writes',
      () async {
        final first = _readyFolderTask('task-a', 'folder-1');
        final second = _readyFolderTask('task-b', 'folder-1');
        final repository = _MemoryMediaTaskRepository([first, second]);

        await expectLater(
          SaveTaskFolderEngineConfigurationUseCase(
            repository: repository,
            analysisProjectionRepository: _MemoryProjectionRepository([
              _projection(first.id),
              _projection(second.id),
            ]),
          ).call(
            folderId: 'folder-1',
            snapshots: {
              first.id: _snapshot(candidateIds: const ['candidate-a']),
              second.id: _snapshot(candidateIds: const ['candidate-b']),
            },
            selection: const EngineManualConfigurationSelection(
              candidateId: 'candidate-a',
              overrides: EngineManualOverrides(container: 'mp4'),
            ),
          ),
          throwsA(isA<EngineTaskFolderSelectionException>()),
        );

        expect(repository.insertCalls, 0);
        expect(
          repository.taskById(first.id).config.engineConfiguration,
          isNull,
        );
        expect(
          repository.taskById(second.id).config.engineConfiguration,
          isNull,
        );
      },
    );
  });
}

MediaTask _readyFolderTask(String id, String folderId) {
  return MediaTask(
    id: id,
    inputPath: '/tmp/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: MediaTaskConfig.initialVideo(),
    progress: 0,
    sortOrder: 0,
    folderId: folderId,
    folderSortOrder: 0,
    analysisResult: MediaAnalysisResult(durationMs: 1000),
    analysisUpdatedAt: 1,
    createdAt: 1,
  );
}

EngineAnalysisProjection _projection(String taskId) {
  return EngineAnalysisProjection(
    taskId: taskId,
    clientFileId: taskId,
    engineSessionId: 'session-1',
    analysisId: 'analysis-1',
    revision: 4,
    schemaVersion: 'framelean.analysis-snapshot.v1',
    validityStatus: 'valid',
    lastEventSequence: 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
}

final class _MemoryProjectionRepository
    implements EngineAnalysisProjectionRepository {
  _MemoryProjectionRepository(Iterable<EngineAnalysisProjection> projections)
    : values = {
        for (final projection in projections) projection.taskId: projection,
      };

  final Map<String, EngineAnalysisProjection> values;

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<void> deleteByTaskId(String taskId) async => values.remove(taskId);

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    return values[taskId];
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    values[projection.taskId] = projection;
  }
}

final class _MemoryMediaTaskRepository implements MediaTaskRepository {
  _MemoryMediaTaskRepository(Iterable<MediaTask> tasks)
    : values = {for (final task in tasks) task.id: task};

  final Map<String, MediaTask> values;
  int insertCalls = 0;

  MediaTask taskById(String taskId) => values[taskId]!;

  @override
  Future<void> deleteTaskById(String taskId) async => values.remove(taskId);

  @override
  Future<void> insertTasks(List<MediaTask> tasks) async {
    insertCalls += 1;
    for (final task in tasks) {
      values[task.id] = task;
    }
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async => values.values.toList();

  @override
  Future<MediaTask?> loadTaskById(String taskId) async => values[taskId];

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    return [for (final taskId in taskIds) ?values[taskId]];
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    values
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
  }

  @override
  Future<void> saveTask(MediaTask task) async => values[task.id] = task;

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {}

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {}
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
  String? sharedPresetId,
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
    'requirements': <String, Object?>{
      'audio_streams': <Object?>[
        <String, Object?>{
          'stream_index': 1,
          'codec': 'pcm_s16le',
          'sample_rate_hz': 48000,
          'channel_count': 2,
        },
        <String, Object?>{
          'stream_index': 2,
          'codec': 'pcm_s16le',
          'sample_rate_hz': 44100,
          'channel_count': 1,
        },
      ],
    },
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
        _preset(
          id: sharedPresetId ?? 'preset-a',
          candidate: candidates['candidate-a']!,
        ),
      if (candidates.containsKey('candidate-b'))
        _preset(
          id: sharedPresetId ?? 'preset-b',
          candidate: candidates['candidate-b']!,
        ),
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
    'audio_decoders': <Object?>[
      <String, Object?>{'stream_index': 1, 'backend_id': 'audio-decoder'},
      <String, Object?>{'stream_index': 2, 'backend_id': 'audio-decoder'},
    ],
    'processors': <Object?>[],
    'video_encoder': second ? 'hevc-encoder' : 'h264-encoder',
    'audio_encoder': 'aac-encoder',
    'muxer': second ? 'mov-muxer' : 'mp4-muxer',
    'output_container': second ? 'mov' : 'mp4',
    'output_video_codec': second ? 'hevc' : 'h264',
    'output_video_profile': null,
    'output_audio_codec': 'aac',
    'audio_bitrate_options_bps': <Object?>[64000, 96000, 128000, 192000],
    'audio_sample_rate_options_hz': <Object?>[32000, 44100, 48000],
    'audio_channel_count_options': <Object?>[1, 2],
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
    'audio_streams': <Object?>[
      <String, Object?>{
        'input_stream_index': 1,
        'decoder_backend': 'audio-decoder',
        'encoder_backend': 'aac-encoder',
        'output_codec': 'aac',
      },
    ],
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
    'audio_bitrates_bps': option(192000, const ['candidate-a', 'candidate-b']),
    'audio_sample_rates_hz': option(32000, const [
      'candidate-a',
      'candidate-b',
    ]),
    'audio_channel_counts': option(2, const ['candidate-a', 'candidate-b']),
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
