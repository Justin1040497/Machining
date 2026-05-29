import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/update/app_version.dart';

void main() {
  group('AppVersion', () {
    test('parses semantic versions with tag and build suffixes', () {
      expect(
        AppVersion.parse('v1.2.3'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
      expect(
        AppVersion.parse('1.2.3+4'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
      expect(
        AppVersion.parse('1.2.3-beta.1'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
    });

    test('compares versions by major minor and patch', () {
      expect(AppVersion.parse('1.1.6') > AppVersion.parse('1.1.5'), isTrue);
      expect(AppVersion.parse('1.2.0') > AppVersion.parse('1.1.9'), isTrue);
      expect(AppVersion.parse('2.0.0') > AppVersion.parse('1.9.9'), isTrue);
      expect(AppVersion.parse('1.1.5') < AppVersion.parse('1.1.6'), isTrue);
    });
  });
}
