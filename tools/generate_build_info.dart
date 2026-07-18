import 'dart:io';

/// Reads pubspec.yaml and generates lib/application/services/framelean_build_info.dart
/// so that version and build number are maintained in a single place (pubspec.yaml).
///
/// Usage from desktop-client/: dart run ../tools/generate_build_info.dart [--check]
///   --check   Exit with code 1 if the file would change (for CI validation).

Future<void> main(List<String> arguments) async {
  final checkMode = arguments.contains('--check');
  final repoRoot = _findRepoRoot();
  final pubspec = File('$repoRoot/pubspec.yaml');
  final outputFile = File(
    '$repoRoot/lib/application/services/framelean_build_info.dart',
  );

  if (!await pubspec.exists()) {
    throw StateError('pubspec.yaml not found at ${pubspec.path}');
  }

  final content = await pubspec.readAsString();
  final versionMatch = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)',
    multiLine: true,
  ).firstMatch(content);

  if (versionMatch == null) {
    throw StateError(
      'Could not parse version from pubspec.yaml. '
      'Expected format: version: X.Y.Z+N',
    );
  }

  final versionLabel = versionMatch.group(1)!;
  final buildNumber = versionMatch.group(2)!;

  final generated = '''
// AUTO-GENERATED from pubspec.yaml — DO NOT EDIT.
// Run from desktop-client/: dart run ../tools/generate_build_info.dart

// ignore_for_file: avoid_classes_with_only_static_members

abstract final class FrameLeanBuildInfo {
  static const currentVersionLabel = '$versionLabel';
  static const currentBuildNumber = $buildNumber;
}
''';

  if (checkMode) {
    if (await outputFile.exists()) {
      final existing = await outputFile.readAsString();
      if (existing == generated) {
        exit(0);
      }
    }
    stderr.writeln(
      'framelean_build_info.dart is out of sync with pubspec.yaml. '
      'Run from desktop-client/: dart run ../tools/generate_build_info.dart',
    );
    exit(1);
  }

  await outputFile.writeAsString(generated);
  stdout.writeln('Generated: ${outputFile.path}');
  stdout.writeln('  version = $versionLabel');
  stdout.writeln('  build   = $buildNumber');
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find pubspec.yaml in any parent directory',
      );
    }
    dir = parent;
  }
  return dir.path;
}
