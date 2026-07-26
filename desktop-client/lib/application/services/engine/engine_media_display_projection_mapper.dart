import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/domain/library.dart';

/// Temporary compatibility projection for Client views that still read the
/// legacy media facts from [MediaTask].
///
/// Decisions, presets, estimates, and capability filtering must continue to
/// come from [EngineAnalysisSnapshotDocument].
final class EngineMediaDisplayProjectionMapper {
  const EngineMediaDisplayProjectionMapper();

  MediaAnalysisResult map(EngineAnalysisSnapshotDocument snapshot) {
    final media = _object(snapshot.raw['media']);
    final descriptor = _object(media?['descriptor']);
    final durationMs = _durationMilliseconds(
      _observedValue(media?['duration']),
    );
    final fileSize = _integer(media?['file_size']);
    final streams = _objectList(descriptor?['streams']);
    final video = _firstStream(streams, 'video');
    final audioStreamMaps = _streamsOfType(streams, 'audio');
    final audio = audioStreamMaps.firstOrNull;
    final image = _object(descriptor?['image']);
    final videoFrameRate = _rationalText(_observedValue(video?['frame_rate']));
    final videoBitrate = _integer(_observedValue(video?['bitrate']));
    final audioBitrate = _integer(_observedValue(audio?['bitrate']));

    return MediaAnalysisResult(
      durationMs: durationMs,
      videoWidth: _integer(video?['width']),
      videoHeight: _integer(video?['height']),
      videoCodec: _string(video?['codec']),
      audioCodec: _string(audio?['codec']),
      videoPixelFormat: _string(_observedValue(video?['pixel_format'])),
      videoBitDepth: _integer(_observedValue(video?['bit_depth'])),
      colorRange: _string(
        _observedValue(_object(video?['hdr'])?['color_range']),
      ),
      colorSpace: _string(
        _observedValue(_object(video?['hdr'])?['color_space']),
      ),
      colorTransfer: _string(
        _observedValue(_object(video?['hdr'])?['color_transfer']),
      ),
      colorPrimaries: _string(
        _observedValue(_object(video?['hdr'])?['color_primaries']),
      ),
      averageFrameRate: videoFrameRate,
      realFrameRate: videoFrameRate,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      estimatedBitrate: _estimatedBitrate(
        fileSizeBytes: fileSize,
        durationMs: durationMs,
      ),
      containerFormat: _string(_observedValue(media?['format'])),
      audioChannels: _integer(_observedValue(audio?['channel_count'])),
      audioSampleRate: _integer(_observedValue(audio?['sample_rate_hz'])),
      audioChannelLayout: _string(_observedValue(audio?['channel_layout'])),
      audioStreamIndex: _integer(audio?['stream_index']),
      audioStreams: List.unmodifiable(
        audioStreamMaps.map(_audioStreamProjection),
      ),
      imageWidth: _integer(image?['width']),
      imageHeight: _integer(image?['height']),
      imageCodec: _string(image?['codec']),
      imagePixelFormat: _string(_observedValue(image?['pixel_format'])),
      imageBitDepth: _integer(_observedValue(image?['bit_depth'])),
    );
  }

  MediaAudioStreamInfo _audioStreamProjection(Map<String, Object?> info) {
    return MediaAudioStreamInfo(
      index: _integer(info['stream_index']) ?? 0,
      codec: _string(info['codec']),
      channels: _integer(_observedValue(info['channel_count'])),
      sampleRate: _integer(_observedValue(info['sample_rate_hz'])),
      channelLayout: _string(_observedValue(info['channel_layout'])),
    );
  }

  Map<String, Object?>? _firstStream(
    List<Map<String, Object?>> streams,
    String type,
  ) {
    return _streamsOfType(streams, type).firstOrNull;
  }

  List<Map<String, Object?>> _streamsOfType(
    List<Map<String, Object?>> streams,
    String type,
  ) {
    return streams
        .where((stream) => stream['type'] == type)
        .map((stream) => _object(stream['info']))
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  Object? _observedValue(Object? raw) {
    final observed = _object(raw);
    if (observed?['status'] != 'detected') {
      return null;
    }
    return observed?['value'];
  }

  int? _durationMilliseconds(Object? raw) {
    final duration = _object(raw);
    final value = _integer(duration?['value']);
    final timescale = _integer(duration?['timescale']);
    if (value == null || timescale == null || timescale <= 0) {
      return null;
    }
    return value * 1000 ~/ timescale;
  }

  String? _rationalText(Object? raw) {
    final rational = _object(raw);
    final numerator = _integer(rational?['numerator']);
    final denominator = _integer(rational?['denominator']);
    if (numerator == null || denominator == null || denominator <= 0) {
      return null;
    }
    return '$numerator/$denominator';
  }

  int? _estimatedBitrate({
    required int? fileSizeBytes,
    required int? durationMs,
  }) {
    if (fileSizeBytes == null || durationMs == null || durationMs <= 0) {
      return null;
    }
    return fileSizeBytes * 8 * 1000 ~/ durationMs;
  }

  List<Map<String, Object?>> _objectList(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return value
        .map(_object)
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
  }

  Map<String, Object?>? _object(Object? value) {
    if (value is! Map) {
      return null;
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        result[key] = entry.value;
      }
    }
    return result;
  }

  String? _string(Object? value) => value is String ? value : null;

  int? _integer(Object? value) => value is int ? value : null;
}
