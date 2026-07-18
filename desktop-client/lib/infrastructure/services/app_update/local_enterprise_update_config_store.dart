import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as p;

class LocalEnterpriseUpdateConfigStore implements EnterpriseUpdateConfigStore {
  const LocalEnterpriseUpdateConfigStore({
    this.managedPreferencesReader =
        const MethodChannelManagedPreferencesReader(),
  });

  static const _userOverrideEnabled = bool.fromEnvironment(
    'FRAMELEAN_ALLOW_USER_ENTERPRISE_UPDATE_CONFIG',
  );

  final ManagedPreferencesReader managedPreferencesReader;

  @override
  Future<EnterpriseUpdateConfig> load() async {
    var config = EnterpriseUpdateConfig.bundled();

    final platformConfig = Platform.isMacOS
        ? await _loadMacosConfig(config)
        : Platform.isWindows
        ? await _loadWindowsConfig(config)
        : null;
    if (platformConfig != null) {
      config = platformConfig;
    }

    if (_userOverrideEnabled) {
      final userOverride = await _loadUserOverride(config);
      if (userOverride != null) {
        config = userOverride;
      }
    }

    return config;
  }

  Future<EnterpriseUpdateConfig?> _loadMacosConfig(
    EnterpriseUpdateConfig bundled,
  ) async {
    final managed = await managedPreferencesReader.read();
    if (managed.isNotEmpty) {
      return bundled.mergeTrustedOverride(
        managed,
        source: EnterpriseUpdateConfigSource.macosManagedPreferences,
      );
    }

    final file = File(
      '/Library/Application Support/FrameLean/enterprise-update.json',
    );
    if (!await file.exists() || !await _isTrustedMacosConfigFile(file)) {
      return null;
    }
    return _readJsonConfig(
      file,
      bundled,
      source: EnterpriseUpdateConfigSource.macosLibraryFile,
    );
  }

  Future<EnterpriseUpdateConfig?> _loadWindowsConfig(
    EnterpriseUpdateConfig bundled,
  ) async {
    final registry = await _readWindowsPolicyRegistry();
    if (registry.isNotEmpty) {
      return bundled.mergeTrustedOverride(
        registry,
        source: EnterpriseUpdateConfigSource.windowsPolicyRegistry,
      );
    }

    final programData = Platform.environment['ProgramData']?.trim();
    if (programData == null || programData.isEmpty) {
      return null;
    }
    final file = File(
      p.join(programData, 'FrameLean', 'enterprise-update.json'),
    );
    if (!await file.exists() || !await _isTrustedWindowsConfigFile(file)) {
      return null;
    }
    return _readJsonConfig(
      file,
      bundled,
      source: EnterpriseUpdateConfigSource.windowsProgramDataFile,
    );
  }

  Future<EnterpriseUpdateConfig?> _loadUserOverride(
    EnterpriseUpdateConfig bundled,
  ) async {
    final home = Platform
        .environment[Platform.isWindows ? 'USERPROFILE' : 'HOME']
        ?.trim();
    if (home == null || home.isEmpty) {
      return null;
    }
    final file = File(p.join(home, '.framelean', 'enterprise-update.dev.json'));
    if (!await file.exists()) {
      return null;
    }
    return _readJsonConfig(
      file,
      bundled,
      source: EnterpriseUpdateConfigSource.userOverride,
    );
  }

  Future<EnterpriseUpdateConfig?> _readJsonConfig(
    File file,
    EnterpriseUpdateConfig bundled, {
    required EnterpriseUpdateConfigSource source,
  }) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return bundled.mergeTrustedOverride(decoded, source: source);
    } on Object {
      return null;
    }
  }

  Future<bool> _isTrustedMacosConfigFile(File file) async {
    final directory = file.parent;
    final fileMode = await _readMacosStat(file.path);
    final directoryMode = await _readMacosStat(directory.path);
    if (fileMode == null || directoryMode == null) {
      return false;
    }
    return fileMode.ownerUid == 0 &&
        fileMode.groupGid == 80 &&
        fileMode.mode == 644 &&
        directoryMode.ownerUid == 0 &&
        directoryMode.groupGid == 80 &&
        directoryMode.mode == 755;
  }

  Future<_MacosStat?> _readMacosStat(String path) async {
    try {
      final result = await Process.run('/usr/bin/stat', [
        '-f',
        '%u:%g:%OLp',
        path,
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      final parts = '${result.stdout}'.trim().split(':');
      if (parts.length != 3) {
        return null;
      }
      return _MacosStat(
        ownerUid: int.parse(parts[0]),
        groupGid: int.parse(parts[1]),
        mode: int.parse(parts[2]),
      );
    } on Object {
      return null;
    }
  }

  Future<bool> _isTrustedWindowsConfigFile(File file) async {
    return await _isTrustedWindowsPath(file.parent.path) &&
        await _isTrustedWindowsPath(file.path);
  }

  Future<bool> _isTrustedWindowsPath(String path) async {
    try {
      final script = r'''
$ErrorActionPreference = "Stop"
$acl = Get-Acl -LiteralPath $args[0]
$unsafe = $false
foreach ($rule in $acl.Access) {
  $sid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
  if ($sid -in @("S-1-1-0", "S-1-5-11", "S-1-5-32-545")) {
    $rights = [System.Security.AccessControl.FileSystemRights]$rule.FileSystemRights
    $writeRights =
      [System.Security.AccessControl.FileSystemRights]::Write -bor
      [System.Security.AccessControl.FileSystemRights]::WriteData -bor
      [System.Security.AccessControl.FileSystemRights]::CreateFiles -bor
      [System.Security.AccessControl.FileSystemRights]::Modify -bor
      [System.Security.AccessControl.FileSystemRights]::FullControl
    if (($rights -band $writeRights) -ne 0) {
      $unsafe = $true
    }
  }
}
if ($unsafe) { exit 2 }
exit 0
''';
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        script,
        path,
      ]);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  Future<Map<String, Object?>> _readWindowsPolicyRegistry() async {
    try {
      final result = await Process.run('reg.exe', [
        'query',
        r'HKLM\Software\Policies\FrameLean',
      ]);
      if (result.exitCode != 0) {
        return const {};
      }
      final values = _parseRegQueryOutput('${result.stdout}');
      final jsonText = values['EnterpriseUpdateConfig'];
      if (jsonText is String && jsonText.trim().isNotEmpty) {
        final decoded = jsonDecode(jsonText);
        if (decoded is Map<String, Object?>) {
          return decoded;
        }
      }
      return _normalizeConfigKeys(values);
    } on Object {
      return const {};
    }
  }

  Map<String, Object?> _parseRegQueryOutput(String output) {
    final values = <String, Object?>{};
    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('HKEY_')) {
        continue;
      }
      final match = RegExp(r'^(\S+)\s+(REG_\S+)\s+(.+)$').firstMatch(line);
      if (match == null) {
        continue;
      }
      final name = match.group(1)!;
      final type = match.group(2)!;
      final value = match.group(3)!.trim();
      if (type == 'REG_DWORD') {
        values[name] = int.tryParse(value.replaceFirst('0x', ''), radix: 16);
      } else {
        values[name] = value;
      }
    }
    return values;
  }

  Map<String, Object?> _normalizeConfigKeys(Map<String, Object?> values) {
    const aliases = {
      'SchemaVersion': 'schemaVersion',
      'Mode': 'mode',
      'UpdateBaseUrl': 'updateBaseUrl',
      'Channel': 'channel',
      'Ring': 'ring',
      'AllowAutomaticChecks': 'allowAutomaticChecks',
      'AllowInAppInstall': 'allowInAppInstall',
      'MacosAppcastUrl': 'macosAppcastUrl',
      'TrustedReleaseKeyIds': 'trustedReleaseKeyIds',
    };
    return {
      for (final entry in values.entries)
        aliases[entry.key] ?? entry.key: entry.value,
    };
  }
}

abstract interface class ManagedPreferencesReader {
  Future<Map<String, Object?>> read();
}

class MethodChannelManagedPreferencesReader
    implements ManagedPreferencesReader {
  const MethodChannelManagedPreferencesReader();

  static const _channel = MethodChannel(enterpriseUpdateConfigChannel);

  @override
  Future<Map<String, Object?>> read() async {
    if (!Platform.isMacOS) {
      return const {};
    }
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'readManagedPreferences',
      );
      return result == null ? const {} : Map<String, Object?>.from(result);
    } on Object {
      return const {};
    }
  }
}

class _MacosStat {
  const _MacosStat({
    required this.ownerUid,
    required this.groupGid,
    required this.mode,
  });

  final int ownerUid;
  final int groupGid;
  final int mode;
}
