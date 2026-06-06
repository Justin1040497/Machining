import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/infrastructure/services/input_runtime/standard_cli_proprietary_audio_decoder.dart';
import 'package:path/path.dart' as path;

void main() {
  group('StandardCliProprietaryAudioDecoder', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'framelean-decoder-test-',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('returns the generated decoded audio file', () async {
      final calls = <List<String>>[];
      final decoder = StandardCliProprietaryAudioDecoder(
        processRunner: (executable, args) async {
          calls.add([executable, ...args]);
          final outputDir = args[args.indexOf('-o') + 1];
          File(path.join(outputDir, 'song.flac')).writeAsStringSync('decoded');
          return ProcessResult(1, 0, 'ok', '');
        },
      );

      final result = await decoder.decode(
        runtime: const ProprietaryAudioAdapterRuntime(
          format: ProprietaryAudioFormat.ncm,
          adapterName: 'ncmdump',
          adapterVersion: 'fake 1.0',
          executablePath: '/adapters/ncmdump',
        ),
        inputPath: '/music/song.ncm',
        temporaryDirectory: tempDirectory.path,
      );

      expect(result.decodedPath, path.join(tempDirectory.path, 'song.flac'));
      expect(result.decodedExtension, '.flac');
      expect(result.cleanupPaths, [tempDirectory.path]);
      expect(calls.single, [
        '/adapters/ncmdump',
        '/music/song.ncm',
        '-o',
        tempDirectory.path,
      ]);
    });

    test('throws a readable error when adapter fails', () async {
      final decoder = StandardCliProprietaryAudioDecoder(
        processRunner: (_, _) async {
          return ProcessResult(1, 2, '', 'adapter failed');
        },
      );

      expect(
        () => decoder.decode(
          runtime: const ProprietaryAudioAdapterRuntime(
            format: ProprietaryAudioFormat.ncm,
            adapterName: 'ncmdump',
            adapterVersion: 'fake 1.0',
            executablePath: '/adapters/ncmdump',
          ),
          inputPath: '/music/song.ncm',
          temporaryDirectory: tempDirectory.path,
        ),
        throwsA(isA<ProprietaryAudioDecodeException>()),
      );
    });
  });
}
