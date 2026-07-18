import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/value_objects/enterprise_update_config.dart';

void main() {
  test('trusted override merges allowed update fields', () {
    final config = EnterpriseUpdateConfig.bundled().mergeTrustedOverride({
      'schemaVersion': 1,
      'mode': 'managed',
      'updateBaseUrl': 'https://updates.example.com',
      'channel': 'stable',
      'ring': 'pilot',
      'allowAutomaticChecks': false,
      'allowInAppInstall': 1,
      'macosAppcastUrl': 'https://updates.example.com/api/v1/sparkle/appcast',
      'trustedReleaseKeyIds': ['stable-v1'],
      'ignored': 'value',
    }, source: EnterpriseUpdateConfigSource.macosManagedPreferences);

    expect(config.mode, EnterpriseUpdateMode.managed);
    expect(config.updateBaseUrl, 'https://updates.example.com');
    expect(config.channel, 'stable');
    expect(config.ring, 'pilot');
    expect(config.allowAutomaticChecks, isFalse);
    expect(config.allowInAppInstall, isTrue);
    expect(config.trustedReleaseKeyIds, ['stable-v1']);
    expect(config.source, EnterpriseUpdateConfigSource.macosManagedPreferences);
  });

  test('invalid override values keep bundled defaults', () {
    final bundled = EnterpriseUpdateConfig.bundled();
    final config = bundled.mergeTrustedOverride({
      'schemaVersion': 1,
      'mode': 'unknown',
      'updateBaseUrl': 'http://updates.example.com',
      'channel': 'stable beta',
      'macosAppcastUrl': 'file:///tmp/appcast.xml',
      'allowAutomaticChecks': 'yes',
      'trustedReleaseKeyIds': ['invalid key id'],
    }, source: EnterpriseUpdateConfigSource.userOverride);

    expect(config.mode, bundled.mode);
    expect(config.updateBaseUrl, bundled.updateBaseUrl);
    expect(config.channel, bundled.channel);
    expect(config.macosAppcastUrl, bundled.macosAppcastUrl);
    expect(config.allowAutomaticChecks, bundled.allowAutomaticChecks);
    expect(config.trustedReleaseKeyIds, isEmpty);
  });

  test('unsupported or missing schema rejects the complete override', () {
    final bundled = EnterpriseUpdateConfig.bundled();

    for (final override in [
      {'mode': 'disabled'},
      {'schemaVersion': 2, 'mode': 'disabled'},
    ]) {
      final config = bundled.mergeTrustedOverride(
        override,
        source: EnterpriseUpdateConfigSource.windowsPolicyRegistry,
      );
      expect(config.mode, bundled.mode);
      expect(config.source, bundled.source);
    }
  });
}
