import 'dart:io';

import 'package:framelean/domain/library.dart';

abstract interface class ReleaseSignatureVerifier {
  Future<void> verify({
    required File file,
    required AppUpdatePackageInfo package,
    required EnterpriseUpdateConfig config,
  });
}
