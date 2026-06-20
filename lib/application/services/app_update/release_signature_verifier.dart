import 'dart:io';

import 'package:framelean/domain/value_objects/app_update_package_info.dart';
import 'package:framelean/domain/value_objects/enterprise_update_config.dart';

abstract interface class ReleaseSignatureVerifier {
  Future<void> verify({
    required File file,
    required AppUpdatePackageInfo package,
    required EnterpriseUpdateConfig config,
  });
}
