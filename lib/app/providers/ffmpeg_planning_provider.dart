import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';

// Binds FFmpeg planning abstractions to local implementations.
/// 压缩策略建议服务，决定压缩画像、码率和 CRF 等参数
final compressionAdvisorProvider = Provider<CompressionAdvisor>((ref) {
  return DefaultCompressionAdvisor();
});

/// FFmpeg 命令构造服务，只生成参数计划，不启动进程
final defaultFfmpegCommandBuilderProvider =
    Provider<DefaultFfmpegCommandBuilder>((ref) {
      return DefaultFfmpegCommandBuilder(
        compressionAdvisor: ref.watch(compressionAdvisorProvider),
      );
    });

/// FFmpeg 命令构造服务，只生成参数计划，不启动进程
final ffmpegCommandBuilderProvider = Provider<FfmpegCommandBuilder>((ref) {
  return ref.watch(defaultFfmpegCommandBuilderProvider);
});
