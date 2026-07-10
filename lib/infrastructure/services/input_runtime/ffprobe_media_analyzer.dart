import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

/// 使用 FFprobe 分析媒体文件基础信息
class FfprobeMediaAnalyzer implements MediaAnalyzer {
  final Duration timeout;

  FfprobeMediaAnalyzer({this.timeout = ffprobeAnalysisTimeout});

  @override
  Future<MediaAnalysisResult> analyze({
    required String ffprobePath,
    required String inputPath,
  }) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw StateError('源文件不存在: $inputPath');
    }

    // 改用 Process.start 而非 Process.run，以便在超时后能主动 kill 子进程。
    // 原实现用 Process.run(...).timeout(timeout)，但 .timeout() 只会取消
    // Future 的等待，不会终止底层 ffprobe 进程；遇到损坏文件或网络盘卡住时，
    // ffprobe 会在后台长期存活，批量分析时累积成僵尸进程泄漏。
    final process = await Process.start(ffprobePath, buildArguments(inputPath));

    final stdoutBuffer = <int>[];
    final stderrBuffer = <int>[];
    final stdoutDone = process.stdout
        .listen(stdoutBuffer.addAll)
        .asFuture<void>();
    final stderrDone = process.stderr
        .listen(stderrBuffer.addAll)
        .asFuture<void>();

    try {
      final exitCode = await process.exitCode.timeout(timeout);
      await Future.wait([stdoutDone, stderrDone]);

      final stderrText = utf8.decode(stderrBuffer);
      if (exitCode != 0) {
        throw StateError('FFprobe 分析失败: $stderrText');
      }

      final json = jsonDecode(utf8.decode(stdoutBuffer));
      if (json is! Map<String, dynamic>) {
        throw StateError('FFprobe 输出格式无效');
      }

      final fileSize = await file.length();

      return parseResult(json, fileSize: fileSize);
    } on TimeoutException {
      // 关键修复：超时后必须主动终止子进程并回收退出码，
      // 否则 ffprobe 进程句柄会残留，长时间运行下持续泄漏。
      await _terminateProcess(process, stdoutDone, stderrDone);
      throw TimeoutException(
        'FFprobe 分析超时（${timeout.inSeconds} 秒）: $inputPath',
        timeout,
      );
    }
  }

  /// 强制终止子进程并等待其退出与流关闭，避免僵尸进程或句柄残留。
  Future<void> _terminateProcess(
    Process process,
    Future<void> stdoutDone,
    Future<void> stderrDone,
  ) async {
    try {
      process.kill(ProcessSignal.sigkill);
    } on Object {
      // kill 失败也不阻断清理，继续等待 exitCode 兜底。
    }
    // 等待进程真正退出与流关闭；这里再加一个较短超时做最终兜底，
    // 防止极端情况下 kill 本身也卡住导致整个分析链路被拖死。
    await Future.wait<void>([
      process.exitCode,
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(seconds: 2), onTimeout: () => const []);
  }

  List<String> buildArguments(String inputPath) {
    return [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_entries',
      'format=duration,bit_rate,format_name:'
          'stream=index,codec_type,codec_name,width,height,bit_rate,duration,'
          'pix_fmt,bits_per_raw_sample,color_range,color_space,'
          'color_transfer,color_primaries,avg_frame_rate,r_frame_rate,'
          'sample_aspect_ratio,display_aspect_ratio,field_order,'
          'chroma_location,'
          'channels,channel_layout,sample_rate:'
          'stream_tags=rotate,language,title:'
          'stream_side_data=side_data_type,rotation,'
          'red_x,red_y,green_x,green_y,blue_x,blue_y,'
          'white_point_x,white_point_y,min_luminance,max_luminance,'
          'max_content,max_average,dv_profile,'
          'dv_bl_signal_compatibility_id',
      inputPath,
    ];
  }

  MediaAnalysisResult parseResult(Map<String, dynamic> json, {int? fileSize}) {
    final streams = json['streams'];
    final format = json['format'];

    if (streams is! List) {
      throw StateError('FFprobe 输出缺少 streams');
    }

    final videoStream = findStream(streams, 'video');
    final audioStream = findUsableAudioStream(streams);
    final audioStreams = findUsableAudioStreams(
      streams,
    ).map(parseAudioStreamInfo).toList(growable: false);

    if (videoStream == null && audioStream == null) {
      throw StateError('媒体文件没有可用媒体流');
    }

    final durationMs = parseDurationMs(format, videoStream, audioStream);
    final videoBitDepth = videoStream == null
        ? null
        : parseVideoBitDepth(videoStream);
    final rotationDegrees = videoStream == null
        ? null
        : parseVideoRotationDegrees(videoStream);
    final sideDataList = videoStream == null
        ? const <Map<String, dynamic>>[]
        : parseSideDataList(videoStream);
    final masteringDisplayMetadata = parseMasteringDisplayMetadata(
      sideDataList,
    );

    return MediaAnalysisResult(
      durationMs: durationMs,
      videoWidth: parseInt(videoStream?['width']),
      videoHeight: parseInt(videoStream?['height']),
      videoCodec: parseString(videoStream?['codec_name']),
      audioCodec: parseString(audioStream?['codec_name']),
      videoPixelFormat: parseString(videoStream?['pix_fmt']),
      videoBitDepth: videoBitDepth,
      colorRange: parseString(videoStream?['color_range']),
      colorSpace: parseString(videoStream?['color_space']),
      colorTransfer: parseString(videoStream?['color_transfer']),
      colorPrimaries: parseString(videoStream?['color_primaries']),
      chromaLocation: parseString(videoStream?['chroma_location']),
      masteringDisplayMetadata: masteringDisplayMetadata,
      masteringDisplayMaxLuminance: parseMasteringDisplayMaxLuminance(
        sideDataList,
      ),
      maxContentLightLevel: parseContentLightValue(sideDataList, 'max_content'),
      maxFrameAverageLightLevel: parseContentLightValue(
        sideDataList,
        'max_average',
      ),
      dolbyVisionProfile: parseDolbyVisionValue(sideDataList, 'dv_profile'),
      dolbyVisionCompatibilityId: parseDolbyVisionValue(
        sideDataList,
        'dv_bl_signal_compatibility_id',
      ),
      averageFrameRate: parseString(videoStream?['avg_frame_rate']),
      realFrameRate: parseString(videoStream?['r_frame_rate']),
      sampleAspectRatio: parseString(videoStream?['sample_aspect_ratio']),
      displayAspectRatio: parseString(videoStream?['display_aspect_ratio']),
      videoRotationDegrees: rotationDegrees,
      fieldOrder: parseString(videoStream?['field_order']),
      videoBitrate: parseInt(videoStream?['bit_rate']),
      audioBitrate: parseInt(audioStream?['bit_rate']),
      containerBitrate: format is Map<String, dynamic>
          ? parseInt(format['bit_rate'])
          : null,
      estimatedBitrate: estimateBitrate(
        fileSize: fileSize,
        durationMs: durationMs,
      ),
      containerFormat: format is Map<String, dynamic>
          ? parseString(format['format_name'])
          : null,
      audioChannels: parseInt(audioStream?['channels']),
      audioSampleRate: parseInt(audioStream?['sample_rate']),
      audioChannelLayout: parseString(audioStream?['channel_layout']),
      audioStreamIndex: parseInt(audioStream?['index']),
      audioStreams: audioStreams,
      imageWidth: parseInt(videoStream?['width']),
      imageHeight: parseInt(videoStream?['height']),
      imageCodec: parseString(videoStream?['codec_name']),
      imagePixelFormat: parseString(videoStream?['pix_fmt']),
      imageBitDepth: videoBitDepth,
      orientationDegrees: rotationDegrees,
    );
  }

  Map<String, dynamic>? findStream(List<dynamic> streams, String codecType) {
    for (final stream in streams) {
      if (stream is Map<String, dynamic> && stream['codec_type'] == codecType) {
        return stream;
      }
    }

    return null;
  }

  Map<String, dynamic>? findUsableAudioStream(List<dynamic> streams) {
    for (final stream in findUsableAudioStreams(streams)) {
      return stream;
    }

    return null;
  }

  List<Map<String, dynamic>> findUsableAudioStreams(List<dynamic> streams) {
    final audioStreams = <Map<String, dynamic>>[];
    for (final stream in streams) {
      if (stream is! Map<String, dynamic> || stream['codec_type'] != 'audio') {
        continue;
      }

      if (MediaCodecNormalizer.isUsableAudioForTranscode(
        parseString(stream['codec_name']),
      )) {
        audioStreams.add(stream);
      }
    }

    return audioStreams;
  }

  MediaAudioStreamInfo parseAudioStreamInfo(Map<String, dynamic> stream) {
    final tags = stream['tags'];
    final tagMap = tags is Map<String, dynamic> ? tags : const {};
    return MediaAudioStreamInfo(
      index: parseInt(stream['index']) ?? 0,
      codec: parseString(stream['codec_name']),
      channels: parseInt(stream['channels']),
      sampleRate: parseInt(stream['sample_rate']),
      channelLayout: parseString(stream['channel_layout']),
      language: parseString(tagMap['language']),
      title: parseString(tagMap['title']),
    );
  }

  int? parseDurationMs(
    Object? format,
    Map<String, dynamic>? videoStream,
    Map<String, dynamic>? audioStream,
  ) {
    if (format is Map<String, dynamic>) {
      final duration = parseDouble(format['duration']);
      if (duration != null) {
        return (duration * 1000).round();
      }
    }

    final streamDuration =
        parseDouble(videoStream?['duration']) ??
        parseDouble(audioStream?['duration']);
    if (streamDuration == null) {
      return null;
    }

    return (streamDuration * 1000).round();
  }

  int? estimateBitrate({required int? fileSize, required int? durationMs}) {
    if (fileSize == null || fileSize <= 0) {
      return null;
    }

    if (durationMs == null || durationMs <= 0) {
      return null;
    }

    final durationSeconds = durationMs / 1000;
    return (fileSize * 8 / durationSeconds).round();
  }

  int? parseInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  double? parseDouble(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String? parseString(Object? value) {
    if (value == null) {
      return null;
    }

    final text = value.toString();
    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  int? parseVideoBitDepth(Map<String, dynamic> videoStream) {
    final directValue = parseInt(videoStream['bits_per_raw_sample']);
    if (directValue != null && directValue > 0) {
      return directValue;
    }

    final pixelFormat = parseString(videoStream['pix_fmt'])?.toLowerCase();
    if (pixelFormat == null || pixelFormat.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d+)(?:le|be)?$').firstMatch(pixelFormat);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    return 8;
  }

  int? parseVideoRotationDegrees(Map<String, dynamic> videoStream) {
    final tags = videoStream['tags'];
    if (tags is Map<String, dynamic>) {
      final tagRotation = parseDouble(tags['rotate']);
      if (tagRotation != null) {
        return tagRotation.round();
      }
    }

    final sideDataList = videoStream['side_data_list'];
    if (sideDataList is List) {
      for (final sideData in sideDataList) {
        if (sideData is! Map<String, dynamic>) {
          continue;
        }

        final rotation = parseDouble(sideData['rotation']);
        if (rotation != null) {
          return rotation.round();
        }
      }
    }

    return null;
  }

  List<Map<String, dynamic>> parseSideDataList(
    Map<String, dynamic> videoStream,
  ) {
    final sideDataList = videoStream['side_data_list'];
    if (sideDataList is! List) {
      return const [];
    }

    return sideDataList.whereType<Map<String, dynamic>>().toList();
  }

  String? parseMasteringDisplayMetadata(
    List<Map<String, dynamic>> sideDataList,
  ) {
    final sideData = findSideData(sideDataList, 'mastering display');
    if (sideData == null) {
      return null;
    }

    final fields = [
      'red_x',
      'red_y',
      'green_x',
      'green_y',
      'blue_x',
      'blue_y',
      'white_point_x',
      'white_point_y',
      'min_luminance',
      'max_luminance',
    ];
    final parts = <String>[];
    for (final field in fields) {
      final value = parseString(sideData[field]);
      if (value != null) {
        parts.add('$field=$value');
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(',');
  }

  double? parseMasteringDisplayMaxLuminance(
    List<Map<String, dynamic>> sideDataList,
  ) {
    final sideData = findSideData(sideDataList, 'mastering display');
    if (sideData == null) {
      return null;
    }

    return parseRationalDouble(sideData['max_luminance']);
  }

  int? parseContentLightValue(
    List<Map<String, dynamic>> sideDataList,
    String key,
  ) {
    final sideData = findSideData(sideDataList, 'content light');
    if (sideData == null) {
      return null;
    }

    return parseInt(sideData[key]);
  }

  int? parseDolbyVisionValue(
    List<Map<String, dynamic>> sideDataList,
    String key,
  ) {
    final sideData =
        findSideData(sideDataList, 'dovi configuration') ??
        findSideData(sideDataList, 'dolby vision');
    if (sideData == null) {
      return null;
    }

    return parseInt(sideData[key]);
  }

  Map<String, dynamic>? findSideData(
    List<Map<String, dynamic>> sideDataList,
    String typeNeedle,
  ) {
    final needle = typeNeedle.toLowerCase();
    for (final sideData in sideDataList) {
      final type = parseString(sideData['side_data_type'])?.toLowerCase();
      if (type != null && type.contains(needle)) {
        return sideData;
      }
    }

    return null;
  }

  double? parseRationalDouble(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    final text = value.toString();
    final parts = text.split('/');
    if (parts.length == 2) {
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator != null && denominator != null && denominator != 0) {
        return numerator / denominator;
      }
    }

    return double.tryParse(text);
  }
}
