enum EnterpriseUpdateMode { enabled, disabled, managed }

enum EnterpriseUpdateConfigSource {
  bundled,
  macosManagedPreferences,
  macosLibraryFile,
  windowsPolicyRegistry,
  windowsProgramDataFile,
  userOverride,
}

class EnterpriseUpdateConfig {
  const EnterpriseUpdateConfig({
    required this.schemaVersion,
    required this.mode,
    required this.updateBaseUrl,
    required this.channel,
    required this.ring,
    required this.allowAutomaticChecks,
    required this.allowInAppInstall,
    required this.macosAppcastUrl,
    required this.trustedReleaseKeyIds,
    required this.source,
  });

  factory EnterpriseUpdateConfig.bundled() {
    return EnterpriseUpdateConfig(
      schemaVersion: 1,
      mode:
          _modeFromName(_bundledUpdateModeName) ?? EnterpriseUpdateMode.enabled,
      updateBaseUrl: const String.fromEnvironment(
        'FRAMELEAN_UPDATE_BASE_URL',
      ).trim(),
      channel: const String.fromEnvironment(
        'FRAMELEAN_UPDATE_CHANNEL',
        defaultValue: 'stable',
      ).trim(),
      ring: const String.fromEnvironment(
        'FRAMELEAN_UPDATE_RING',
        defaultValue: 'stable',
      ).trim(),
      allowAutomaticChecks: const bool.fromEnvironment(
        'FRAMELEAN_UPDATE_ALLOW_AUTOMATIC_CHECKS',
        defaultValue: true,
      ),
      allowInAppInstall: const bool.fromEnvironment(
        'FRAMELEAN_UPDATE_ALLOW_IN_APP_INSTALL',
        defaultValue: true,
      ),
      macosAppcastUrl: const String.fromEnvironment(
        'FRAMELEAN_SPARKLE_FEED_URL',
      ).trim(),
      trustedReleaseKeyIds: _splitCsv(
        const String.fromEnvironment('FRAMELEAN_TRUSTED_RELEASE_KEY_IDS'),
      ),
      source: EnterpriseUpdateConfigSource.bundled,
    );
  }

  final int schemaVersion;
  final EnterpriseUpdateMode mode;
  final String updateBaseUrl;
  final String channel;
  final String ring;
  final bool allowAutomaticChecks;
  final bool allowInAppInstall;
  final String macosAppcastUrl;
  final List<String> trustedReleaseKeyIds;
  final EnterpriseUpdateConfigSource source;

  bool get updatesDisabled => mode == EnterpriseUpdateMode.disabled;

  bool get hasUpdateBaseUrl => updateBaseUrl.trim().isNotEmpty;

  bool get hasMacosAppcastUrl => macosAppcastUrl.trim().isNotEmpty;

  bool get requiresReleaseSignature =>
      _bundledReleaseSignatureRequired || trustedReleaseKeyIds.isNotEmpty;

  EnterpriseUpdateConfig mergeTrustedOverride(
    Map<String, Object?> json, {
    required EnterpriseUpdateConfigSource source,
  }) {
    if (_readInt(json, 'schemaVersion') != 1) {
      return this;
    }
    return copyWith(
      schemaVersion: 1,
      mode: _readMode(json, 'mode') ?? mode,
      updateBaseUrl: _readHttpsUrl(json, 'updateBaseUrl') ?? updateBaseUrl,
      channel: _readIdentifier(json, 'channel') ?? channel,
      ring: _readIdentifier(json, 'ring') ?? ring,
      allowAutomaticChecks:
          _readBool(json, 'allowAutomaticChecks') ?? allowAutomaticChecks,
      allowInAppInstall:
          _readBool(json, 'allowInAppInstall') ?? allowInAppInstall,
      macosAppcastUrl:
          _readHttpsUrl(json, 'macosAppcastUrl') ?? macosAppcastUrl,
      trustedReleaseKeyIds:
          _readKeyIds(json, 'trustedReleaseKeyIds') ?? trustedReleaseKeyIds,
      source: source,
    );
  }

  EnterpriseUpdateConfig copyWith({
    int? schemaVersion,
    EnterpriseUpdateMode? mode,
    String? updateBaseUrl,
    String? channel,
    String? ring,
    bool? allowAutomaticChecks,
    bool? allowInAppInstall,
    String? macosAppcastUrl,
    List<String>? trustedReleaseKeyIds,
    EnterpriseUpdateConfigSource? source,
  }) {
    return EnterpriseUpdateConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      mode: mode ?? this.mode,
      updateBaseUrl: updateBaseUrl ?? this.updateBaseUrl,
      channel: channel ?? this.channel,
      ring: ring ?? this.ring,
      allowAutomaticChecks: allowAutomaticChecks ?? this.allowAutomaticChecks,
      allowInAppInstall: allowInAppInstall ?? this.allowInAppInstall,
      macosAppcastUrl: macosAppcastUrl ?? this.macosAppcastUrl,
      trustedReleaseKeyIds: List.unmodifiable(
        trustedReleaseKeyIds ?? this.trustedReleaseKeyIds,
      ),
      source: source ?? this.source,
    );
  }
}

const _bundledUpdateModeName = String.fromEnvironment(
  'FRAMELEAN_UPDATE_MODE',
  defaultValue: 'enabled',
);

const _bundledReleaseSignatureRequired = bool.fromEnvironment(
  'FRAMELEAN_REQUIRE_RELEASE_SIGNATURE',
);

EnterpriseUpdateMode? _readMode(Map<String, Object?> json, String key) {
  final text = _readString(json, key);
  if (text == null) {
    return null;
  }
  return _modeFromName(text);
}

EnterpriseUpdateMode? _modeFromName(String text) {
  for (final value in EnterpriseUpdateMode.values) {
    if (value.name == text.trim()) {
      return value;
    }
  }
  return null;
}

String? _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

String? _readHttpsUrl(Map<String, Object?> json, String key) {
  final value = _readString(json, key);
  if (value == null) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}

String? _readIdentifier(Map<String, Object?> json, String key) {
  final value = _readString(json, key);
  return value != null && RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(value)
      ? value
      : null;
}

int? _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? _readBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  return null;
}

List<String>? _readStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) {
    return List.unmodifiable(
      value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }
  if (value is String) {
    return _splitCsv(value);
  }
  return null;
}

List<String>? _readKeyIds(Map<String, Object?> json, String key) {
  final values = _readStringList(json, key);
  if (values == null ||
      values.any(
        (value) => !RegExp(r'^[a-zA-Z0-9._-]{1,64}$').hasMatch(value),
      )) {
    return null;
  }
  return values;
}

List<String> _splitCsv(String value) {
  return List.unmodifiable(
    value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}
