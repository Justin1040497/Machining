import 'dart:io';
import 'dart:typed_data';

import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_container_parser.dart';
import 'package:path/path.dart' as path;

class NativeNcmAudioDecoder implements ProprietaryAudioDecoder {
  static const chunkSize = 0x8000;

  final NcmContainerParser parser;

  const NativeNcmAudioDecoder({this.parser = const NcmContainerParser()});

  @override
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  }) async {
    if (runtime.format != ProprietaryAudioFormat.ncm) {
      throw ProprietaryAudioDecodeException(
        'NCM 原生解码器不支持 ${runtime.format.displayName}',
      );
    }

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw ProprietaryAudioDecodeException('NCM 解析失败: 源文件不存在 $inputPath');
    }

    final outputDirectory = Directory(temporaryDirectory);
    await outputDirectory.create(recursive: true);

    final input = await inputFile.open();
    File? outputFile;
    RandomAccessFile? output;
    try {
      final container = await parser.parse(input);
      await input.setPosition(container.audioDataOffset);

      final firstChunk = await input.read(chunkSize);
      if (firstChunk.isEmpty) {
        throw const ProprietaryAudioDecodeException('NCM 解析失败: 音频数据为空');
      }
      container.keyBox.transformAudioChunk(firstChunk);

      final decodedExtension = _decodedExtensionForHeader(firstChunk);
      if (decodedExtension == null) {
        throw const ProprietaryAudioDecodeException('NCM 解析失败: 解包后的音频格式无法识别');
      }

      final outputPath = path.join(
        outputDirectory.path,
        '${path.basenameWithoutExtension(inputPath)}$decodedExtension',
      );
      outputFile = File(outputPath);
      output = await outputFile.open(mode: FileMode.write);
      await output.writeFrom(firstChunk);

      while (true) {
        final chunk = await input.read(chunkSize);
        if (chunk.isEmpty) {
          break;
        }

        container.keyBox.transformAudioChunk(chunk);
        await output.writeFrom(chunk);
      }

      await output.close();
      output = null;

      if (await outputFile.length() == 0) {
        throw const ProprietaryAudioDecodeException('NCM 解析失败: 输出音频为空');
      }

      return ProprietaryAudioDecodeResult(
        decodedPath: outputFile.path,
        decodedExtension: decodedExtension,
        adapterName: runtime.adapterName,
        adapterVersion: runtime.adapterVersion,
        temporary: true,
        cleanupPaths: [outputDirectory.path],
      );
    } on ProprietaryAudioDecodeException {
      await _deletePartialOutput(outputFile);
      rethrow;
    } on Object catch (error) {
      await _deletePartialOutput(outputFile);
      throw ProprietaryAudioDecodeException('NCM 解析失败: $error');
    } finally {
      await output?.close();
      await input.close();
    }
  }

  String? _decodedExtensionForHeader(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x66 &&
        bytes[1] == 0x4c &&
        bytes[2] == 0x61 &&
        bytes[3] == 0x43) {
      return '.flac';
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return '.mp3';
    }

    if (bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0) {
      return '.mp3';
    }

    return null;
  }

  Future<void> _deletePartialOutput(File? outputFile) async {
    if (outputFile == null) {
      return;
    }

    try {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
    } on Object {
      // 失败路径的临时文件清理是尽力而为，保留原始错误更有价值。
    }
  }
}
