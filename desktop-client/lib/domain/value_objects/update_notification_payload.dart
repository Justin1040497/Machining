import 'dart:convert';

import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';

class UpdateNotificationPayload {
  const UpdateNotificationPayload({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.status,
    required this.notesMarkdown,
    required this.notesSummary,
    this.githubDownloadUrl,
    this.giteeDownloadUrl,
    this.backupDownloadUrl,
  });

  factory UpdateNotificationPayload.fromRelease(
    AppReleaseInfo release, {
    required AppUpdateStatus status,
  }) {
    return UpdateNotificationPayload(
      version: release.version,
      buildNumber: release.buildNumber,
      platform: release.platform,
      status: status,
      notesMarkdown: release.releaseNotesMarkdown,
      notesSummary: release.releaseNotesSummary,
      githubDownloadUrl: release.githubDownloadUrl,
      giteeDownloadUrl: release.giteeDownloadUrl,
      backupDownloadUrl: release.backupDownloadUrl,
    );
  }

  final String version;
  final int buildNumber;
  final String platform;
  final AppUpdateStatus status;
  final String notesMarkdown;
  final String notesSummary;
  final String? githubDownloadUrl;
  final String? giteeDownloadUrl;
  final String? backupDownloadUrl;

  bool get hasExternalDownloadLinks =>
      _hasText(githubDownloadUrl) ||
      _hasText(giteeDownloadUrl) ||
      _hasText(backupDownloadUrl);

  String toJson() {
    return jsonEncode({
      'version': version,
      'buildNumber': buildNumber,
      'platform': platform,
      'status': status.name,
      'notesMarkdown': notesMarkdown,
      'notesSummary': notesSummary,
      'githubDownloadUrl': githubDownloadUrl,
      'giteeDownloadUrl': giteeDownloadUrl,
      'backupDownloadUrl': backupDownloadUrl,
    });
  }

  static UpdateNotificationPayload? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return null;
      }

      final statusValue = decoded['status'];
      final status = AppUpdateStatus.values.where((item) {
        return item.name == statusValue;
      }).firstOrNull;
      final version = decoded['version'];
      final buildNumber = decoded['buildNumber'];
      final platform = decoded['platform'];
      if (status == null ||
          version is! String ||
          buildNumber is! num ||
          platform is! String) {
        return null;
      }

      return UpdateNotificationPayload(
        version: version,
        buildNumber: buildNumber.toInt(),
        platform: platform,
        status: status,
        notesMarkdown: decoded['notesMarkdown'] as String? ?? '',
        notesSummary: decoded['notesSummary'] as String? ?? '',
        githubDownloadUrl: _readNullableString(decoded['githubDownloadUrl']),
        giteeDownloadUrl: _readNullableString(decoded['giteeDownloadUrl']),
        backupDownloadUrl: _readNullableString(decoded['backupDownloadUrl']),
      );
    } on Object {
      return null;
    }
  }
}


bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String? _readNullableString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
