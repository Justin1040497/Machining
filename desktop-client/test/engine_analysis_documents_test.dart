import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';

void main() {
  group('EngineAnalysisSnapshotDocument', () {
    test('preserves unknown fields and exposes only applicable presets', () {
      final snapshot = _snapshot();
      snapshot['future_top_level'] = <String, Object?>{'enabled': true};
      final unavailable =
          Map<String, Object?>.from(
              (snapshot['presets']! as List<Object?>).single
                  as Map<String, Object?>,
            )
            ..['id'] = 'compact'
            ..['display_name'] = '体积优先'
            ..['applicable'] = false
            ..['unavailable_reason'] = 'NOT_AVAILABLE'
            ..['candidate'] = null
            ..['configuration'] = null
            ..['estimate'] = null;
      (snapshot['presets']! as List<Object?>).add(unavailable);

      final document = EngineAnalysisSnapshotDocument.fromJson(snapshot);

      expect(document.analysisId, 'analysis-1');
      expect(document.availablePresets.map((preset) => preset.id), [
        'balanced',
      ]);
      expect(document.raw['future_top_level'], {'enabled': true});
      expect(
        () =>
            (document.raw['future_top_level']!
                    as Map<String, Object?>)['enabled'] =
                false,
        throwsUnsupportedError,
      );
    });

    test('parses custom target size bounds from the snapshot', () {
      final snapshot = _snapshot();
      snapshot['custom_target_size'] = <String, Object?>{
        'available': true,
        'unavailable_reason': null,
        'minimum_bytes': 100,
        'maximum_bytes': 1000,
        'default_bytes': 400,
        'step_bytes': 50,
        'display_unit': 'bytes',
      };

      final document = EngineAnalysisSnapshotDocument.fromJson(snapshot);

      expect(document.customTargetSize.available, isTrue);
      expect(document.customTargetSize.minimumBytes, 100);
      expect(document.customTargetSize.maximumBytes, 1000);
      expect(document.customTargetSize.defaultBytes, 400);
      expect(document.customTargetSize.stepBytes, 50);
    });

    test('rejects available target size options without complete bounds', () {
      final snapshot = _snapshot();
      snapshot['custom_target_size'] = <String, Object?>{
        'available': true,
        'display_unit': 'bytes',
      };

      expect(
        () => EngineAnalysisSnapshotDocument.fromJson(snapshot),
        throwsA(
          isA<EngineDocumentException>().having(
            (error) => error.path,
            'path',
            r'$.custom_target_size',
          ),
        ),
      );
    });

    test('rejects an applicable preset without a complete bound result', () {
      final snapshot = _snapshot();
      final preset =
          (snapshot['presets']! as List<Object?>).single
              as Map<String, Object?>;
      preset['estimate'] = null;

      expect(
        () => EngineAnalysisSnapshotDocument.fromJson(snapshot),
        throwsA(
          isA<EngineDocumentException>().having(
            (error) => error.path,
            'path',
            r'$.presets[0]',
          ),
        ),
      );
    });

    test('rejects a preset configuration for another candidate', () {
      final snapshot = _snapshot();
      final preset =
          (snapshot['presets']! as List<Object?>).single
              as Map<String, Object?>;
      final configuration = preset['configuration']! as Map<String, Object?>;
      configuration['execution_chain_id'] = 'candidate-other';

      expect(
        () => EngineAnalysisSnapshotDocument.fromJson(snapshot),
        throwsA(
          isA<EngineDocumentException>().having(
            (error) => error.path,
            'path',
            r'$.presets[0].configuration.execution_chain_id',
          ),
        ),
      );
    });

    test('rejects a preset candidate that diverges from capabilities', () {
      final snapshot = _snapshot();
      final preset =
          (snapshot['presets']! as List<Object?>).single
              as Map<String, Object?>;
      final candidate = preset['candidate']! as Map<String, Object?>;
      candidate['output_container'] = 'mkv';

      expect(
        () => EngineAnalysisSnapshotDocument.fromJson(snapshot),
        throwsA(
          isA<EngineDocumentException>().having(
            (error) => error.path,
            'path',
            r'$.presets[0].candidate',
          ),
        ),
      );
    });

    test('rejects option graph references to unknown candidates', () {
      final snapshot = _snapshot();
      final graph = snapshot['configuration_options']! as Map<String, Object?>;
      graph['containers'] = <Object?>[
        <String, Object?>{
          'value': 'mp4',
          'candidate_ids': <Object?>['candidate-other'],
        },
      ];

      expect(
        () => EngineAnalysisSnapshotDocument.fromJson(snapshot),
        throwsA(
          isA<EngineDocumentException>().having(
            (error) => error.path,
            'path',
            r'$.configuration_options.containers[0].candidate_ids',
          ),
        ),
      );
    });

    test('surfaces an invalid snapshot without treating it as malformed', () {
      final snapshot = _snapshot();
      snapshot['validity'] = <String, Object?>{
        'status': 'invalid',
        'reason_code': 'ANALYSIS_SOURCE_CHANGED',
        'message': 'source changed',
      };

      final document = EngineAnalysisSnapshotDocument.fromJson(snapshot);

      expect(document.validity.isValid, isFalse);
      expect(document.validity.reasonCode, 'ANALYSIS_SOURCE_CHANGED');
    });
  });

  group('EngineAnalysisResponseDocument', () {
    test('keeps failed analysis as a typed FLL result', () {
      final response = <String, Object?>{
        'schema_version': 'framelean.analyze-media.v1',
        'analysis_id': 'analysis-1',
        'analysis_revision': 1,
        'task_mode': 'video_compress',
        'media_analysis_status': 'failed',
        'configuration_status': 'not_evaluated',
        'media': null,
        'source_fingerprint': null,
        'requirements': null,
        'environment_summary': null,
        'engine_backend_summary': null,
        'capabilities': null,
        'configuration_options': null,
        'recommendation': null,
        'presets': <Object?>[],
        'custom_target_size': null,
        'warnings': <Object?>[],
        'error': <String, Object?>{
          'code': 'MEDIA_INVALID_FORMAT',
          'message': 'cannot analyze input',
          'retryable': false,
        },
      };

      final document = EngineAnalysisResponseDocument.fromJson(response);

      expect(document.mediaAnalysisStatus, EngineMediaAnalysisStatus.failed);
      expect(document.hasSnapshot, isFalse);
      expect(document.errorCode, 'MEDIA_INVALID_FORMAT');
    });
  });
}

Map<String, Object?> _snapshot() {
  final candidate = _candidate();
  final configuration = _configuration();
  final estimate = _estimate();
  return <String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 1,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': 'video_compress',
    'media': <String, Object?>{},
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{
      'available': true,
      'execution_chains': <Object?>[Map<String, Object?>.from(candidate)],
    },
    'configuration_options': <String, Object?>{
      'candidate_ids': <Object?>['candidate-1'],
      'containers': <Object?>[
        <String, Object?>{
          'value': 'mp4',
          'candidate_ids': <Object?>['candidate-1'],
        },
      ],
      'video_codecs': <Object?>[],
      'video_profiles': <Object?>[],
      'audio_codecs': <Object?>[],
      'video_encoders': <Object?>[],
      'audio_encoders': <Object?>[],
      'pixel_formats': <Object?>[],
      'bit_depths': <Object?>[],
      'hdr_modes': <Object?>[],
      'preserves_hdr': <Object?>[],
      'requires_tone_mapping': <Object?>[],
    },
    'recommendation': <String, Object?>{
      'status': 'complete',
      'configuration': Map<String, Object?>.from(configuration),
      'reasons': <Object?>['balanced'],
      'estimate': Map<String, Object?>.from(estimate),
      'resource_sample_unix_ms': 1,
    },
    'presets': <Object?>[
      <String, Object?>{
        'id': 'balanced',
        'display_name': '均衡推荐',
        'description': '明显变小',
        'applicable': true,
        'unavailable_reason': null,
        'policy_version': 1,
        'policy': <String, Object?>{},
        'candidate': Map<String, Object?>.from(candidate),
        'configuration': Map<String, Object?>.from(configuration),
        'estimate': Map<String, Object?>.from(estimate),
        'risks': <Object?>[],
      },
    ],
    'custom_target_size': <String, Object?>{
      'available': false,
      'unavailable_reason': 'ENGINE_EXECUTION_CHAIN_NOT_READY',
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
  };
}

Map<String, Object?> _candidate() {
  return <String, Object?>{
    'id': 'candidate-1',
    'demuxer': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'processors': <Object?>[],
    'video_encoder': 'video-encoder-1',
    'audio_encoder': 'audio-encoder-1',
    'muxer': 'muxer-1',
    'output_container': 'mp4',
    'output_video_codec': 'h264',
    'output_video_profile': null,
    'output_audio_codec': 'aac',
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
    'output_hdr_mode': 'sdr',
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _configuration() {
  return <String, Object?>{
    'selection_source': 'preset',
    'selected_preset': 'balanced',
    'execution_chain_id': 'candidate-1',
    'container': 'mp4',
    'video_codec': 'h264',
    'video_profile': null,
    'audio_codec': 'aac',
    'demuxer_backend': 'demuxer-1',
    'video_decoders': <Object?>[],
    'audio_decoders': <Object?>[],
    'video_encoder_backend': 'video-encoder-1',
    'audio_encoder_backend': 'audio-encoder-1',
    'processors': <Object?>[],
    'muxer_backend': 'muxer-1',
    'output_pixel_format': 'yuv420p',
    'output_bit_depth': 8,
    'output_hdr_mode': 'sdr',
    'target_size': null,
    'target_video_bitrate': 2000000,
    'target_audio_bitrate': 96000,
    'preserves_hdr': false,
    'requires_tone_mapping': false,
  };
}

Map<String, Object?> _estimate() {
  return <String, Object?>{
    'expected_bytes': 100,
    'minimum_bytes': 80,
    'maximum_bytes': 120,
    'recommended_video_bitrate': 2000000,
    'recommended_audio_bitrate': 96000,
    'confidence': 'low',
    'basis': <Object?>['baseline'],
  };
}
