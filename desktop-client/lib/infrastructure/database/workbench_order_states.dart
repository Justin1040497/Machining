import 'package:drift/drift.dart';

class WorkbenchOrderStateRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get orderRevision =>
      integer().named('order_revision').withDefault(const Constant(0))();

  @override
  String get tableName => 'workbench_order_state';

  @override
  Set<Column> get primaryKey => {id};
}
