import 'package:drift/drift.dart';

class AppNotificationRows extends Table {
  TextColumn get id => text()();
  TextColumn get level => text()();
  TextColumn get title => text()();
  TextColumn get message => text().withDefault(const Constant(''))();
  TextColumn get source => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get readAt => integer().named('read_at').nullable()();
  IntColumn get dismissedAt => integer().named('dismissed_at').nullable()();
  TextColumn get payloadJson => text().named('payload_json').nullable()();

  @override
  String get tableName => 'app_notifications';

  @override
  Set<Column> get primaryKey => {id};
}
