import 'package:drift/drift.dart';
import 'package:framelean/application/repositories/workbench_order_revision_store.dart';
import 'package:framelean/infrastructure/database/app_database.dart';

final class DriftWorkbenchOrderRevisionStore
    implements WorkbenchOrderRevisionStore {
  const DriftWorkbenchOrderRevisionStore(this.database);

  final AppDatabase database;

  @override
  Future<int> nextRevision() {
    return database.transaction(() async {
      final row = await (database.select(
        database.workbenchOrderStateRows,
      )..where((table) => table.id.equals(1))).getSingleOrNull();
      final next = (row?.orderRevision ?? 0) + 1;
      await database
          .into(database.workbenchOrderStateRows)
          .insertOnConflictUpdate(
            WorkbenchOrderStateRowsCompanion(
              id: const Value(1),
              orderRevision: Value(next),
            ),
          );
      return next;
    });
  }
}
