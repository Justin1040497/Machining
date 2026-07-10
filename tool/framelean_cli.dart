import 'dart:io';

import 'package:args/args.dart';
import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_observer.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_starter.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';
import 'package:framelean/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_ffmpeg_locator.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final compressionAdvisor = DefaultCompressionAdvisor();
  final cli = FrameLeanCli(
    locator: LocalFfmpegLocator(),
    analyzer: FfprobeMediaAnalyzer(),
    compressionAdvisor: compressionAdvisor,
    commandBuilder: DefaultFfmpegCommandBuilder(
      compressionAdvisor: compressionAdvisor,
    ),
    processStarter: LocalFfmpegProcessStarter(),
    processObserver: LocalFfmpegProcessObserver(),
  );

  exitCode = await cli.run(args);
}

class FrameLeanCli {
  final LocalFfmpegLocator locator;
  final FfprobeMediaAnalyzer analyzer;
  final DefaultCompressionAdvisor compressionAdvisor;
  final DefaultFfmpegCommandBuilder commandBuilder;
  final LocalFfmpegProcessStarter processStarter;
  final LocalFfmpegProcessObserver processObserver;

  const FrameLeanCli({
    required this.locator,
    required this.analyzer,
    required this.compressionAdvisor,
    required this.commandBuilder,
    required this.processStarter,
    required this.processObserver,
  });

  // ---------------------------------------------------------------------------
  // Entry point / dispatch
  // ---------------------------------------------------------------------------

  Future<int> run(List<String> args) async {
    final parser = buildParser();
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      printUsage();
      return 0;
    }

    late final ArgResults result;
    try {
      result = parser.parse(args);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      printUsage();
      return 64;
    }

    final command = result.command;
    if (command == null) {
      stderr.writeln('不支持的命令: ${args.first}');
      printUsage();
      return 64;
    }

    final commandName = command.name;

    if (command['help'] == true) {
      printUsage(commandName: commandName);
      return 0;
    }

    return switch (commandName) {
      'compress' => runCompress(command),
      'image' => runImage(command),
      'audio' => runAudio(command),
      _ => _unsupported(args.first),
    };
  }

  int _unsupported(String name) {
    stderr.writeln('不支持的命令: $name');
    printUsage();
    return 64;
  }

  // ---------------------------------------------------------------------------
  // Arg parser
  // ---------------------------------------------------------------------------

  ArgParser buildParser() {
    final parser = ArgParser();

    parser.addCommand('compress', _buildCompressParser());
    parser.addCommand('image', _buildImageParser());
    parser.addCommand('audio', _buildAudioParser());

    return parser;
  }

  ArgParser _buildCompressParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: '显示 compress 命令帮助。')
      ..addOption(
        'codec',
        abbr: 'c',
        allowed: [
          'source', 'h264', 'h265', 'hevc',
          'vp9', 'av1', 'prores', 'mpeg4', 'mjpeg',
        ],
        help: '目标视频编码。不传时使用 App 默认编码，初始为 H.264。',
      )
      ..addOption(
        'encoder-backend',
        abbr: 'e',
        allowed: EncoderBackend.values.map((e) => e.name),
        help: '编码器实现后端。默认 auto（自动选择最佳可用编码器）。',
      )
      ..addOption(
        'crf',
        help: 'CRF 质量值 (0-51)，越小质量越高。默认 28。',
        defaultsTo: '28',
      )
      ..addOption(
        'smart-preset',
        abbr: 'p',
        allowed: SmartCompressionPreset.values.map((e) => e.name),
        defaultsTo: SmartCompressionPreset.balanced.name,
        help: '智能压缩预设: balanced, chat, clear, compact。',
      )
      ..addOption(
        'mode',
        abbr: 'm',
        allowed: CompressionMode.values.map((e) => e.name),
        defaultsTo: CompressionMode.preset.name,
        help: '压缩策略: preset (预设质量) 或 targetSize (指定目标体积)。',
      )
      ..addOption(
        'target-size',
        help: '目标输出体积，如 "50MB"、"1.2GB"、"500KB"。仅 mode=targetSize 时有效。',
      )
      ..addOption(
        'output-format',
        abbr: 'f',
        allowed: OutputFormat.values.map((e) => e.name),
        defaultsTo: OutputFormat.mp4.name,
        help: '输出容器格式: mp4, mov, mkv, webm, avi。',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: '输出目录。默认与源文件同目录。',
      )
      ..addOption(
        'resolution',
        abbr: 'r',
        defaultsTo: 'original',
        allowed: ['original', '2160p', '1080p', '720p', '480p'],
        help: '目标分辨率。original 表示保持原始分辨率。',
      );
  }

  ArgParser _buildImageParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: '显示 image 命令帮助。')
      ..addOption(
        'format',
        abbr: 'f',
        allowed: const ['jpg', 'png', 'webp', 'bmp', 'tiff', 'gif'],
        defaultsTo: 'jpg',
        help: '输出图片格式。',
      )
      ..addOption(
        'quality',
        abbr: 'q',
        defaultsTo: '80',
        help: '图片质量 (1-100)。默认 80。',
      )
      ..addFlag(
        'lossless',
        negatable: false,
        help: '无损压缩（仅 PNG / WebP / TIFF 支持）。',
      )
      ..addOption(
        'resize',
        allowed: ImageResizePreset.values.map((e) => e.name),
        defaultsTo: ImageResizePreset.original.name,
        help: '长边缩放预设: original, longEdge3840, longEdge2560, '
            'longEdge1920, longEdge1280, longEdge720。',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: '输出目录。默认与源文件同目录。',
      );
  }

  ArgParser _buildAudioParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: '显示 audio 命令帮助。')
      ..addOption(
        'format',
        abbr: 'f',
        allowed: const [
          'mp3', 'm4a', 'aac', 'wav', 'flac', 'aiff', 'wma', 'opus', 'oggOpus',
        ],
        defaultsTo: 'm4a',
        help: '输出音频格式。',
      )
      ..addOption(
        'bitrate',
        abbr: 'b',
        allowed: AudioBitratePreset.values.map((e) => e.name),
        defaultsTo: AudioBitratePreset.k192.name,
        help: '音频码率: source, k320, k192, k128, k96, k64。',
      )
      ..addOption(
        'sample-rate',
        allowed: AudioSampleRatePreset.values.map((e) => e.name),
        defaultsTo: AudioSampleRatePreset.source.name,
        help: '采样率: source, hz48000, hz44100, hz32000。',
      )
      ..addOption(
        'channels',
        abbr: 'c',
        allowed: AudioChannelsPreset.values.map((e) => e.name),
        defaultsTo: AudioChannelsPreset.source.name,
        help: '声道: source, stereo, mono。',
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: '输出目录。默认与源文件同目录。',
      );
  }

  // ---------------------------------------------------------------------------
  // compress
  // ---------------------------------------------------------------------------

  Future<int> runCompress(ArgResults command) async {
    final rest = command.rest;
    if (rest.isEmpty) {
      stderr.writeln('compress 命令需要至少一个视频文件路径。');
      printUsage(commandName: 'compress');
      return 64;
    }

    late final CliCompressOptions options;
    try {
      options = _parseCompressOptions(command);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      printUsage(commandName: 'compress');
      return 64;
    }

    if (rest.length == 1) {
      return _compressOne(rest.single, options);
    }

    // Batch mode
    if (options.compressionMode == CompressionMode.targetSize) {
      stderr.writeln('批量模式下不支持 --mode targetSize，请使用 --mode preset。');
      return 64;
    }

    var successCount = 0;
    var failCount = 0;
    final total = rest.length;

    for (var i = 0; i < rest.length; i++) {
      stdout.writeln('[${i + 1}/$total] ${rest[i]}');
      final code = await _compressOne(rest[i], options);
      if (code == 0) {
        successCount++;
      } else {
        failCount++;
      }
    }

    stdout.writeln('处理完成: $successCount 成功, $failCount 失败');
    return failCount > 0 ? 70 : 0;
  }

  Future<int> _compressOne(String inputPath, CliCompressOptions options) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      stderr.writeln('找不到输入文件: $inputPath');
      return 66;
    }

    stdout.writeln('FrameLean CLI');
    stdout.writeln('输入文件: ${path.absolute(inputPath)}');

    final runtime = await locator.resolve();
    final ffmpeg = runtime.ffmpeg;
    final ffprobe = runtime.ffprobe;
    if (ffmpeg == null || ffprobe == null) {
      stderr.writeln('无法找到可用的 ffmpeg / ffprobe。');
      stderr.writeln('请先安装 FFmpeg，或后续在 App 设置中指定自定义路径。');
      return 69;
    }

    stdout.writeln('ffmpeg: ${ffmpeg.path}');
    stdout.writeln('ffprobe: ${ffprobe.path}');

    MediaTask task;
    try {
      stdout.writeln('正在分析媒体信息...');
      final analysis = await analyzer.analyze(
        ffprobePath: ffprobe.path,
        inputPath: inputPath,
      );
      task = MediaTask.draft(
        inputPath: inputPath,
        fileName: path.basename(inputPath),
        mediaKind: MediaKind.video,
        sortOrder: 0,
        config: options.toVideoTaskConfig(),
      ).withAnalysisResult(analysis);
      stdout.writeln(formatAnalysis(task));
    } on Object catch (error) {
      stderr.writeln('FFprobe 分析失败: $error');
      return 65;
    }

    var allowExtremeCompression = false;
    final recommendation = compressionAdvisor.recommend(task);
    try {
      stdout.writeln(
        formatCompressionPreview(
          task: task,
          sourceSizeBytes: await inputFile.length(),
          recommendation: recommendation,
        ),
      );
    } on Object catch (error) {
      stderr.writeln('压缩预览生成失败: $error');
      return 65;
    }

    if (recommendation.shouldWarnUser) {
      stdout.writeln(recommendation.message);
      stdout.writeln('当前码率: ${formatBitrate(recommendation.bitrate)}');
      stdout.writeln(
        '低码率阈值: ${formatBitrate(recommendation.lowBitrateThreshold)}',
      );
      stdout.write('是否继续使用极限压缩策略？输入 y 继续，其他输入取消: ');
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y' && answer != 'yes') {
        stdout.writeln('已取消本次压缩，未启动 FFmpeg。');
        return 0;
      }

      allowExtremeCompression = true;
    }

    late final FfmpegCommandPlan plan;
    try {
      plan = commandBuilder.build(
        task,
        allowExtremeCompression: allowExtremeCompression,
        encoderCapabilities: runtime.encoderCapabilities,
      );
    } on Object catch (error) {
      stderr.writeln('FFmpeg 命令构造失败: $error');
      return 65;
    }
    stdout.writeln('输出文件: ${path.absolute(plan.outputPath)}');
    stdout.writeln('命令说明: ${plan.logHint}');

    final logFile = await createLogFile(task);
    stdout.writeln('原始日志: ${logFile.path}');

    try {
      stdout.writeln('开始执行 FFmpeg...');
      final startedProcess = await processStarter.start(
        ffmpegPath: ffmpeg.path,
        args: plan.args,
        logFile: logFile,
      );

      var lastPrintedPercent = -1;
      final result = await processObserver.observe(
        startedProcess: startedProcess,
        task: task.markRunning(outputPath: plan.outputPath),
        outputPath: plan.outputPath,
        onProgress: (progress) async {
          final percent = (progress * 100).floor();
          if (percent != lastPrintedPercent) {
            lastPrintedPercent = percent;
            stdout.write('\r进度: $percent%');
          }
        },
      );

      stdout.writeln();
      return printExecutionResult(result, plan.outputPath, logFile.path);
    } on Object catch (error) {
      stderr.writeln('FFmpeg 启动或执行失败: $error');
      stderr.writeln('原始日志: ${logFile.path}');
      return 70;
    }
  }

  CliCompressOptions _parseCompressOptions(ArgResults command) {
    return CliCompressOptions(
      videoCodec: parseVideoCodecOrDefault(command['codec'] as String?),
      encoderBackend: parseEncoderBackend(command['encoder-backend'] as String?),
      compressionCrf: int.parse(command['crf'] as String),
      smartPreset: parseSmartPreset(command['smart-preset'] as String),
      compressionMode: parseCompressionMode(command['mode'] as String),
      targetSizeBytes: parseSizeBytes(command['target-size'] as String?),
      outputFormat: parseOutputFormat(command['output-format'] as String),
      outputDirectory: command['output-dir'] as String? ?? '',
      resolutionPreset: parseResolutionPreset(command['resolution'] as String),
    );
  }

  // ---------------------------------------------------------------------------
  // image
  // ---------------------------------------------------------------------------

  Future<int> runImage(ArgResults command) async {
    final rest = command.rest;
    if (rest.isEmpty) {
      stderr.writeln('image 命令需要一个图片文件路径。');
      printUsage(commandName: 'image');
      return 64;
    }

    final inputPath = rest.single;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      stderr.writeln('找不到输入文件: $inputPath');
      return 66;
    }

    stdout.writeln('FrameLean CLI - 图片处理');
    stdout.writeln('输入文件: ${path.absolute(inputPath)}');

    final runtime = await locator.resolve();
    final ffmpeg = runtime.ffmpeg;
    if (ffmpeg == null) {
      stderr.writeln('无法找到可用的 ffmpeg。');
      return 69;
    }

    late final MediaOutputFormat outputFormat;
    late final int quality;
    late final bool lossless;
    late final ImageResizePreset resizePreset;
    late final String outputDirectory;
    try {
      outputFormat = parseImageOutputFormat(command['format'] as String);
      quality = int.parse(command['quality'] as String);
      lossless = command['lossless'] == true;
      resizePreset = parseImageResizePreset(command['resize'] as String);
      outputDirectory = command['output-dir'] as String? ?? '';
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      printUsage(commandName: 'image');
      return 64;
    }

    final imageConfig = ImageProcessingConfig.initial().copyWith(
      outputFormat: outputFormat,
      keepOriginalOutputFormat: false,
      imageQuality: quality,
      losslessCompression: lossless,
      resizePreset: resizePreset,
    );

    final config = MediaTaskConfig.initialImage().copyWith(
      image: imageConfig,
      outputDirectory: outputDirectory,
    );

    final task = MediaTask.draft(
      inputPath: inputPath,
      fileName: path.basename(inputPath),
      mediaKind: MediaKind.image,
      sortOrder: 0,
      config: config,
    );

    stdout.writeln('输出格式: ${outputFormat.name}');
    stdout.writeln('质量: ${lossless ? "无损" : "$quality"}');
    stdout.writeln('缩放: ${resizePreset.name}');

    late final FfmpegCommandPlan plan;
    try {
      plan = commandBuilder.build(
        task,
        encoderCapabilities: runtime.encoderCapabilities,
      );
    } on Object catch (error) {
      stderr.writeln('FFmpeg 命令构造失败: $error');
      return 65;
    }
    stdout.writeln('输出文件: ${path.absolute(plan.outputPath)}');

    final logFile = await createLogFile(task);
    stdout.writeln('原始日志: ${logFile.path}');

    try {
      stdout.writeln('开始执行 FFmpeg...');
      final startedProcess = await processStarter.start(
        ffmpegPath: ffmpeg.path,
        args: plan.args,
        logFile: logFile,
      );

      var lastPrintedPercent = -1;
      final result = await processObserver.observe(
        startedProcess: startedProcess,
        task: task.markRunning(outputPath: plan.outputPath),
        outputPath: plan.outputPath,
        onProgress: (progress) async {
          final percent = (progress * 100).floor();
          if (percent != lastPrintedPercent) {
            lastPrintedPercent = percent;
            stdout.write('\r进度: $percent%');
          }
        },
      );

      stdout.writeln();
      return printExecutionResult(result, plan.outputPath, logFile.path);
    } on Object catch (error) {
      stderr.writeln('FFmpeg 启动或执行失败: $error');
      stderr.writeln('原始日志: ${logFile.path}');
      return 70;
    }
  }

  // ---------------------------------------------------------------------------
  // audio
  // ---------------------------------------------------------------------------

  Future<int> runAudio(ArgResults command) async {
    final rest = command.rest;
    if (rest.isEmpty) {
      stderr.writeln('audio 命令需要一个音频文件路径。');
      printUsage(commandName: 'audio');
      return 64;
    }

    final inputPath = rest.single;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      stderr.writeln('找不到输入文件: $inputPath');
      return 66;
    }

    stdout.writeln('FrameLean CLI - 音频处理');
    stdout.writeln('输入文件: ${path.absolute(inputPath)}');

    final runtime = await locator.resolve();
    final ffmpeg = runtime.ffmpeg;
    if (ffmpeg == null) {
      stderr.writeln('无法找到可用的 ffmpeg。');
      return 69;
    }

    final outputFormat = parseAudioOutputFormat(command['format'] as String);
    final bitrate = parseAudioBitrate(command['bitrate'] as String);
    final sampleRate = parseAudioSampleRate(command['sample-rate'] as String);
    final channels = parseAudioChannels(command['channels'] as String);
    final outputDirectory = command['output-dir'] as String? ?? '';

    final audioConfig = AudioProcessingConfig.initial().copyWith(
      outputFormat: outputFormat,
      keepOriginalOutputFormat: false,
      bitratePreset: bitrate,
      sampleRate: sampleRate,
      channels: channels,
    );

    final config = MediaTaskConfig.initialAudio().copyWith(
      audio: audioConfig,
      outputDirectory: outputDirectory,
    );

    final task = MediaTask.draft(
      inputPath: inputPath,
      fileName: path.basename(inputPath),
      mediaKind: MediaKind.audio,
      sortOrder: 0,
      config: config,
    );

    stdout.writeln('输出格式: ${outputFormat.name}');
    stdout.writeln('码率: ${bitrate.name}');
    stdout.writeln('采样率: ${sampleRate.name}');
    stdout.writeln('声道: ${channels.name}');

    late final FfmpegCommandPlan plan;
    try {
      plan = commandBuilder.build(
        task,
        encoderCapabilities: runtime.encoderCapabilities,
      );
    } on Object catch (error) {
      stderr.writeln('FFmpeg 命令构造失败: $error');
      return 65;
    }
    stdout.writeln('输出文件: ${path.absolute(plan.outputPath)}');

    final logFile = await createLogFile(task);
    stdout.writeln('原始日志: ${logFile.path}');

    try {
      stdout.writeln('开始执行 FFmpeg...');
      final startedProcess = await processStarter.start(
        ffmpegPath: ffmpeg.path,
        args: plan.args,
        logFile: logFile,
      );

      var lastPrintedPercent = -1;
      final result = await processObserver.observe(
        startedProcess: startedProcess,
        task: task.markRunning(outputPath: plan.outputPath),
        outputPath: plan.outputPath,
        onProgress: (progress) async {
          final percent = (progress * 100).floor();
          if (percent != lastPrintedPercent) {
            lastPrintedPercent = percent;
            stdout.write('\r进度: $percent%');
          }
        },
      );

      stdout.writeln();
      return printExecutionResult(result, plan.outputPath, logFile.path);
    } on Object catch (error) {
      stderr.writeln('FFmpeg 启动或执行失败: $error');
      stderr.writeln('原始日志: ${logFile.path}');
      return 70;
    }
  }

  // ---------------------------------------------------------------------------
  // Help / usage
  // ---------------------------------------------------------------------------

  void printUsage({String? commandName}) {
    if (commandName == null) {
      stdout.writeln('FrameLean CLI — 命令行媒体处理工具');
      stdout.writeln('');
      stdout.writeln('可用命令:');
      stdout.writeln('  compress    视频压缩 / 转码');
      stdout.writeln('  image       图片格式转换 / 压缩');
      stdout.writeln('  audio       音频格式转换 / 压缩');
      stdout.writeln('');
      stdout.writeln('使用 --help 查看具体命令帮助:');
      stdout.writeln('  dart run tool/framelean_cli.dart compress --help');
      stdout.writeln('  dart run tool/framelean_cli.dart image --help');
      stdout.writeln('  dart run tool/framelean_cli.dart audio --help');
      return;
    }

    switch (commandName) {
      case 'compress':
        _printCompressUsage();
      case 'image':
        _printImageUsage();
      case 'audio':
        _printAudioUsage();
    }
  }

  void _printCompressUsage() {
    stdout.writeln('用法:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress <input> [<input2> ...] [options]',
    );
    stdout.writeln('');
    stdout.writeln('选项:');
    stdout.writeln('  -c, --codec          目标视频编码 (source|h264|h265|hevc|vp9|av1|'
        'prores|mpeg4|mjpeg)');
    stdout.writeln('  -e, --encoder-backend 编码器后端 (auto|libx264|libx265|'
        'libvpx-vp9|libsvtav1|prores-ks|native-mpeg4|native-mjpeg|'
        'videotoolbox|nvenc|qsv|amf)');
    stdout.writeln('  --crf                 CRF 质量值 (0-51)，默认 28');
    stdout.writeln('  -p, --smart-preset    智能压缩预设 (balanced|chat|clear|compact)，'
        '默认 balanced');
    stdout.writeln('  -m, --mode            压缩策略 (preset|targetSize)，默认 preset');
    stdout.writeln('  --target-size         目标输出体积 ("50MB"、"1.2GB")，仅 targetSize '
        '模式有效');
    stdout.writeln('  -f, --output-format   输出容器格式 (mp4|mov|mkv|webm|avi)，默认 mp4');
    stdout.writeln('  -o, --output-dir      输出目录，默认与源文件同目录');
    stdout.writeln('  -r, --resolution      目标分辨率 (original|2160p|1080p|720p|480p)，'
        '默认 original');
    stdout.writeln('');
    stdout.writeln('示例:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 '
      '--codec h265 --resolution 1080p',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 '
      '-c av1 -e nvenc --crf 26 -p clear -f mkv',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 '
      '-m targetSize --target-size 50MB',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress a.mp4 b.mp4 c.mp4 '
      '--codec h265 -r 1080p',
    );
  }

  void _printImageUsage() {
    stdout.writeln('用法:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart image <input> [options]',
    );
    stdout.writeln('');
    stdout.writeln('选项:');
    stdout.writeln('  -f, --format    输出格式 (jpg|png|webp|bmp|tiff|gif)，默认 jpg');
    stdout.writeln('  -q, --quality   图片质量 (1-100)，默认 80');
    stdout.writeln('  --lossless      无损压缩（仅 PNG / WebP / TIFF）');
    stdout.writeln(
      '  --resize        长边缩放 (original|longEdge3840|longEdge2560|'
      'longEdge1920|longEdge1280|longEdge720)',
    );
    stdout.writeln('  -o, --output-dir 输出目录，默认与源文件同目录');
    stdout.writeln('');
    stdout.writeln('示例:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart image ~/Pictures/photo.png '
      '--format webp --quality 90',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart image ~/Pictures/photo.png '
      '--format jpg --resize longEdge1920 -q 85',
    );
  }

  void _printAudioUsage() {
    stdout.writeln('用法:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart audio <input> [options]',
    );
    stdout.writeln('');
    stdout.writeln('选项:');
    stdout.writeln(
      '  -f, --format     输出格式 (mp3|m4a|aac|wav|flac|aiff|wma|opus|oggOpus)，'
      '默认 m4a',
    );
    stdout.writeln(
      '  -b, --bitrate    码率 (source|k320|k192|k128|k96|k64)，默认 k192',
    );
    stdout.writeln(
      '  --sample-rate    采样率 (source|hz48000|hz44100|hz32000)，默认 source',
    );
    stdout.writeln('  -c, --channels   声道 (source|stereo|mono)，默认 source');
    stdout.writeln('  -o, --output-dir 输出目录，默认与源文件同目录');
    stdout.writeln('');
    stdout.writeln('示例:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart audio ~/Music/song.wav '
      '--format mp3 --bitrate k320',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart audio ~/Music/song.flac '
      '--format m4a --bitrate k192 --channels stereo',
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers (format)
  // ---------------------------------------------------------------------------

  String formatAnalysis(MediaTask task) {
    final analysis = task.analysisResult;
    if (analysis == null) {
      return '媒体分析完成。';
    }

    final duration = analysis.durationMs == null
        ? '未知'
        : '${(analysis.durationMs! / 1000).toStringAsFixed(1)}s';
    final resolution =
        '${analysis.videoWidth ?? "?"}x${analysis.videoHeight ?? "?"}';
    final videoCodec = analysis.videoCodec ?? '未知';
    final audioCodec = analysis.audioCodec ?? '无音频或未知';

    return '媒体分析完成: 时长 $duration, 分辨率 $resolution, '
        '视频 $videoCodec, 音频 $audioCodec';
  }

  String formatCompressionPreview({
    required MediaTask task,
    required int sourceSizeBytes,
    required CompressionRecommendation recommendation,
  }) {
    final analysis = task.analysisResult;
    final sourceCodec = analysis?.videoCodec ?? '未知';
    final targetCodec = commandBuilder.resolveTargetVideoCodec(task);
    final sourceResolution = formatSourceResolution(task);
    final targetResolution = formatTargetResolution(task);

    return [
      '压缩预览:',
      '源视频编码: $sourceCodec',
      '目标视频编码: ${formatVideoCodec(targetCodec)}',
      '源视频大小: ${formatBytes(sourceSizeBytes)}',
      '源视频码率: ${formatBitrate(recommendation.bitrate)}',
      '原分辨率: $sourceResolution',
      '目标分辨率: $targetResolution',
      ...formatCompressionModePreview(recommendation),
    ].join('\n');
  }

  String formatVideoCodec(VideoCodec codec) {
    return switch (codec) {
      VideoCodec.source => '跟随源文件',
      VideoCodec.h264 => 'H.264',
      VideoCodec.hevc => 'H.265 / HEVC',
      VideoCodec.vp9 => 'VP9',
      VideoCodec.av1 => 'AV1',
      VideoCodec.proRes => 'Apple ProRes',
      VideoCodec.mpeg4 => 'MPEG-4 Part 2',
      VideoCodec.mjpeg => 'Motion JPEG',
    };
  }

  List<String> formatCompressionModePreview(
    CompressionRecommendation recommendation,
  ) {
    if (recommendation.profile == CompressionProfile.normal) {
      return ['压缩模式: 普通质量压缩 CRF ${recommendation.crf}', '预计输出大小: CRF 模式无法准确预估'];
    }

    final modeText = recommendation.profile == CompressionProfile.targetSize
        ? '指定目标体积压缩'
        : '目标码率压缩';
    return [
      '压缩模式: $modeText',
      '预计输出大小: ${formatBytesNullable(recommendation.estimatedOutputSizeBytes)}',
      '目标总码率: ${formatBitrate(recommendation.targetTotalBitrate)}',
      '目标视频码率: ${formatBitrate(recommendation.targetVideoBitrate)}',
      '目标音频码率: ${formatBitrate(recommendation.targetAudioBitrate)}',
    ];
  }

  String formatSourceResolution(MediaTask task) {
    final analysis = task.analysisResult;
    final width = analysis?.videoWidth;
    final height = analysis?.videoHeight;
    if (width == null || height == null) {
      return '未知';
    }

    return '${width}x$height';
  }

  String formatTargetResolution(MediaTask task) {
    final analysis = task.analysisResult;
    final sourceWidth = analysis?.videoWidth;
    final sourceHeight = analysis?.videoHeight;
    final targetHeight = switch (task.config.resolutionPreset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };

    if (targetHeight == null) {
      return formatSourceResolution(task);
    }

    if (sourceWidth == null || sourceHeight == null || sourceHeight <= 0) {
      return '等比缩放到 ${targetHeight}p';
    }

    final targetWidth = makeEven(
      (sourceWidth * targetHeight / sourceHeight).round(),
    );
    return '${targetWidth}x$targetHeight';
  }

  int makeEven(int value) {
    if (value.isEven) {
      return value;
    }

    return value + 1;
  }

  // ---------------------------------------------------------------------------
  // Shared helpers (log / result)
  // ---------------------------------------------------------------------------

  Future<File> createLogFile(MediaTask task) async {
    final logsDirectory = Directory(
      path.join(Directory.systemTemp.path, 'framelean', 'cli-ffmpeg-logs'),
    );
    await logsDirectory.create(recursive: true);

    final safeFileName = task.fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return File(path.join(logsDirectory.path, '$timestamp-$safeFileName.log'));
  }

  Future<int> printExecutionResult(
    FfmpegProcessObservation result,
    String outputPath,
    String logFilePath,
  ) async {
    switch (result.status) {
      case FfmpegProcessObservationStatus.completed:
        final outputFile = File(outputPath);
        final sizeBytes = await outputFile.length();
        stdout.writeln('执行结果: completed');
        stdout.writeln('输出路径: ${path.absolute(outputPath)}');
        stdout.writeln('输出大小: ${formatBytes(sizeBytes)}');
        stdout.writeln('原始日志: $logFilePath');
        return 0;
      case FfmpegProcessObservationStatus.failed:
        stderr.writeln('执行结果: failed');
        stderr.writeln('错误信息: ${result.message ?? "未知错误"}');
        stderr.writeln('原始日志: $logFilePath');
        return 70;
    }
  }

  String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 2)} '
        '${units[unitIndex]}';
  }

  String formatBytesNullable(int? bytes) {
    if (bytes == null) {
      return '未知';
    }

    return formatBytes(bytes);
  }

  String formatBitrate(int? bitrate) {
    if (bitrate == null) {
      return '未知';
    }

    return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  VideoCodec parseVideoCodecOrDefault(String? value) {
    if (value == null) {
      return AppSettings.initial().defaultOutputVideoCodec;
    }

    return switch (value) {
      'source' => VideoCodec.source,
      'h264' => VideoCodec.h264,
      'h265' => VideoCodec.hevc,
      'hevc' => VideoCodec.hevc,
      'vp9' => VideoCodec.vp9,
      'av1' => VideoCodec.av1,
      'prores' => VideoCodec.proRes,
      'mpeg4' => VideoCodec.mpeg4,
      'mjpeg' => VideoCodec.mjpeg,
      _ => throw FormatException('不支持的编码参数: $value'),
    };
  }

  EncoderBackend parseEncoderBackend(String? value) {
    if (value == null) return EncoderBackend.auto;
    return EncoderBackend.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的编码器后端: $value'),
    );
  }

  SmartCompressionPreset parseSmartPreset(String value) {
    return SmartCompressionPreset.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的智能预设: $value'),
    );
  }

  CompressionMode parseCompressionMode(String value) {
    return CompressionMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的压缩模式: $value'),
    );
  }

  OutputFormat parseOutputFormat(String value) {
    return OutputFormat.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的输出格式: $value'),
    );
  }

  ResolutionPreset parseResolutionPreset(String value) {
    return switch (value) {
      'original' => ResolutionPreset.original,
      '2160p' => ResolutionPreset.p2160,
      '1080p' => ResolutionPreset.p1080,
      '720p' => ResolutionPreset.p720,
      '480p' => ResolutionPreset.p480,
      _ => throw FormatException('不支持的分辨率参数: $value'),
    };
  }

  MediaOutputFormat parseImageOutputFormat(String value) {
    return switch (value) {
      'jpg' => MediaOutputFormat.jpg,
      'png' => MediaOutputFormat.png,
      'webp' => MediaOutputFormat.webp,
      'bmp' => MediaOutputFormat.bmp,
      'tiff' => MediaOutputFormat.tiff,
      'gif' => MediaOutputFormat.gif,
      _ => throw FormatException('不支持的图片格式: $value'),
    };
  }

  ImageResizePreset parseImageResizePreset(String value) {
    return ImageResizePreset.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的缩放预设: $value'),
    );
  }

  MediaOutputFormat parseAudioOutputFormat(String value) {
    return switch (value) {
      'mp3' => MediaOutputFormat.mp3,
      'm4a' => MediaOutputFormat.m4a,
      'aac' => MediaOutputFormat.aac,
      'wav' => MediaOutputFormat.wav,
      'flac' => MediaOutputFormat.flac,
      'aiff' => MediaOutputFormat.aiff,
      'wma' => MediaOutputFormat.wma,
      'opus' => MediaOutputFormat.opus,
      'oggOpus' => MediaOutputFormat.oggOpus,
      _ => throw FormatException('不支持的音频格式: $value'),
    };
  }

  AudioBitratePreset parseAudioBitrate(String value) {
    return AudioBitratePreset.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的音频码率: $value'),
    );
  }

  AudioSampleRatePreset parseAudioSampleRate(String value) {
    return AudioSampleRatePreset.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的采样率: $value'),
    );
  }

  AudioChannelsPreset parseAudioChannels(String value) {
    return AudioChannelsPreset.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('不支持的声道参数: $value'),
    );
  }

  int? parseSizeBytes(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(r'^([\d.]+)\s*(kb|mb|gb|b)?$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) throw FormatException('无法解析体积: $value');
    final num = double.parse(match.group(1)!);
    final unit = (match.group(2) ?? 'b').toLowerCase();
    return switch (unit) {
      'gb' => (num * 1024 * 1024 * 1024).round(),
      'mb' => (num * 1024 * 1024).round(),
      'kb' => (num * 1024).round(),
      _ => num.round(),
    };
  }
}

// ---------------------------------------------------------------------------
// CLI options model
// ---------------------------------------------------------------------------

class CliCompressOptions {
  final VideoCodec videoCodec;
  final EncoderBackend encoderBackend;
  final int compressionCrf;
  final SmartCompressionPreset smartPreset;
  final CompressionMode compressionMode;
  final int? targetSizeBytes;
  final OutputFormat outputFormat;
  final String outputDirectory;
  final ResolutionPreset resolutionPreset;

  const CliCompressOptions({
    required this.videoCodec,
    required this.encoderBackend,
    required this.compressionCrf,
    required this.smartPreset,
    required this.compressionMode,
    required this.targetSizeBytes,
    required this.outputFormat,
    required this.outputDirectory,
    required this.resolutionPreset,
  });

  VideoTaskConfig toVideoTaskConfig() {
    return VideoTaskConfig.initial().copyWith(
      videoCodec: videoCodec,
      encoderBackend: encoderBackend,
      compressionCrf: compressionCrf,
      smartPreset: smartPreset,
      compressionMode: compressionMode,
      targetSizeBytes: targetSizeBytes,
      outputFormat: outputFormat,
      outputDirectory: outputDirectory,
      resolutionPreset: resolutionPreset,
    );
  }
}
