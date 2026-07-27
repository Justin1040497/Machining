import 'package:drift/drift.dart';

class SettingsRows extends Table {
  IntColumn get id => integer()();
  TextColumn get defaultOutputDirectory =>
      text().named('default_output_directory').nullable()();
  TextColumn get lastSelectedOutputDirectory =>
      text().named('last_selected_output_directory').nullable()();
  BoolColumn get saveOutputToSourceDirectory => boolean()
      .named('save_output_to_source_directory')
      .withDefault(const Constant(true))();
  BoolColumn get showRawLog =>
      boolean().named('show_raw_log').withDefault(const Constant(false))();
  BoolColumn get showAdvancedOptions => boolean()
      .named('show_advanced_options')
      .withDefault(const Constant(false))();
  TextColumn get defaultOutputVideoCodec => text()
      .named('default_output_video_codec')
      .withDefault(const Constant('h264'))();
  TextColumn get defaultCompressionSmartPreset => text()
      .named('default_compression_smart_preset')
      .withDefault(const Constant('chat'))();
  TextColumn get defaultOutputFileNameTemplate => text()
      .named('default_output_file_name_template')
      .withDefault(const Constant('{source}-{action}'))();
  TextColumn get defaultMediaConfigJson =>
      text().named('default_media_config_json').nullable()();
  TextColumn get themeMode =>
      text().named('theme_mode').withDefault(const Constant('system'))();
  BoolColumn get hideNotificationBadge => boolean()
      .named('hide_notification_badge')
      .withDefault(const Constant(true))();
  BoolColumn get showTaskCompletionDialog => boolean()
      .named('show_task_completion_dialog')
      .withDefault(const Constant(true))();
  TextColumn get taskCompletionSound => text()
      .named('task_completion_sound')
      .withDefault(const Constant('clean_success'))();
  IntColumn get maxConcurrentExecutions => integer()
      .named('max_concurrent_executions')
      .withDefault(const Constant(2))();
  IntColumn get folderImportScanDepth => integer()
      .named('folder_import_scan_depth')
      .withDefault(const Constant(2))();
  TextColumn get notificationPoliciesJson => text()
      .named('notification_policies_json')
      .withDefault(const Constant('{}'))();
  TextColumn get shortcutBindingsJson => text()
      .named('shortcut_bindings_json')
      .withDefault(const Constant('{}'))();
  TextColumn get closeBehavior => text()
      .named('close_behavior')
      .withDefault(const Constant('background'))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  String get tableName => 'settings';

  @override
  Set<Column> get primaryKey => {id};
}
