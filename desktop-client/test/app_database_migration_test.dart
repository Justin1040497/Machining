import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('AppDatabase migrations', () {
    test(
      'upgrades schema 37 with safe task folder grouping metadata',
      () async {
        final fixture = await _seedCurrentDatabase();
        addTearDown(fixture.dispose);
        _downgrade(
          fixture.file,
          version: 37,
          statements: const [
            'ALTER TABLE task_folders DROP COLUMN origin',
            'ALTER TABLE task_folders DROP COLUMN compatibility_class',
          ],
        );

        final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
        addTearDown(database.close);

        final folder = await database
            .select(database.taskFolderRows)
            .getSingle();
        expect(folder.origin, 'manual');
        expect(folder.compatibilityClass, isNull);
        expect(await _userVersion(database), 38);
      },
    );

    test('upgrades schema 36 by removing folder media defaults', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 36,
        statements: const [
          "ALTER TABLE task_folders ADD COLUMN default_purpose TEXT NOT NULL DEFAULT 'compression'",
          "ALTER TABLE task_folders ADD COLUMN default_config_json TEXT NOT NULL DEFAULT '{}'",
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(task_folders)')
          .get();
      final names = columns.map((row) => row.read<String>('name'));
      expect(names, isNot(contains('default_purpose')));
      expect(names, isNot(contains('default_config_json')));
      final folder = await database.select(database.taskFolderRows).getSingle();
      expect(folder.id, 'legacy-folder');
      expect(folder.mediaKind, 'video');
      expect(folder.sortOrder, 0);
      expect(await _userVersion(database), 38);
    });

    test('upgrades schema 35 by removing the legacy concurrency limit', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 35,
        statements: const [
          'ALTER TABLE settings ADD COLUMN max_concurrent_executions INTEGER NOT NULL DEFAULT 2',
          'UPDATE settings SET max_concurrent_executions = 3 WHERE id = 1',
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(settings)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('max_concurrent_executions')),
      );
      final settings = await database.select(database.settingsRows).getSingle();
      expect(settings.id, 1);
      expect(settings.folderImportScanDepth, 2);
      expect(await _userVersion(database), 38);
    });

    test('upgrades schema 33 with persistent operation request ids', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 33,
        statements: const [
          'ALTER TABLE engine_analysis_projections DROP COLUMN analysis_request_id',
          'ALTER TABLE engine_analysis_projections DROP COLUMN execution_request_id',
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final columns = await database
          .customSelect("PRAGMA table_info('engine_analysis_projections')")
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['analysis_request_id', 'execution_request_id']),
      );
      expect(await _userVersion(database), 38);
    });

    test('upgrades schema 32 with persisted order revision state', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 32,
        statements: const ['DROP TABLE workbench_order_state'],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      expect(
        await database.select(database.workbenchOrderStateRows).get(),
        isEmpty,
      );
      expect(await _userVersion(database), 38);
    });

    test('upgrades schema 31 lifecycle projections and legacy statuses', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 31,
        statements: const [
          'ALTER TABLE engine_analysis_projections DROP COLUMN analysis_work_id',
          'ALTER TABLE engine_analysis_projections DROP COLUMN analysis_queue_position',
          'ALTER TABLE engine_analysis_projections DROP COLUMN analysis_queue_revision',
          'ALTER TABLE engine_analysis_projections DROP COLUMN execution_id',
          'ALTER TABLE engine_analysis_projections DROP COLUMN execution_queue_position',
          'ALTER TABLE engine_analysis_projections DROP COLUMN execution_queue_revision',
          'ALTER TABLE engine_analysis_projections DROP COLUMN execution_state',
          'ALTER TABLE engine_analysis_projections DROP COLUMN pause_reason',
          'ALTER TABLE engine_analysis_projections DROP COLUMN preempted_by_execution_id',
          'ALTER TABLE engine_analysis_projections DROP COLUMN resume_depth',
          'ALTER TABLE engine_analysis_projections DROP COLUMN media_time_us',
          'ALTER TABLE engine_analysis_projections DROP COLUMN processed_bytes',
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final task = (await database.select(database.taskRows).get()).single;
      expect(task.status, 'ready');
      expect(
        await database.select(database.engineAnalysisProjectionRows).get(),
        isEmpty,
      );
      expect(await _userVersion(database), 38);
    });

    test(
      'upgrades schema 30 by creating the engine analysis projection table',
      () async {
        final fixture = await _seedCurrentDatabase();
        addTearDown(fixture.dispose);
        _downgrade(
          fixture.file,
          version: 30,
          statements: const ['DROP TABLE engine_analysis_projections'],
        );

        final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
        addTearDown(database.close);

        expect(await database.select(database.taskRows).get(), hasLength(1));
        expect(
          await database.select(database.engineAnalysisProjectionRows).get(),
          isEmpty,
        );
        expect(await _userVersion(database), 38);
      },
    );

    test('upgrades schema 29 by adding failure_json', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 29,
        statements: const ['ALTER TABLE tasks DROP COLUMN failure_json'],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final task = (await database.select(database.taskRows).get()).single;
      expect(task.id, 'legacy-task');
      expect(task.failureJson, isNull);
      expect(await _userVersion(database), 38);
    });

    test(
      'upgrades schema 28 and preserves tasks folders and notifications',
      () async {
        final fixture = await _seedCurrentDatabase();
        addTearDown(fixture.dispose);
        _downgrade(
          fixture.file,
          version: 28,
          statements: const [
            'ALTER TABLE tasks DROP COLUMN failure_json',
            'ALTER TABLE settings DROP COLUMN notification_policies_json',
            'ALTER TABLE settings DROP COLUMN shortcut_bindings_json',
            'ALTER TABLE settings DROP COLUMN close_behavior',
          ],
        );

        final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
        addTearDown(database.close);

        expect(await database.select(database.taskRows).get(), hasLength(1));
        expect(
          await database.select(database.taskFolderRows).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.appNotificationRows).get(),
          hasLength(1),
        );
        final settings = await database
            .select(database.settingsRows)
            .getSingle();
        expect(settings.notificationPoliciesJson, '{}');
        expect(settings.shortcutBindingsJson, '{}');
        expect(settings.closeBehavior, 'background');
        expect(await _userVersion(database), 38);
      },
    );

    test('upgrades schema 24 and preserves pre-folder task data', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 24,
        statements: const [
          'ALTER TABLE tasks DROP COLUMN failure_json',
          'DROP TABLE task_folders',
          'ALTER TABLE tasks DROP COLUMN folder_id',
          'ALTER TABLE tasks DROP COLUMN folder_sort_order',
          'ALTER TABLE tasks DROP COLUMN policy_tags_json',
          'ALTER TABLE tasks DROP COLUMN analysis_audio_streams_json',
          'ALTER TABLE tasks DROP COLUMN output_file_size',
          'ALTER TABLE settings DROP COLUMN folder_import_scan_depth',
          'ALTER TABLE settings DROP COLUMN notification_policies_json',
          'ALTER TABLE settings DROP COLUMN shortcut_bindings_json',
          'ALTER TABLE settings DROP COLUMN close_behavior',
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);

      final tasks = await database.select(database.taskRows).get();
      expect(tasks.single.id, 'legacy-task');
      expect(tasks.single.fileName, 'legacy.mp4');
      expect(await database.select(database.taskFolderRows).get(), isEmpty);
      expect(
        await database.select(database.appNotificationRows).get(),
        hasLength(1),
      );
      final settings = await database.select(database.settingsRows).getSingle();
      expect(settings.folderImportScanDepth, 2);
      expect(await _userVersion(database), 38);
    });

    test('applies custom value migrations from schema 21', () async {
      final fixture = await _seedCurrentDatabase();
      addTearDown(fixture.dispose);
      _downgrade(
        fixture.file,
        version: 21,
        statements: const [
          "UPDATE settings SET default_compression_smart_preset = 'balanced'",
          "UPDATE settings SET default_output_file_name_template = '{source}-{date}-{action}'",
          "UPDATE settings SET task_completion_sound = 'none'",
        ],
      );

      final database = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(database.close);
      final settings = await database.select(database.settingsRows).getSingle();

      expect(settings.defaultCompressionSmartPreset, 'chat');
      expect(settings.defaultOutputFileNameTemplate, '{source}-{action}');
      expect(settings.taskCompletionSound, 'clean_success');
      expect(await _userVersion(database), 38);
    });
  });
}

Future<_DatabaseFixture> _seedCurrentDatabase() async {
  final directory = await Directory.systemTemp.createTemp(
    'framelean-migration-test-',
  );
  final file = File('${directory.path}/framelean.sqlite');
  final database = AppDatabase.forTesting(NativeDatabase(file));
  await database.customSelect('SELECT 1').get();
  await database.customStatement(
    "INSERT INTO settings (id, created_at, updated_at) VALUES (1, 1, 1)",
  );
  await database.customStatement(
    'INSERT INTO tasks ('
    'id, input_path, file_name, purpose, status, sort_order, '
    'output_format, video_codec, encoder_backend, resolution_preset, '
    'output_directory, created_at, folder_id'
    ") VALUES ('legacy-task', '/videos/legacy.mp4', 'legacy.mp4', "
    "'compression', 'pending', 0, 'mp4', 'h264', 'auto', 'original', "
    "'', 1, 'legacy-folder')",
  );
  await database.customStatement(
    'INSERT INTO task_folders ('
    'id, name, media_kind, sort_order, created_at, updated_at'
    ") VALUES ('legacy-folder', 'Legacy', 'video', 0, 1, 1)",
  );
  await database.customStatement(
    'INSERT INTO app_notifications ('
    'id, level, title, source, created_at'
    ") VALUES ('legacy-notification', 'success', 'Legacy', 'test', 1)",
  );
  await database.close();
  return _DatabaseFixture(directory: directory, file: file);
}

void _downgrade(
  File file, {
  required int version,
  required List<String> statements,
}) {
  final database = sqlite.sqlite3.open(file.path);
  try {
    database.execute('PRAGMA foreign_keys = OFF');
    for (final statement in statements) {
      database.execute(statement);
    }
    database.execute('PRAGMA user_version = $version');
  } finally {
    database.close();
  }
}

Future<int> _userVersion(AppDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

class _DatabaseFixture {
  const _DatabaseFixture({required this.directory, required this.file});

  final Directory directory;
  final File file;

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
