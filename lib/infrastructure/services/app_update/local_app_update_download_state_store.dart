import 'dart:convert';
import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAppUpdateDownloadStateStore implements AppUpdateDownloadStateStore {
  const LocalAppUpdateDownloadStateStore();

  static const _fileName = 'update-download-state.json';

  @override
  Future<PersistedDownloadState?> load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    if (!await file.exists()) {
      return null;
    }
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final pkg = json['package'] as Map<String, dynamic>;
      final release = AppReleaseInfo(
        version: json['version'] as String,
        buildNumber: json['buildNumber'] as int,
        channel: json['channel'] as String,
        platform: json['platform'] as String,
        mandatory: json['mandatory'] as bool? ?? false,
        minSupportedBuild: json['minSupportedBuild'] as int? ?? 0,
        notesUrl: json['notesUrl'] as String,
        releaseNotesMarkdown: json['releaseNotesMarkdown'] as String,
        releaseNotesSummary: json['releaseNotesSummary'] as String,
        package: AppUpdatePackageInfo(
          fileName: pkg['fileName'] as String,
          sizeBytes: pkg['sizeBytes'] as int,
          sha256: pkg['sha256'] as String,
          ed25519Signature: pkg['ed25519Signature'] as String?,
        ),
        githubDownloadUrl: json['githubDownloadUrl'] as String?,
        giteeDownloadUrl: json['giteeDownloadUrl'] as String?,
        backupDownloadUrl: json['backupDownloadUrl'] as String?,
      );
      return PersistedDownloadState(
        release: release,
        filePath: json['filePath'] as String,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(PersistedDownloadState state) async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    final json = {
      'version': state.release.version,
      'buildNumber': state.release.buildNumber,
      'channel': state.release.channel,
      'platform': state.release.platform,
      'mandatory': state.release.mandatory,
      'minSupportedBuild': state.release.minSupportedBuild,
      'notesUrl': state.release.notesUrl,
      'releaseNotesMarkdown': state.release.releaseNotesMarkdown,
      'releaseNotesSummary': state.release.releaseNotesSummary,
      'githubDownloadUrl': state.release.githubDownloadUrl,
      'giteeDownloadUrl': state.release.giteeDownloadUrl,
      'backupDownloadUrl': state.release.backupDownloadUrl,
      'package': {
        'fileName': state.release.package.fileName,
        'sizeBytes': state.release.package.sizeBytes,
        'sha256': state.release.package.sha256,
        'ed25519Signature': state.release.package.ed25519Signature,
      },
      'filePath': state.filePath,
    };
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(json));
  }

  @override
  Future<void> clear() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
