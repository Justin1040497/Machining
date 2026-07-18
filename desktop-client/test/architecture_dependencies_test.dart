import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'source imports respect the Clean Architecture dependency direction',
    () {
      final violations = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final relativePath = path.relative(entity.path);
        final layer = _layerFor(relativePath);
        if (layer == null || layer == 'app') {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          final import = _importFrom(lines[index]);
          if (import == null) {
            continue;
          }

          final reason = _violationReason(layer, import);
          if (reason != null) {
            violations.add(
              '$relativePath:${index + 1} imports $import ($reason)',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}

String? _layerFor(String filePath) {
  final segments = path.split(filePath);
  if (segments.length < 2 || segments.first != 'lib') {
    return null;
  }
  return segments[1];
}

String? _importFrom(String line) {
  final match = RegExp(r"^\s*import\s+'([^']+)'").firstMatch(line);
  return match?.group(1);
}

String? _violationReason(String layer, String import) {
  final projectImport = RegExp(
    r'^package:framelean/(app|application|domain|features|infrastructure)/',
  ).firstMatch(import);
  final targetLayer = projectImport?.group(1);

  switch (layer) {
    case 'domain':
      if (targetLayer != null && targetLayer != 'domain') {
        return 'domain may only depend on domain';
      }
      if (import == 'dart:io' ||
          import.startsWith('package:flutter/') ||
          import.startsWith('package:drift/')) {
        return 'domain must stay framework and platform independent';
      }
    case 'application':
      if (targetLayer == 'app' ||
          targetLayer == 'features' ||
          targetLayer == 'infrastructure') {
        return 'application may only depend on application and domain';
      }
      if (import.startsWith('package:flutter/')) {
        return 'application must not depend on Flutter';
      }
    case 'infrastructure':
      if (targetLayer == 'app' || targetLayer == 'features') {
        return 'infrastructure must not depend on app or features';
      }
    case 'features':
      if (targetLayer == 'infrastructure') {
        return 'features must use application abstractions via app providers';
      }
  }

  return null;
}
