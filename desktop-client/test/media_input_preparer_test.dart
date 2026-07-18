import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/input_runtime/media_input_preparer.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_format_resolver.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';
import 'package:framelean/infrastructure/services/input_runtime/default_media_input_preparer.dart';
import 'package:path/path.dart' as path;

void main() {
  group('DefaultMediaInputPreparer', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'framelean-input-preparer-test-',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('keeps ordinary audio task unchanged', () async {
      final task = audioTask(inputPath: '/music/source.mp3');
      final preparer = DefaultMediaInputPreparer(
        proprietaryAudioFormatResolver: const FakeFormatResolver(null),
        proprietaryAudioAdapterRegistry: FakeAdapterRegistry(),
        proprietaryAudioDecoder: FakeDecoder(
          decodedPath: path.join(tempDirectory.path, 'source.mp3'),
        ),
        temporaryDirectoryFactory: (_, _) async => tempDirectory,
      );

      final prepared = await preparer.prepare(
        task,
        purpose: MediaInputPreparationPurpose.analysis,
      );

      expect(prepared.task.inputPath, task.inputPath);
      expect(prepared.usesTemporaryInput, isFalse);
    });

    test('uses decoded audio path for analysis', () async {
      final decodedPath = path.join(tempDirectory.path, 'source.flac');
      final task = audioTask(inputPath: '/music/source.ncm');
      final decoder = FakeDecoder(decodedPath: decodedPath);
      final preparer = DefaultMediaInputPreparer(
        proprietaryAudioFormatResolver: const FakeFormatResolver(
          ProprietaryAudioFormat.ncm,
        ),
        proprietaryAudioAdapterRegistry: FakeAdapterRegistry(),
        proprietaryAudioDecoder: decoder,
        temporaryDirectoryFactory: (_, _) async => tempDirectory,
      );

      final prepared = await preparer.prepare(
        task,
        purpose: MediaInputPreparationPurpose.analysis,
      );

      expect(prepared.task.inputPath, decodedPath);
      expect(prepared.task.config.outputDirectory, isEmpty);
      expect(decoder.inputPaths, ['/music/source.ncm']);
      expect(decoder.temporaryDirectories, [tempDirectory.path]);
    });

    test(
      'keeps execution output beside the original source by default',
      () async {
        final decodedPath = path.join(tempDirectory.path, 'source.flac');
        final task = audioTask(inputPath: '/music/source.ncm');
        final preparer = DefaultMediaInputPreparer(
          proprietaryAudioFormatResolver: const FakeFormatResolver(
            ProprietaryAudioFormat.ncm,
          ),
          proprietaryAudioAdapterRegistry: FakeAdapterRegistry(),
          proprietaryAudioDecoder: FakeDecoder(decodedPath: decodedPath),
          temporaryDirectoryFactory: (_, _) async => tempDirectory,
        );

        final prepared = await preparer.prepare(
          task,
          purpose: MediaInputPreparationPurpose.execution,
        );

        expect(prepared.task.inputPath, decodedPath);
        expect(prepared.task.fileName, 'source.ncm');
        expect(prepared.task.config.outputDirectory, '/music');
      },
    );

    test('cleanup removes decoded temporary directory', () async {
      final decodedPath = path.join(tempDirectory.path, 'source.flac');
      File(decodedPath).writeAsStringSync('decoded');
      final preparer = DefaultMediaInputPreparer(
        proprietaryAudioFormatResolver: const FakeFormatResolver(
          ProprietaryAudioFormat.ncm,
        ),
        proprietaryAudioAdapterRegistry: FakeAdapterRegistry(),
        proprietaryAudioDecoder: FakeDecoder(decodedPath: decodedPath),
        temporaryDirectoryFactory: (_, _) async => tempDirectory,
      );
      final prepared = await preparer.prepare(
        audioTask(inputPath: '/music/source.ncm'),
        purpose: MediaInputPreparationPurpose.analysis,
      );

      await preparer.cleanup(prepared);

      expect(await tempDirectory.exists(), isFalse);
    });
  });
}

MediaTask audioTask({required String inputPath}) {
  return MediaTask.draft(
    inputPath: inputPath,
    fileName: path.basename(inputPath),
    mediaKind: MediaKind.audio,
    sortOrder: 0,
  ).copyWith(id: 'audio-task');
}

class FakeFormatResolver implements ProprietaryAudioFormatResolver {
  final ProprietaryAudioFormat? format;

  const FakeFormatResolver(this.format);

  @override
  ProprietaryAudioFormat? resolve(String inputPath) {
    return format;
  }
}

class FakeAdapterRegistry implements ProprietaryAudioAdapterRegistry {
  @override
  Future<ProprietaryAudioAdapterRuntime> resolveRuntime(
    ProprietaryAudioFormat format,
  ) async {
    return ProprietaryAudioAdapterRuntime(
      format: format,
      adapterName: 'fake-adapter',
      adapterVersion: 'fake 1.0',
      executablePath: '/adapters/fake',
    );
  }
}

class FakeDecoder implements ProprietaryAudioDecoder {
  final String decodedPath;
  final List<String> inputPaths = [];
  final List<String> temporaryDirectories = [];

  FakeDecoder({required this.decodedPath});

  @override
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  }) async {
    inputPaths.add(inputPath);
    temporaryDirectories.add(temporaryDirectory);
    return ProprietaryAudioDecodeResult(
      decodedPath: decodedPath,
      decodedExtension: path.extension(decodedPath),
      adapterName: runtime.adapterName,
      adapterVersion: runtime.adapterVersion,
      cleanupPaths: [temporaryDirectory],
    );
  }
}
