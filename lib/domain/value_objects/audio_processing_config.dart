import 'package:framelean/domain/enums/media_output_format.dart';

enum AudioBitratePreset { source, k320, k192, k128, k96, k64 }

enum AudioSampleRatePreset { source, hz48000, hz44100, hz32000 }

enum AudioChannelsPreset { source, stereo, mono }

/// 音频任务的分类型处理配置。
class AudioProcessingConfig {
  final MediaOutputFormat outputFormat;
  final bool keepOriginalOutputFormat;
  final AudioBitratePreset bitratePreset;
  final AudioSampleRatePreset sampleRate;
  final AudioChannelsPreset channels;
  final bool preserveMetadata;

  const AudioProcessingConfig({
    required this.outputFormat,
    required this.keepOriginalOutputFormat,
    required this.bitratePreset,
    required this.sampleRate,
    required this.channels,
    required this.preserveMetadata,
  });

  factory AudioProcessingConfig.initial() {
    return const AudioProcessingConfig(
      outputFormat: MediaOutputFormat.m4a,
      keepOriginalOutputFormat: false,
      bitratePreset: AudioBitratePreset.k192,
      sampleRate: AudioSampleRatePreset.source,
      channels: AudioChannelsPreset.source,
      preserveMetadata: true,
    );
  }

  AudioProcessingConfig copyWith({
    MediaOutputFormat? outputFormat,
    bool? keepOriginalOutputFormat,
    AudioBitratePreset? bitratePreset,
    AudioSampleRatePreset? sampleRate,
    AudioChannelsPreset? channels,
    bool? preserveMetadata,
  }) {
    return AudioProcessingConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      keepOriginalOutputFormat:
          keepOriginalOutputFormat ?? this.keepOriginalOutputFormat,
      bitratePreset: bitratePreset ?? this.bitratePreset,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    );
  }
}
