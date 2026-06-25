/// 更新提醒 snooze 持久化端口。
///
/// 记录用户主动跳过的版本号。同一版本在开机自启时不再自动弹出更新弹窗，
/// 但用户手动触发（轻提示 / 设置页检查更新）仍会展示。
/// 服务端发布新版本后 snooze 自动失效。
abstract class AppUpdateSnoozeStore {
  Future<String?> loadSnoozedVersion();

  Future<void> saveSnoozedVersion(String version);

  Future<void> clearSnoozedVersion();
}
