import 'package:drift/drift.dart';
import 'package:machining/application/repositories/app_settings_repository.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/app_compression_settings.dart';
import 'package:machining/infrastructure/database/app_database.dart';

/// 用 Drift + SQLite 实现应用设置的读取和保存
class DriftAppSettingsRepository implements AppSettingsRepository {
  /// settings 表只保存一份全局设置，所以固定使用 id = 1
  static const settingsId = 1;

  final AppDatabase database;

  /// 这里把数据库对象当作参数传进来 是因为要保证这个数据库对象是唯一的 是由外面用一个实例统一管理的 而不是每个Repository都创建一个
  DriftAppSettingsRepository(this.database);

  @override
  Future<AppSettings> loadSettings() async {
    final row = await (database.select(
      database.settingsRows,
    )..where((table) => table.id.equals(settingsId))).getSingleOrNull();

    if (row == null) {
      /// 如果没有在数据库获取到数据 那就返回一个默认的设置
      return AppSettings.initial();
    }

    return row.toDomain();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (database.select(
      database.settingsRows,
    )..where((table) => table.id.equals(settingsId))).getSingleOrNull();

    /// Value是字段包装器 比如Value(null) 表示即使这个字段我填写的null 也要更新到数据库
    /// 如果这个字段不传 就是不更新 这么写就是保证当前这个字段参与本次更新
    await database
        .into(database.settingsRows)
        .insertOnConflictUpdate(
          SettingsRowsCompanion(
            id: const Value(settingsId),
            defaultOutputDirectory: Value(settings.defaultOutputDirectory),
            lastSelectedOutputDirectory: Value(
              settings.lastSelectedOutputDirectory,
            ),
            customFfmpegPath: Value(settings.customFfmpegPath),
            customFfprobePath: Value(settings.customFfprobePath),
            showRawLog: Value(settings.showRawLog),
            showAdvancedOptions: Value(settings.showAdvancedOptions),
            defaultOutputVideoCodec: Value(
              settings.defaultOutputVideoCodec.name,
            ),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }
}

/// 数据库Setting表转AppSetting实体类
extension SettingsRowMapper on SettingsRow {
  AppSettings toDomain() {
    return AppSettings(
      defaultOutputDirectory: defaultOutputDirectory,
      lastSelectedOutputDirectory: lastSelectedOutputDirectory,
      customFfmpegPath: customFfmpegPath,
      customFfprobePath: customFfprobePath,
      showRawLog: showRawLog,
      showAdvancedOptions: showAdvancedOptions,
      compressionSettings: AppCompressionSettings(
        defaultOutputVideoCodec: enumValueByNameInSettings(
          VideoCodec.values,
          defaultOutputVideoCodec,
        ),
      ),
    );
  }
}

T enumValueByNameInSettings<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }

  throw StateError('未知的枚举值: $name');
}
