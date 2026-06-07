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
  TextColumn get customFfmpegPath =>
      text().named('custom_ffmpeg_path').nullable()();
  TextColumn get customFfprobePath =>
      text().named('custom_ffprobe_path').nullable()();
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
      .withDefault(const Constant('balanced'))();
  TextColumn get defaultOutputFileNameTemplate => text()
      .named('default_output_file_name_template')
      .withDefault(const Constant('sourceFileNameCodec'))();
  TextColumn get defaultMediaConfigJson =>
      text().named('default_media_config_json').nullable()();
  TextColumn get themeMode =>
      text().named('theme_mode').withDefault(const Constant('light'))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  String get tableName => 'settings';

  @override
  Set<Column> get primaryKey => {id};
}
