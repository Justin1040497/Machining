import 'dart:convert';

import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/media_processing_preset.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';

String encodeMediaTaskConfig(MediaTaskConfig config) {
  return jsonEncode(mediaTaskConfigToJson(config));
}

MediaTaskConfig decodeMediaTaskConfig(String text) {
  final json = jsonDecode(text);
  if (json is! Map<String, dynamic>) {
    throw StateError('媒体配置 JSON 格式无效');
  }

  return mediaTaskConfigFromJson(json);
}

Map<String, Object?> mediaTaskConfigToJson(MediaTaskConfig config) {
  return {
    'configVersion': 1,
    'outputDirectory': config.outputDirectory,
    'outputFileName': config.outputFileName,
    'compressionMode': config.compressionMode.name,
    'preset': config.preset?.name,
    'targetSizeBytes': config.targetSizeBytes,
    'targetSizeRatio': config.targetSizeRatio,
    'video': videoConfigToJson(config.video),
    'image': imageConfigToJson(config.image),
    'audio': audioConfigToJson(config.audio),
  };
}

MediaTaskConfig mediaTaskConfigFromJson(Map<String, dynamic> json) {
  return MediaTaskConfig(
    outputDirectory: stringValue(json['outputDirectory']) ?? '',
    outputFileName: stringValue(json['outputFileName']) ?? '',
    compressionMode:
        nullableEnumValueByName(
          CompressionMode.values,
          stringValue(json['compressionMode']),
        ) ??
        CompressionMode.preset,
    preset: nullableEnumValueByName(
      MediaProcessingPreset.values,
      stringValue(json['preset']),
    ),
    targetSizeBytes: intValue(json['targetSizeBytes']),
    targetSizeRatio: doubleValue(json['targetSizeRatio']),
    video: videoConfigFromJson(mapValue(json['video'])),
    image: imageConfigFromJson(mapValue(json['image'])),
    audio: audioConfigFromJson(mapValue(json['audio'])),
  );
}

Map<String, Object?>? videoConfigToJson(VideoProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'keepOriginalOutputFormat': config.keepOriginalOutputFormat,
    'videoCodec': config.videoCodec.name,
    'encoderBackend': config.encoderBackend.name,
    'hdrOutputMode': config.hdrOutputMode.name,
    'videoCodecBeforePreserveHdr': config.videoCodecBeforePreserveHdr?.name,
    'encoderBackendBeforePreserveHdr':
        config.encoderBackendBeforePreserveHdr?.name,
    'resolutionPreset': config.resolutionPreset.name,
    'compressionCrf': config.compressionCrf,
    'smartPreset': config.smartPreset?.name,
    'preserveMetadata': config.preserveMetadata,
  };
}

VideoProcessingConfig? videoConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return VideoProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.mp4,
    keepOriginalOutputFormat:
        boolValue(json['keepOriginalOutputFormat']) ?? false,
    videoCodec:
        nullableEnumValueByName(
          VideoCodec.values,
          stringValue(json['videoCodec']),
        ) ??
        VideoCodec.h264,
    encoderBackend:
        nullableEnumValueByName(
          EncoderBackend.values,
          stringValue(json['encoderBackend']),
        ) ??
        EncoderBackend.auto,
    hdrOutputMode:
        nullableEnumValueByName(
          HdrOutputMode.values,
          stringValue(json['hdrOutputMode']),
        ) ??
        HdrOutputMode.convertToSdr,
    videoCodecBeforePreserveHdr: nullableEnumValueByName(
      VideoCodec.values,
      stringValue(json['videoCodecBeforePreserveHdr']),
    ),
    encoderBackendBeforePreserveHdr: nullableEnumValueByName(
      EncoderBackend.values,
      stringValue(json['encoderBackendBeforePreserveHdr']),
    ),
    resolutionPreset:
        nullableEnumValueByName(
          ResolutionPreset.values,
          stringValue(json['resolutionPreset']),
        ) ??
        ResolutionPreset.original,
    compressionCrf: intValue(json['compressionCrf']) ?? 28,
    smartPreset: nullableEnumValueByName(
      SmartCompressionPreset.values,
      stringValue(json['smartPreset']),
    ),
    preserveMetadata: boolValue(json['preserveMetadata']) ?? true,
  );
}

Map<String, Object?>? imageConfigToJson(ImageProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'keepOriginalOutputFormat': config.keepOriginalOutputFormat,
    'imageQuality': config.imageQuality,
    'resizePreset': config.resizePreset.name,
    'preserveMetadata': config.preserveMetadata,
  };
}

ImageProcessingConfig? imageConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return ImageProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.jpg,
    keepOriginalOutputFormat:
        boolValue(json['keepOriginalOutputFormat']) ?? false,
    imageQuality: intValue(json['imageQuality']) ?? 100,
    resizePreset:
        nullableEnumValueByName(
          ImageResizePreset.values,
          stringValue(json['resizePreset']),
        ) ??
        ImageResizePreset.original,
    preserveMetadata: boolValue(json['preserveMetadata']) ?? false,
  );
}

Map<String, Object?>? audioConfigToJson(AudioProcessingConfig? config) {
  if (config == null) {
    return null;
  }

  return {
    'outputFormat': config.outputFormat.name,
    'keepOriginalOutputFormat': config.keepOriginalOutputFormat,
    'bitratePreset': config.bitratePreset.name,
    'sampleRate': config.sampleRate.name,
    'channels': config.channels.name,
    'preserveMetadata': config.preserveMetadata,
  };
}

AudioProcessingConfig? audioConfigFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  return AudioProcessingConfig(
    outputFormat:
        nullableEnumValueByName(
          MediaOutputFormat.values,
          stringValue(json['outputFormat']),
        ) ??
        MediaOutputFormat.m4a,
    keepOriginalOutputFormat:
        boolValue(json['keepOriginalOutputFormat']) ?? false,
    bitratePreset:
        nullableEnumValueByName(
          AudioBitratePreset.values,
          stringValue(json['bitratePreset']),
        ) ??
        AudioBitratePreset.k192,
    sampleRate:
        nullableEnumValueByName(
          AudioSampleRatePreset.values,
          stringValue(json['sampleRate']),
        ) ??
        AudioSampleRatePreset.source,
    channels:
        nullableEnumValueByName(
          AudioChannelsPreset.values,
          stringValue(json['channels']),
        ) ??
        AudioChannelsPreset.source,
    preserveMetadata: boolValue(json['preserveMetadata']) ?? true,
  );
}

Map<String, dynamic>? mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? stringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return value.toString();
}

int? intValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double? doubleValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool? boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  return switch (value?.toString()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}

T enumValueByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  throw StateError('未知的枚举值: $name');
}

T? nullableEnumValueByName<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.trim().isEmpty) {
    return null;
  }

  return enumValueByName(values, name);
}
