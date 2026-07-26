import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_media_display_projection_mapper.dart';

void main() {
  const mapper = EngineMediaDisplayProjectionMapper();

  test('maps FLL video and audio facts into the legacy display model', () {
    final result = mapper.map(
      _snapshot(<String, Object?>{
        'file_size': 45_000_000,
        'format': _detected('mov'),
        'duration': _detected(<String, Object?>{
          'value': 90_000,
          'timescale': 1000,
        }),
        'descriptor': <String, Object?>{
          'type': 'video',
          'streams': <Object?>[
            <String, Object?>{
              'type': 'video',
              'info': <String, Object?>{
                'stream_index': 0,
                'codec': 'hevc',
                'width': 3840,
                'height': 2160,
                'frame_rate': _detected(<String, Object?>{
                  'numerator': 30_000,
                  'denominator': 1001,
                }),
                'bitrate': _detected(3_000_000),
                'pixel_format': _detected('yuv420p10le'),
                'bit_depth': _detected(10),
                'hdr': <String, Object?>{
                  'color_range': _detected('tv'),
                  'color_space': _detected('bt2020nc'),
                  'color_transfer': _detected('smpte2084'),
                  'color_primaries': _detected('bt2020'),
                },
              },
            },
            <String, Object?>{
              'type': 'audio',
              'info': <String, Object?>{
                'stream_index': 1,
                'codec': 'aac',
                'bitrate': _detected(192_000),
                'channel_count': _detected(2),
                'sample_rate_hz': _detected(48_000),
                'channel_layout': _detected('stereo'),
              },
            },
            <String, Object?>{
              'type': 'audio',
              'info': <String, Object?>{
                'stream_index': 3,
                'codec': 'ac3',
                'bitrate': _detected(384_000),
                'channel_count': _detected(6),
                'sample_rate_hz': _detected(48_000),
                'channel_layout': _detected('5.1'),
              },
            },
          ],
        },
      }),
    );

    expect(result.durationMs, 90_000);
    expect(result.containerFormat, 'mov');
    expect(result.videoWidth, 3840);
    expect(result.videoHeight, 2160);
    expect(result.videoCodec, 'hevc');
    expect(result.videoPixelFormat, 'yuv420p10le');
    expect(result.videoBitDepth, 10);
    expect(result.averageFrameRate, '30000/1001');
    expect(result.realFrameRate, '30000/1001');
    expect(result.videoBitrate, 3_000_000);
    expect(result.estimatedBitrate, 4_000_000);
    expect(result.colorTransfer, 'smpte2084');
    expect(result.colorPrimaries, 'bt2020');
    expect(result.audioCodec, 'aac');
    expect(result.audioStreamIndex, 1);
    expect(result.audioStreams, hasLength(2));
    expect(result.audioStreams.last.index, 3);
    expect(result.audioStreams.last.channels, 6);
  });

  test('ignores values whose FLL observation status is not detected', () {
    final result = mapper.map(
      _snapshot(<String, Object?>{
        'file_size': 100,
        'format': _notDetected(),
        'duration': _notDetected(),
        'descriptor': <String, Object?>{
          'type': 'image',
          'image': <String, Object?>{
            'codec': 'png',
            'width': 1280,
            'height': 720,
            'pixel_format': _notDetected(value: 'rgba'),
            'bit_depth': _detected(8),
          },
        },
      }),
    );

    expect(result.containerFormat, isNull);
    expect(result.durationMs, isNull);
    expect(result.estimatedBitrate, isNull);
    expect(result.imageCodec, 'png');
    expect(result.imageWidth, 1280);
    expect(result.imageHeight, 720);
    expect(result.imagePixelFormat, isNull);
    expect(result.imageBitDepth, 8);
  });
}

EngineAnalysisSnapshotDocument _snapshot(Map<String, Object?> media) {
  return EngineAnalysisSnapshotDocument.fromJson(<String, Object?>{
    'schema_version': 'framelean.analysis-snapshot.v1',
    'analysis_id': 'analysis-1',
    'analysis_revision': 1,
    'decision_model_revision': 1,
    'estimator_model_revision': 1,
    'task_mode': 'video_compress',
    'media': media,
    'source_fingerprint': <String, Object?>{},
    'requirements': <String, Object?>{},
    'environment_summary': <String, Object?>{},
    'engine_backend_summary': <String, Object?>{},
    'capabilities': <String, Object?>{
      'available': false,
      'execution_chains': <Object?>[],
    },
    'configuration_options': <String, Object?>{
      'candidate_ids': <Object?>[],
      'containers': <Object?>[],
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
      'status': 'unavailable',
      'configuration': null,
      'estimate': null,
      'reasons': <Object?>[],
    },
    'presets': <Object?>[],
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
  });
}

Map<String, Object?> _detected(Object value) {
  return <String, Object?>{'status': 'detected', 'value': value};
}

Map<String, Object?> _notDetected({Object? value}) {
  return <String, Object?>{'status': 'absent', 'value': value};
}
