import 'package:framelean/domain/enums/audio_codec.dart';
import 'package:framelean/domain/enums/media_output_format.dart';

enum AudioBitratePreset { source, k320, k192, k128, k96, k64 }

enum AudioSampleRatePreset { source, hz48000, hz44100, hz32000 }

enum AudioChannelsPreset { source, stereo, mono }

/// 音频任务的分类型处理配置。
class AudioProcessingConfig {
  final MediaOutputFormat outputFormat;
  final AudioCodec audioCodec;
  final AudioBitratePreset bitratePreset;
  final AudioSampleRatePreset sampleRate;
  final AudioChannelsPreset channels;

  const AudioProcessingConfig({
    required this.outputFormat,
    required this.audioCodec,
    required this.bitratePreset,
    required this.sampleRate,
    required this.channels,
  });

  factory AudioProcessingConfig.initial() {
    return const AudioProcessingConfig(
      outputFormat: MediaOutputFormat.m4a,
      audioCodec: AudioCodec.aac,
      bitratePreset: AudioBitratePreset.k192,
      sampleRate: AudioSampleRatePreset.source,
      channels: AudioChannelsPreset.source,
    );
  }

  AudioProcessingConfig copyWith({
    MediaOutputFormat? outputFormat,
    AudioCodec? audioCodec,
    AudioBitratePreset? bitratePreset,
    AudioSampleRatePreset? sampleRate,
    AudioChannelsPreset? channels,
  }) {
    return AudioProcessingConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      audioCodec: audioCodec ?? this.audioCodec,
      bitratePreset: bitratePreset ?? this.bitratePreset,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
    );
  }
}
