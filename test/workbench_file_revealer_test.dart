import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_file_revealer.dart';
import 'package:path/path.dart' as path;

void main() {
  group('WorkbenchFileRevealer', () {
    test('builds Windows select command with path as separate argument', () {
      const targetPath = r'C:\Users\left\Videos\第二节课 实操.mp4';

      final command = WorkbenchFileRevealer.buildRevealCommand(
        targetPath: targetPath,
        targetIsDirectory: false,
        operatingSystem: 'windows',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'explorer.exe');
      expect(command.arguments, ['/select,', targetPath]);
    });

    test('opens Windows directory directly', () {
      const targetPath = r'C:\Users\left\Videos';

      final command = WorkbenchFileRevealer.buildRevealCommand(
        targetPath: targetPath,
        targetIsDirectory: true,
        operatingSystem: 'windows',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'explorer.exe');
      expect(command.arguments, [targetPath]);
    });

    test('builds macOS reveal command for files', () {
      const targetPath = '/Users/left/Videos/source.mp4';

      final command = WorkbenchFileRevealer.buildRevealCommand(
        targetPath: targetPath,
        targetIsDirectory: false,
        operatingSystem: 'macos',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'open');
      expect(command.arguments, ['-R', targetPath]);
    });

    test('opens macOS directory directly', () {
      const targetPath = '/Users/left/Videos';

      final command = WorkbenchFileRevealer.buildRevealCommand(
        targetPath: targetPath,
        targetIsDirectory: true,
        operatingSystem: 'macos',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'open');
      expect(command.arguments, [targetPath]);
    });

    test('opens Linux parent directory for files', () {
      const targetPath = '/home/left/Videos/source.mp4';

      final command = WorkbenchFileRevealer.buildRevealCommand(
        targetPath: targetPath,
        targetIsDirectory: false,
        operatingSystem: 'linux',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'xdg-open');
      expect(command.arguments, ['/home/left/Videos']);
    });

    test('falls back to existing parent directory for missing files', () {
      final tempDirectory = Directory.systemTemp.createTempSync(
        'framelean_reveal_',
      );

      try {
        final missingTarget = path.join(tempDirectory.path, 'missing.mp4');

        final target = WorkbenchFileRevealer.resolveRevealTarget(missingTarget);

        expect(target, isNotNull);
        expect(target!.path, tempDirectory.path);
        expect(target.isDirectory, true);
      } finally {
        tempDirectory.deleteSync(recursive: true);
      }
    });
  });
}
