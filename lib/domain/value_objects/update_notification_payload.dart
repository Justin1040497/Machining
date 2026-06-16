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
    );
  }

  final String version;
  final int buildNumber;
  final String platform;
  final AppUpdateStatus status;
  final String notesMarkdown;
  final String notesSummary;

  String toJson() {
    return jsonEncode({
      'version': version,
      'buildNumber': buildNumber,
      'platform': platform,
      'status': status.name,
      'notesMarkdown': notesMarkdown,
      'notesSummary': notesSummary,
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
      );
    } on Object {
      return null;
    }
  }
}
