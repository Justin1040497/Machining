import 'package:drift/drift.dart';

class TaskFolderRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mediaKind => text().named('media_kind')();
  IntColumn get sortOrder => integer().named('sort_order')();
  TextColumn get defaultConfigJson => text().named('default_config_json')();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  String get tableName => 'task_folders';

  @override
  Set<Column> get primaryKey => {id};
}
