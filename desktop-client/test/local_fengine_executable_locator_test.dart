import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/services/engine/local_fengine_executable_locator.dart';
import 'package:path/path.dart' as path;

void main() {
  group('LocalFEngineExecutableLocator', () {
    test('uses an existing explicit engine override', () async {
      final checked = <String>[];
      final expected = path.normalize(
        path.absolute('/opt/framelean/framelean-engine'),
      );
      final locator = LocalFEngineExecutableLocator(
        operatingSystem: 'macos',
        resolvedExecutable: '/Applications/FrameLean.app/Contents/MacOS/app',
        currentDirectory: '/workspace/desktop-client',
        environment: const <String, String>{
          'FRAMELEAN_ENGINE_PATH': ' /opt/framelean/framelean-engine ',
        },
        fileExists: (candidate) async {
          checked.add(candidate);
          return candidate == expected;
        },
      );

      expect(await locator.resolve(), expected);
      expect(checked, <String>[expected]);
    });

    test('does not fall back when an explicit override is missing', () async {
      final checked = <String>[];
      final locator = LocalFEngineExecutableLocator(
        operatingSystem: 'macos',
        resolvedExecutable: '/Applications/FrameLean.app/Contents/MacOS/app',
        currentDirectory: '/workspace/desktop-client',
        environment: const <String, String>{
          'FRAMELEAN_ENGINE_PATH': '/missing/framelean-engine',
        },
        fileExists: (candidate) async {
          checked.add(candidate);
          return false;
        },
      );

      await expectLater(
        locator.resolve(),
        throwsA(isA<FEngineExecutableNotFoundException>()),
      );
      expect(checked, hasLength(1));
    });

    test('finds the engine in a macOS application Resources directory', () async {
      final checked = <String>[];
      final expected = path.normalize(
        path.absolute(
          '/Applications/FrameLean.app/Contents/Resources/framelean-engine',
        ),
      );
      final locator = LocalFEngineExecutableLocator(
        operatingSystem: 'macos',
        resolvedExecutable:
            '/Applications/FrameLean.app/Contents/MacOS/FrameLean',
        currentDirectory: '/workspace/desktop-client',
        environment: const <String, String>{},
        fileExists: (candidate) async {
          checked.add(candidate);
          return candidate == expected;
        },
      );

      expect(await locator.resolve(), expected);
      expect(
        checked,
        containsAllInOrder(<String>[
          path.normalize(
            path.absolute(
              '/Applications/FrameLean.app/Contents/MacOS/framelean-engine',
            ),
          ),
          path.normalize(
            path.absolute(
              '/Applications/FrameLean.app/Contents/MacOS/fengine/framelean-engine',
            ),
          ),
          expected,
        ]),
      );
    });

    test('uses the Windows executable name', () async {
      final checked = <String>[];
      final expected = path.normalize(
        path.absolute('/app/framelean-engine.exe'),
      );
      final locator = LocalFEngineExecutableLocator(
        operatingSystem: 'windows',
        resolvedExecutable: '/app/framelean.exe',
        currentDirectory: '/workspace/desktop-client',
        environment: const <String, String>{},
        fileExists: (candidate) async {
          checked.add(candidate);
          return candidate == expected;
        },
      );

      expect(await locator.resolve(), expected);
      expect(checked.first, expected);
    });
  });
}
