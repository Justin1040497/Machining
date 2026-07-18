import 'dart:io';

import 'package:framelean/application/library.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalAppUpdateInstallIdStore implements AppUpdateInstallIdStore {
  const LocalAppUpdateInstallIdStore();

  static const _uuid = Uuid();

  @override
  Future<String> loadOrCreateInstallId() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'update-install-id'));
    if (await file.exists()) {
      final value = (await file.readAsString()).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    final id = _uuid.v4();
    await file.create(recursive: true);
    await file.writeAsString(id);
    return id;
  }
}
