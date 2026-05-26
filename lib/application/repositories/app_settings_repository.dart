import 'package:framelean/domain/entities/app_settings.dart';

/// 应用设置存储抽象
abstract class AppSettingsRepository {
  /// 读取当前设置
  Future<AppSettings> loadSettings();

  /// 保存当前设置
  Future<void> saveSettings(AppSettings settings);
}
