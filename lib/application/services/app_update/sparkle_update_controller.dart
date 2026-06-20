import 'package:framelean/domain/value_objects/enterprise_update_config.dart';

class SparkleUpdatePolicyStatus {
  const SparkleUpdatePolicyStatus({
    required this.available,
    required this.automaticChecksEnabled,
    required this.appcastUrl,
  });

  final bool available;
  final bool automaticChecksEnabled;
  final String appcastUrl;
}

abstract interface class SparkleUpdateController {
  Future<void> checkForUpdates(EnterpriseUpdateConfig config);

  Future<void> checkForUpdateInformation(EnterpriseUpdateConfig config);

  Future<SparkleUpdatePolicyStatus> getUpdatePolicyStatus(
    EnterpriseUpdateConfig config,
  );
}
