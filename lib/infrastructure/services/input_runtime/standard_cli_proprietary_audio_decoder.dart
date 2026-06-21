import 'dart:async';
import 'dart:io';

import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';
import 'package:path/path.dart' as path;
import 'package:framelean/app/constants.dart';

class StandardCliProprietaryAudioDecoder implements ProprietaryAudioDecoder {
  static const supportedDecodedExtensions = {
    '.mp3',
    '.flac',
    '.ogg',
    '.oga',
    '.m4a',
    '.aac',
    '.wav',
  };

  final Duration timeout;
  final Future<ProcessResult> Function(String executable, List<String> args)?
  processRunner;

  const StandardCliProprietaryAudioDecoder({
    this.timeout = audioDecoderTimeout,
    this.processRunner,
  });

  @override
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  }) async {
    final outputDirectory = Directory(temporaryDirectory);
    await outputDirectory.create(recursive: true);

    final args = buildAdapterArgs(
      runtime: runtime,
      inputPath: inputPath,
      outputDirectory: outputDirectory.path,
    );

    final result = await runProcess(
      runtime.executablePath,
      args,
    ).timeout(timeout);
    if (result.exitCode != 0) {
      throw ProprietaryAudioDecodeException(
        '专有音频适配失败: ${stderrSummary(result.stderr)}',
      );
    }

    final decodedFile = await findDecodedAudioFile(outputDirectory);
    if (decodedFile == null) {
      throw const ProprietaryAudioDecodeException('专有音频适配失败: 适配器没有生成标准音频文件');
    }

    return ProprietaryAudioDecodeResult(
      decodedPath: decodedFile.path,
      decodedExtension: path.extension(decodedFile.path).toLowerCase(),
      adapterName: runtime.adapterName,
      adapterVersion: runtime.adapterVersion,
      temporary: true,
      cleanupPaths: [outputDirectory.path],
    );
  }

  Future<ProcessResult> runProcess(String executable, List<String> args) {
    final runner = processRunner;
    if (runner != null) {
      return runner(executable, args);
    }

    return Process.run(executable, args, runInShell: Platform.isWindows);
  }

  List<String> buildAdapterArgs({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String outputDirectory,
  }) {
    if (runtime.adapterName == 'qmc-decrypt') {
      return [inputPath, outputDirectory];
    }

    return [
      '--input',
      inputPath,
      '--output-dir',
      outputDirectory,
      '--format',
      runtime.format.name,
    ];
  }

  Future<File?> findDecodedAudioFile(Directory outputDirectory) async {
    if (!await outputDirectory.exists()) {
      return null;
    }

    final files = <File>[];
    await for (final entity in outputDirectory.list()) {
      if (entity is! File) {
        continue;
      }

      final extension = path.extension(entity.path).toLowerCase();
      if (supportedDecodedExtensions.contains(extension) &&
          await entity.length() > 0) {
        files.add(entity);
      }
    }

    if (files.isEmpty) {
      return null;
    }

    files.sort((first, second) => first.path.compareTo(second.path));
    return files.first;
  }

  String stderrSummary(Object? stderr) {
    final text = stderr?.toString().trim() ?? '';
    if (text.isEmpty) {
      return '未知错误';
    }

    const maxLength = 240;
    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }
}
