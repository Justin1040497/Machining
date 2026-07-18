import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalAppUpdateSnoozeStore implements AppUpdateSnoozeStore {
  const LocalAppUpdateSnoozeStore();

  static const _fileName = 'update-snoozed-version';

  @override
  Future<String?> loadSnoozedVersion() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    if (!await file.exists()) {
      return null;
    }
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> saveSnoozedVersion(String version) async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    await file.create(recursive: true);
    await file.writeAsString(version);
  }

  @override
  Future<void> clearSnoozedVersion() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, _fileName));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
