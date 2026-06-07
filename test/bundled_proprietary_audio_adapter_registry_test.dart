import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/infrastructure/services/input_runtime/bundled_proprietary_audio_adapter_registry.dart';
import 'package:path/path.dart' as path;

void main() {
  group('BundledProprietaryAudioAdapterRegistry', () {
    test(
      'returns builtin runtime for ncm without probing external binaries',
      () async {
        final processCalls = <List<String>>[];
        final registry = BundledProprietaryAudioAdapterRegistry(
          processRunner: (executable, args) async {
            processCalls.add([executable, ...args]);
            return ProcessResult(1, 1, '', 'should not be called');
          },
        );

        final runtime = await registry.resolveRuntime(
          ProprietaryAudioFormat.ncm,
        );

        expect(runtime.adapterName, 'native-ncm-dart');
        expect(runtime.adapterVersion, 'builtin');
        expect(runtime.executablePath, isEmpty);
        expect(processCalls, isEmpty);
      },
    );

    test('resolves qmc adapter from candidate executable', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'framelean-qmc-registry-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final executablePath = path.join(
        tempDirectory.path,
        Platform.isWindows
            ? 'framelean-qmc-adapter.exe'
            : 'framelean-qmc-adapter',
      );
      File(executablePath).writeAsStringSync('adapter');
      final processCalls = <List<String>>[];
      final registry = BundledProprietaryAudioAdapterRegistry(
        candidateBuilder: (_) => [executablePath],
        processRunner: (executable, args) async {
          processCalls.add([executable, ...args]);
          return ProcessResult(1, 0, 'framelean-qmc-adapter 1.0', '');
        },
      );

      final runtime = await registry.resolveRuntime(
        ProprietaryAudioFormat.qmcMflac,
      );

      expect(runtime.adapterName, 'framelean-qmc-adapter');
      expect(runtime.adapterVersion, 'framelean-qmc-adapter 1.0');
      expect(runtime.executablePath, executablePath);
      expect(processCalls.single, [executablePath, '--version']);
    });

    test('accepts qmc-decrypt as direct open source runtime', () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'framelean-qmc-decrypt-registry-test-',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final executablePath = path.join(
        tempDirectory.path,
        Platform.isWindows ? 'qmc-decrypt.exe' : 'qmc-decrypt',
      );
      File(executablePath).writeAsStringSync('adapter');
      final processCalls = <List<String>>[];
      final registry = BundledProprietaryAudioAdapterRegistry(
        candidateBuilder: (_) => [executablePath],
        processRunner: (executable, args) async {
          processCalls.add([executable, ...args]);
          return ProcessResult(
            1,
            0,
            'Usage: qmc-decrypt <input> <output> [ekey]',
            '',
          );
        },
      );

      final runtime = await registry.resolveRuntime(
        ProprietaryAudioFormat.qmcMflac,
      );

      expect(runtime.adapterName, 'qmc-decrypt');
      expect(runtime.adapterVersion, 'qmc-decrypt (version unavailable)');
      expect(runtime.executablePath, executablePath);
      expect(processCalls.single, [executablePath, '--help']);
    });
  });
}
