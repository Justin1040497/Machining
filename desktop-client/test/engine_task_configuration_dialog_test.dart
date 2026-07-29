import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/engine_task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_configuration_dialog_widgets.dart';

void main() {
  testWidgets('renders FLL preset content and resolves exact IDs', (
    tester,
  ) async {
    final task = _task();
    final snapshot = _snapshot();
    final resolvedTask = task.copyWith(fileName: 'resolved.mp4');
    EngineConfigurationSelection? selection;
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final dialogFuture = showEngineTaskConfigurationEditor(
      context: hostContext,
      task: task,
      snapshot: snapshot,
      onResolve: (value) async {
        selection = value;
        return resolvedTask;
      },
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('任务模式已由分析结果锁定：'), findsOneWidget);
    expect(find.textContaining('视频压缩'), findsOneWidget);
    expect(find.text('格式转换'), findsNothing);
    expect(find.text('FLL 推荐预设'), findsOneWidget);
    expect(find.text('FLL 按源文件特点选择的方案'), findsOneWidget);
    expect(find.text('预计输出：200B'), findsOneWidget);
    expect(find.text('风险：HDR 可能需要色调映射'), findsOneWidget);
    expect(find.text('体积优先'), findsNothing);

    await tester.tap(find.text('FLL 推荐预设'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(selection, isA<EnginePresetSelection>());
    final presetSelection = selection! as EnginePresetSelection;
    expect(presetSelection.presetId, 'fll-preset-opaque');
    expect(presetSelection.candidateId, 'candidate-opaque');
    expect(await dialogFuture, same(resolvedTask));
  });

  testWidgets('shows unavailable without falling back to legacy controls', (
    tester,
  ) async {
    final task = _task();
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final dialogFuture = showEngineTaskConfigurationEditor(
      context: hostContext,
      task: task,
      snapshot: _snapshot(candidateIds: const [], includePresets: false),
      onResolve: (_) async => task,
    );
    await tester.pumpAndSettle();

    expect(find.text('当前配置不可用'), findsOneWidget);
    expect(find.text('当前分析结果没有可执行候选方案。'), findsOneWidget);
    expect(find.text('可用预设'), findsNothing);
    expect(find.text('质量'), findsNothing);
    expect(find.text('视频编码'), findsNothing);
    expect(find.text('输出容器'), findsNothing);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogFuture, isNull);
  });

  testWidgets(
    'renders snapshot-backed audio parameter controls in manual mode',
    (tester) async {
      final task = _task();
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      final dialogFuture = showEngineTaskConfigurationEditor(
        context: hostContext,
        task: task,
        snapshot: _snapshot(),
        onResolve: (_) async => task,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('手动配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('请选择候选方案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('candidate-opaque').last);
      await tester.pumpAndSettle();

      expect(find.text('保留音轨 1'), findsOneWidget);
      expect(find.textContaining('pcm_s16le'), findsOneWidget);
      expect(find.text('码率'), findsOneWidget);
      expect(find.text('采样率'), findsOneWidget);
      expect(find.text('声道'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await dialogFuture, isNull);
    },
  );

  testWidgets('shows unavailable when FLL has no presets', (tester) async {
    final task = _task();
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final dialogFuture = showEngineTaskConfigurationEditor(
      context: hostContext,
      task: task,
      snapshot: _snapshot(includePresets: false),
      onResolve: (_) async => task,
    );
    await tester.pumpAndSettle();

    expect(find.text('预设不可用'), findsOneWidget);
    expect(find.text('当前分析结果没有可用预设。手动配置仍可使用，请勿使用旧预设回退。'), findsOneWidget);
    expect(find.text('体积优先'), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogFuture, isNull);
  });

  testWidgets('keeps dialog open and reenables save after resolve failure', (
    tester,
  ) async {
    final task = _task();
    late BuildContext hostContext;
    var resolveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final dialogFuture = showEngineTaskConfigurationEditor(
      context: hostContext,
      task: task,
      snapshot: _snapshot(),
      onResolve: (_) async {
        resolveCalls++;
        throw StateError('resolve failed');
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('FLL 推荐预设'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(resolveCalls, 1);
    expect(find.text('Engine 任务配置'), findsOneWidget);
    expect(find.text('配置解析失败：Bad state: resolve failed'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await dialogFuture, isNull);
  });

  testWidgets('renders a folder summary and saves the selected FLL preset', (
    tester,
  ) async {
    final first = _task();
    final second = _task().copyWith(
      id: 'task-2',
      fileName: 'second.mp4',
      inputPath: '/tmp/second.mp4',
    );
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹 1',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    EngineConfigurationSelection? saved;
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final dialogFuture = showEngineTaskConfigurationEditor(
      context: hostContext,
      task: first,
      snapshot: _snapshot(),
      title: '任务夹 Engine 配置',
      sourceSummary: WorkbenchTaskFolderSummary(
        folder: folder,
        tasks: [first, second],
      ),
      onResolve: (selection) async {
        saved = selection;
        return first;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('任务夹 Engine 配置'), findsOneWidget);
    expect(find.text('任务数量: 2'), findsOneWidget);
    expect(find.textContaining('源文件总大小:'), findsOneWidget);

    await tester.tap(find.text('FLL 推荐预设'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isA<EnginePresetSelection>());
    expect(await dialogFuture, same(first));
  });
}

TextButton _saveButton(WidgetTester tester) {
  return tester.widget<TextButton>(
    find.ancestor(of: find.text('保存'), matching: find.byType(TextButton)).first,
  );
}

MediaTask _task() {
  return MediaTask.draft(
    inputPath: '/tmp/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    sortOrder: 0,
  );
}

EngineAnalysisSnapshotDocument _snapshot({
  List<String> candidateIds = const ['candidate-opaque'],
  bool includePresets = true,
  bool targetSizeAvailable = true,
}) {
  final candidates = <String, Map<String, Object?>>{
    for (final candidateId in candidateIds)
      candidateId: _candidate(candidateId),
  };
  final recommendation = candidateIds.isEmpty
      ? <String, Object?>{
          'status': 'unavailable',
          'configuration': null,
          'estimate': null,
          'reasons': <Object?>['没有可执行候选'],
        }
      : <String, Object?>{
          'status': 'complete',
          'configuration': _configuration(candidateIds.first),
          'estimate': _estimate(),
          'reasons': <Object?>['FLL 推荐'],
        };

  return EngineAnalysisSnapshotDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-widget',
    'analysis_revision': 7,
    'decision_model_revision': 2,
    'estimator_model_revision': 3,
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
    'presets': includePresets
        ? <Object?>[_preset(candidateIds.first)]
        : <Object?>[],
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
  return <String, Object?>{
    'id': id,
    'demuxer': 'fll-demuxer',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[
      <String, Object?>{'stream_index': 1, 'backend_id': 'fll-audio-decoder'},
    ],
    'processors': <Object?>[],
    'muxer': 'fll-muxer',
    'output_container': 'mp4',
    'output_hdr_mode': 'sdr',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
    'video_encoder': 'fll-video-encoder',
    'audio_encoder': 'fll-audio-encoder',
    'output_video_codec': 'fll-video-codec',
    'output_video_profile': null,
    'output_audio_codec': 'fll-audio-codec',
    'audio_bitrate_options_bps': <Object?>[192000],
    'audio_sample_rate_options_hz': <Object?>[32000],
    'audio_channel_count_options': <Object?>[2],
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
  };
}

Map<String, Object?> _configuration(String candidateId) {
  return <String, Object?>{
    'selection_source': 'recommendation',
    'execution_chain_id': candidateId,
    'container': 'mp4',
    'demuxer_backend': 'fll-demuxer',
    'video_decoders': <Object?>[],
    'audio_streams': <Object?>[
      <String, Object?>{
        'input_stream_index': 1,
        'decoder_backend': 'fll-audio-decoder',
        'encoder_backend': 'fll-audio-encoder',
        'output_codec': 'fll-audio-codec',
      },
    ],
    'processors': <Object?>[],
    'muxer_backend': 'fll-muxer',
    'output_hdr_mode': 'sdr',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _estimate() {
  return <String, Object?>{
    'expected_bytes': 200,
    'minimum_bytes': 150,
    'maximum_bytes': 250,
    'confidence': 'high',
    'basis': <Object?>['fll-model'],
  };
}

Map<String, Object?> _preset(String candidateId) {
  return <String, Object?>{
    'id': 'fll-preset-opaque',
    'display_name': 'FLL 推荐预设',
    'description': 'FLL 按源文件特点选择的方案',
    'applicable': true,
    'unavailable_reason': null,
    'policy_version': 9,
    'policy': <String, Object?>{'owner': 'fll'},
    'candidate': _candidate(candidateId),
    'configuration': _configuration(candidateId),
    'estimate': _estimate(),
    'risks': <Object?>['HDR 可能需要色调映射'],
  };
}

Map<String, Object?> _configurationOptions(List<String> candidateIds) {
  List<Object?> option(Object value) {
    return candidateIds.isEmpty
        ? <Object?>[]
        : <Object?>[
            <String, Object?>{'value': value, 'candidate_ids': candidateIds},
          ];
  }

  return <String, Object?>{
    'candidate_ids': candidateIds,
    'containers': option('mp4'),
    'video_codecs': option('fll-video-codec'),
    'video_profiles': <Object?>[],
    'audio_codecs': option('fll-audio-codec'),
    'audio_bitrates_bps': option(192000),
    'audio_sample_rates_hz': option(32000),
    'audio_channel_counts': option(2),
    'video_encoders': <Object?>[],
    'audio_encoders': <Object?>[],
    'pixel_formats': option('yuv420p'),
    'bit_depths': <Object?>[],
    'hdr_modes': <Object?>[],
    'preserves_hdr': option(false),
    'requires_tone_mapping': <Object?>[],
  };
}
