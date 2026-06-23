import 'package:framelean/domain/library.dart';

abstract interface class EnterpriseUpdateConfigStore {
  Future<EnterpriseUpdateConfig> load();
}

class EnterpriseUpdateConfigCache {
  EnterpriseUpdateConfigCache(this.store);

  final EnterpriseUpdateConfigStore store;
  EnterpriseUpdateConfig? _snapshot;

  EnterpriseUpdateConfig? get snapshot => _snapshot;

  Future<EnterpriseUpdateConfig> load() async {
    return _snapshot ??= await store.load();
  }

  Future<EnterpriseUpdateConfig> reload() async {
    return _snapshot = await store.load();
  }
}
