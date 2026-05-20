# App Settings Dialog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the application settings dialog from the two v2.0.0 prototype images, restore the bottom-left settings entry, and make the compact dialog expand in-place into the advanced dialog.

**Architecture:** Add a focused workbench dialog widget instead of a new route, because the prototype is a modal over the current queue. Persist settings through the existing `AppSettingsRepository` / Drift `settings` row, then apply those app defaults when new tasks are created. Keep the UI visually aligned with existing workbench dialogs while matching the prototype dimensions, spacing, and button treatment.

**Tech Stack:** Flutter, Dart, Riverpod, Drift/SQLite, `file_selector`, `flutter_test`, `build_runner`.

---

## Context And Constraints

- Use @Flutter while implementing.
- Current settings entry is already wired through `WorkbenchBottomBar.onOpenSettings`, but the button is commented in `lib/features/workbench/pages/workbench_page/bottom_bar.dart:47-52`.
- Current `WorkbenchPage` passes a placeholder dialog at `lib/features/workbench/pages/workbench_page.dart:193-198`; replace that path with the real modal.
- Existing application settings live in `lib/domain/entities/app_settings.dart`, `lib/domain/value_objects/app_compression_settings.dart`, `lib/infrastructure/database/settings.dart`, and `lib/infrastructure/repositories/drift_app_settings_repository.dart`.
- Existing persisted settings already cover default output directory, custom FFmpeg/FFprobe path, raw log switch, advanced options switch, and default output video codec. The prototype also needs default compression preset and default output filename template, so this plan adds those as first-class app settings instead of fake static controls.
- The modal should use the same visual family as `WorkbenchTaskConfigurationDialog`: white `Dialog`, 10 px radius, max width 410, compact type, grey overlay, blue save button.

## Prototype Acceptance Criteria

- Bottom bar shows `+`, settings gear, centered play button, and clear-list button.
- Clicking the gear opens a modal titled `应用设置`.
- Compact modal:
  - Width is 410 px max, white background, 10 px radius.
  - Header has left arrow and title.
  - Fields appear in this order: `默认压缩配置`, `默认导出地址`, checkbox `保存到原文件旁`, directory field, `默认导出文件名`.
  - Bottom row has orange `高级设置` button on the left, grey `取消`, blue `保存`.
- Clicking `高级设置` expands the same dialog vertically; do not close/reopen or navigate.
- Advanced modal:
  - Keeps all compact fields.
  - Adds `FFmpeg路径` and `FFprobe路径`.
  - Hides the orange `高级设置` button.
  - Keeps `取消` and `保存` aligned on the right.
- Saving persists settings. Custom FFmpeg/FFprobe paths refresh `ffmpegRuntimeProvider`.
- New tasks use app defaults for output directory, smart compression preset, output codec, and output filename template.

### Task 1: Add App Settings Fields For The Prototype

**Files:**
- Create: `lib/domain/enums/default_output_file_name_template.dart`
- Modify: `lib/domain/value_objects/app_compression_settings.dart:1-22`
- Modify: `lib/domain/entities/app_settings.dart:1-112`
- Test: `test/app_settings_test.dart`

**Step 1: Write the failing test**

Create `test/app_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

void main() {
  test('initial settings expose prototype defaults', () {
    final settings = AppSettings.initial();

    expect(settings.defaultOutputVideoCodec, VideoCodec.h264);
    expect(
      settings.defaultSmartCompressionPreset,
      SmartCompressionPreset.balanced,
    );
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.datetimeOriginalCodec,
    );
  });

  test('copyWith can clear nullable paths and update prototype fields', () {
    final settings = AppSettings.initial().copyWith(
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      customFfmpegPath: '/usr/local/bin/ffmpeg',
      defaultSmartCompressionPreset: SmartCompressionPreset.chat,
      defaultOutputVideoCodec: VideoCodec.hevc,
    );

    final cleared = settings.copyWith(
      defaultOutputDirectory: null,
      customFfmpegPath: null,
    );

    expect(cleared.defaultOutputDirectory, isNull);
    expect(cleared.customFfmpegPath, isNull);
    expect(cleared.defaultSmartCompressionPreset, SmartCompressionPreset.chat);
    expect(cleared.defaultOutputVideoCodec, VideoCodec.hevc);
  });
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/app_settings_test.dart
```

Expected: FAIL because `DefaultOutputFileNameTemplate`, `defaultSmartCompressionPreset`, and nullable clearing support do not exist.

**Step 3: Write minimal implementation**

Create `lib/domain/enums/default_output_file_name_template.dart`:

```dart
enum DefaultOutputFileNameTemplate {
  datetimeOriginalCodec;

  String get label {
    switch (this) {
      case DefaultOutputFileNameTemplate.datetimeOriginalCodec:
        return '日期时间_原文件名_编码名称';
    }
  }
}
```

Update `lib/domain/value_objects/app_compression_settings.dart`:

```dart
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';

class AppCompressionSettings {
  final VideoCodec defaultOutputVideoCodec;
  final SmartCompressionPreset defaultSmartPreset;

  const AppCompressionSettings({
    required this.defaultOutputVideoCodec,
    required this.defaultSmartPreset,
  });

  factory AppCompressionSettings.initial() {
    return const AppCompressionSettings(
      defaultOutputVideoCodec: VideoCodec.h264,
      defaultSmartPreset: SmartCompressionPreset.balanced,
    );
  }

  AppCompressionSettings copyWith({
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartPreset,
  }) {
    return AppCompressionSettings(
      defaultOutputVideoCodec:
          defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
      defaultSmartPreset: defaultSmartPreset ?? this.defaultSmartPreset,
    );
  }
}
```

Update `lib/domain/entities/app_settings.dart` with a sentinel-based `copyWith` so nullable fields can be cleared:

```dart
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/app_compression_settings.dart';

const Object _notProvided = Object();

class AppSettings {
  final String? defaultOutputDirectory;
  final String? lastSelectedOutputDirectory;
  final String? customFfmpegPath;
  final String? customFfprobePath;
  final bool showRawLog;
  final bool showAdvancedOptions;
  final AppCompressionSettings compressionSettings;
  final DefaultOutputFileNameTemplate defaultOutputFileNameTemplate;

  AppSettings({
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    this.customFfmpegPath,
    this.customFfprobePath,
    required this.showRawLog,
    required this.showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartCompressionPreset,
    this.defaultOutputFileNameTemplate =
        DefaultOutputFileNameTemplate.datetimeOriginalCodec,
  }) : compressionSettings =
           compressionSettings ??
           AppCompressionSettings(
             defaultOutputVideoCodec:
                 defaultOutputVideoCodec ??
                 AppCompressionSettings.initial().defaultOutputVideoCodec,
             defaultSmartPreset:
                 defaultSmartCompressionPreset ??
                 AppCompressionSettings.initial().defaultSmartPreset,
           );

  factory AppSettings.initial() {
    return AppSettings(
      defaultOutputDirectory: null,
      lastSelectedOutputDirectory: null,
      customFfmpegPath: null,
      customFfprobePath: null,
      showRawLog: false,
      showAdvancedOptions: false,
      compressionSettings: AppCompressionSettings.initial(),
      defaultOutputFileNameTemplate:
          DefaultOutputFileNameTemplate.datetimeOriginalCodec,
    );
  }

  AppSettings copyWith({
    Object? defaultOutputDirectory = _notProvided,
    Object? lastSelectedOutputDirectory = _notProvided,
    Object? customFfmpegPath = _notProvided,
    Object? customFfprobePath = _notProvided,
    bool? preferRawLogView,
    bool? showAdvancedOptions,
    AppCompressionSettings? compressionSettings,
    VideoCodec? defaultOutputVideoCodec,
    SmartCompressionPreset? defaultSmartCompressionPreset,
    DefaultOutputFileNameTemplate? defaultOutputFileNameTemplate,
  }) {
    return AppSettings(
      defaultOutputDirectory: identical(defaultOutputDirectory, _notProvided)
          ? this.defaultOutputDirectory
          : defaultOutputDirectory as String?,
      lastSelectedOutputDirectory:
          identical(lastSelectedOutputDirectory, _notProvided)
          ? this.lastSelectedOutputDirectory
          : lastSelectedOutputDirectory as String?,
      customFfmpegPath: identical(customFfmpegPath, _notProvided)
          ? this.customFfmpegPath
          : customFfmpegPath as String?,
      customFfprobePath: identical(customFfprobePath, _notProvided)
          ? this.customFfprobePath
          : customFfprobePath as String?,
      showRawLog: preferRawLogView ?? showRawLog,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      compressionSettings:
          compressionSettings ??
          this.compressionSettings.copyWith(
            defaultOutputVideoCodec: defaultOutputVideoCodec,
            defaultSmartPreset: defaultSmartCompressionPreset,
          ),
      defaultOutputFileNameTemplate:
          defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
    );
  }

  VideoCodec get defaultOutputVideoCodec =>
      compressionSettings.defaultOutputVideoCodec;

  SmartCompressionPreset get defaultSmartCompressionPreset =>
      compressionSettings.defaultSmartPreset;

  AppSettings withCustomFfmpegPath(String? path) {
    return copyWith(customFfmpegPath: path);
  }

  AppSettings withCustomFfprobePath(String? path) {
    return copyWith(customFfprobePath: path);
  }
}
```

**Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/app_settings_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/enums/default_output_file_name_template.dart lib/domain/value_objects/app_compression_settings.dart lib/domain/entities/app_settings.dart test/app_settings_test.dart
git commit -m "feat: extend app settings defaults"
```

### Task 2: Persist New App Settings In Drift

**Files:**
- Modify: `lib/infrastructure/database/settings.dart:1-26`
- Modify: `lib/infrastructure/database/app_database.dart:18-68`
- Modify: `lib/infrastructure/repositories/drift_app_settings_repository.dart:1-86`
- Modify generated: `lib/infrastructure/database/app_database.g.dart`
- Modify docs: `docs/develop/data-model.md:145-160`
- Test: `test/drift_app_settings_repository_test.dart`

**Step 1: Write the failing test**

Create `test/drift_app_settings_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/infrastructure/database/app_database.dart';
import 'package:machining/infrastructure/repositories/drift_app_settings_repository.dart';

void main() {
  test('settings row maps persisted prototype defaults to domain', () {
    final row = SettingsRow(
      id: 1,
      defaultOutputDirectory: '/Users/leftzhou/Desktop',
      lastSelectedOutputDirectory: null,
      customFfmpegPath: '/opt/homebrew/bin/ffmpeg',
      customFfprobePath: '/opt/homebrew/bin/ffprobe',
      showRawLog: false,
      showAdvancedOptions: false,
      defaultOutputVideoCodec: 'hevc',
      defaultCompressionSmartPreset: 'chat',
      defaultOutputFileNameTemplate: 'datetimeOriginalCodec',
      createdAt: 1,
      updatedAt: 2,
    );

    final settings = row.toDomain();

    expect(settings.defaultOutputDirectory, '/Users/leftzhou/Desktop');
    expect(settings.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(settings.defaultSmartCompressionPreset, SmartCompressionPreset.chat);
    expect(
      settings.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.datetimeOriginalCodec,
    );
  });
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/drift_app_settings_repository_test.dart
```

Expected: FAIL because generated `SettingsRow` does not have the new fields yet.

**Step 3: Write minimal implementation**

Update `lib/infrastructure/database/settings.dart`:

```dart
TextColumn get defaultCompressionSmartPreset => text()
    .named('default_compression_smart_preset')
    .withDefault(const Constant('balanced'))();
TextColumn get defaultOutputFileNameTemplate => text()
    .named('default_output_file_name_template')
    .withDefault(const Constant('datetimeOriginalCodec'))();
```

Update `lib/infrastructure/database/app_database.dart`:

```dart
@override
int get schemaVersion => 10;
```

and in `onUpgrade`:

```dart
if (from < 10) {
  await migrator.addColumn(
    settingsRows,
    settingsRows.defaultCompressionSmartPreset,
  );
  await migrator.addColumn(
    settingsRows,
    settingsRows.defaultOutputFileNameTemplate,
  );
}
```

Update `lib/infrastructure/repositories/drift_app_settings_repository.dart` imports:

```dart
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
```

Add fields to `SettingsRowsCompanion` in `saveSettings`:

```dart
defaultCompressionSmartPreset: Value(
  settings.defaultSmartCompressionPreset.name,
),
defaultOutputFileNameTemplate: Value(
  settings.defaultOutputFileNameTemplate.name,
),
```

Add fields to `SettingsRowMapper.toDomain()`:

```dart
compressionSettings: AppCompressionSettings(
  defaultOutputVideoCodec: enumValueByNameInSettings(
    VideoCodec.values,
    defaultOutputVideoCodec,
  ),
  defaultSmartPreset: enumValueByNameInSettings(
    SmartCompressionPreset.values,
    defaultCompressionSmartPreset,
  ),
),
defaultOutputFileNameTemplate: enumValueByNameInSettings(
  DefaultOutputFileNameTemplate.values,
  defaultOutputFileNameTemplate,
),
```

Run generator:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Update `docs/develop/data-model.md` settings table:

```markdown
| `default_compression_smart_preset` | text | 否 | `balanced` | `compressionSettings.defaultSmartPreset` | 新任务默认智能压缩方案 |
| `default_output_file_name_template` | text | 否 | `datetimeOriginalCodec` | `defaultOutputFileNameTemplate` | 新任务默认导出文件名模板 |
```

Update schema migration list:

```markdown
| 10 | 给 `settings` 增加默认智能压缩方案和默认导出文件名模板 |
```

**Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/app_settings_test.dart test/drift_app_settings_repository_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/infrastructure/database/settings.dart lib/infrastructure/database/app_database.dart lib/infrastructure/database/app_database.g.dart lib/infrastructure/repositories/drift_app_settings_repository.dart docs/develop/data-model.md test/drift_app_settings_repository_test.dart
git commit -m "feat: persist app settings dialog defaults"
```

### Task 3: Apply App Defaults When Creating New Tasks

**Files:**
- Modify: `lib/features/workbench/providers/media_task_notifier.dart:1-135`
- Test: `test/media_task_notifier_test.dart:1-180`

**Step 1: Write the failing test**

Add imports to `test/media_task_notifier_test.dart`:

```dart
import 'package:machining/application/repositories/app_settings_repository.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
```

Add this test inside the group:

```dart
test('creates new drafts from app settings defaults', () async {
  final repository = FakeMediaTaskRepository([]);
  final container = testContainer(
    repository: repository,
    sourceFileChecker: const FakeSourceFileChecker(
      existingPaths: {'/videos/source.mp4'},
    ),
    fingerprintReader: FakeSourceFileFingerprintReader(
      fingerprint: testFingerprint,
    ),
    appSettingsRepository: FakeAppSettingsRepository(
      AppSettings.initial().copyWith(
        defaultOutputDirectory: '/Users/leftzhou/Desktop',
        defaultOutputVideoCodec: VideoCodec.hevc,
        defaultSmartCompressionPreset: SmartCompressionPreset.chat,
        defaultOutputFileNameTemplate:
            DefaultOutputFileNameTemplate.datetimeOriginalCodec,
      ),
    ),
  );

  await container.read(mediaTaskListProvider.future);
  final task = await container
      .read(mediaTaskListProvider.notifier)
      .createDraftFromPath('/videos/source.mp4');

  expect(task.config.outputDirectory, '/Users/leftzhou/Desktop');
  expect(task.config.videoCodec, VideoCodec.hevc);
  expect(task.config.smartPreset, SmartCompressionPreset.chat);
  expect(task.config.outputFileName, contains('source'));
  expect(task.config.outputFileName.toLowerCase(), contains('hevc'));
});
```

Update `testContainer`:

```dart
ProviderContainer testContainer({
  required FakeMediaTaskRepository repository,
  required FakeSourceFileChecker sourceFileChecker,
  required FakeSourceFileFingerprintReader fingerprintReader,
  FakeAppSettingsRepository? appSettingsRepository,
}) {
  return ProviderContainer.test(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(
        appSettingsRepository ??
            FakeAppSettingsRepository(AppSettings.initial()),
      ),
      mediaTaskRepositoryProvider.overrideWithValue(repository),
      sourceFileCheckerProvider.overrideWithValue(sourceFileChecker),
      sourceFileFingerprintReaderProvider.overrideWithValue(fingerprintReader),
      ffmpegTaskQueueRunnerProvider.overrideWithValue(
        FakeFfmpegTaskQueueRunner(),
      ),
    ],
  );
}
```

Update `FakeSourceFileFingerprintReader` to support both missing-source and create-draft tests:

```dart
class FakeSourceFileFingerprintReader implements SourceFileFingerprintReader {
  FakeSourceFileFingerprintReader({this.fingerprint});

  final SourceFileFingerprint? fingerprint;
  final List<String> readPaths = [];

  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    readPaths.add(inputPath);
    final value = fingerprint;
    if (value == null) {
      throw StateError('不应该读取缺失源文件指纹: $inputPath');
    }
    return value;
  }
}

class FakeAppSettingsRepository implements AppSettingsRepository {
  FakeAppSettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/media_task_notifier_test.dart
```

Expected: FAIL because `createDraftFromPath` still uses `VideoTaskConfig.initial()`.

**Step 3: Write minimal implementation**

In `lib/features/workbench/providers/media_task_notifier.dart`, add imports:

```dart
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
```

Inside `createDraftFromPath`, load settings before creating the draft:

```dart
final settings = await ref.read(appSettingsRepositoryProvider).loadSettings();
final initialConfig = buildInitialConfigFromSettings(
  sourceFileName: path.basename(inputPath),
  settings: settings,
);
```

Pass the config into `MediaTask.draft`:

```dart
config: initialConfig,
```

Add helper functions near the bottom of the file:

```dart
VideoTaskConfig buildInitialConfigFromSettings({
  required String sourceFileName,
  required AppSettings settings,
}) {
  return VideoTaskConfig.initial().copyWith(
    outputDirectory: settings.defaultOutputDirectory ?? '',
    videoCodec: settings.defaultOutputVideoCodec,
    smartPreset: settings.defaultSmartCompressionPreset,
    outputFileName: buildDefaultOutputFileName(
      sourceFileName: sourceFileName,
      codec: settings.defaultOutputVideoCodec,
      template: settings.defaultOutputFileNameTemplate,
      now: DateTime.now(),
    ),
  );
}

String buildDefaultOutputFileName({
  required String sourceFileName,
  required VideoCodec codec,
  required DefaultOutputFileNameTemplate template,
  required DateTime now,
}) {
  switch (template) {
    case DefaultOutputFileNameTemplate.datetimeOriginalCodec:
      final dateTime = [
        now.year.toString().padLeft(4, '0'),
        now.month.toString().padLeft(2, '0'),
        now.day.toString().padLeft(2, '0'),
        now.hour.toString().padLeft(2, '0'),
        now.minute.toString().padLeft(2, '0'),
      ].join();
      final baseName = path.basenameWithoutExtension(sourceFileName).trim();
      return '${dateTime}_${baseName}_${codecFileNameToken(codec)}';
  }
}

String codecFileNameToken(VideoCodec codec) {
  switch (codec) {
    case VideoCodec.source:
      return 'source';
    case VideoCodec.h264:
      return 'h264';
    case VideoCodec.hevc:
      return 'hevc';
  }
}
```

**Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/media_task_notifier_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/workbench/providers/media_task_notifier.dart test/media_task_notifier_test.dart
git commit -m "feat: apply app defaults to new tasks"
```

### Task 4: Build The Prototype-Matching Settings Dialog Widget

**Files:**
- Create: `lib/features/workbench/pages/workbench_page/app_settings_dialog.dart`
- Test: `test/app_settings_dialog_test.dart`

**Step 1: Write the failing widget tests**

Create `test/app_settings_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/features/workbench/pages/workbench_page/app_settings_dialog.dart';

void main() {
  testWidgets('settings dialog starts in compact prototype state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial().copyWith(
              defaultOutputDirectory: '/Users/leftzhou/Desktop',
            ),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (_) async {},
            onPickOutputDirectory: () async => null,
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    );

    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('默认压缩配置'), findsOneWidget);
    expect(find.text('均衡方案'), findsOneWidget);
    expect(find.text('默认导出地址'), findsOneWidget);
    expect(find.text('/Users/leftzhou/Desktop'), findsOneWidget);
    expect(find.text('默认导出文件名'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);
    expect(find.text('FFmpeg路径'), findsNothing);
    expect(find.text('FFprobe路径'), findsNothing);
  });

  testWidgets('advanced button expands the same dialog vertically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial().copyWith(
              defaultOutputDirectory: '/Users/leftzhou/Desktop',
            ),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (_) async {},
            onPickOutputDirectory: () async => null,
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    );

    final compactHeight = tester.getSize(find.byType(Dialog)).height;

    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();

    expect(find.text('FFmpeg路径'), findsOneWidget);
    expect(find.text('FFprobe路径'), findsOneWidget);
    expect(find.text('高级设置'), findsNothing);
    expect(tester.getSize(find.byType(Dialog)).height, greaterThan(compactHeight));
  });

  testWidgets('save returns edited settings', (tester) async {
    AppSettings? savedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial(),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (settings) async {
              savedSettings = settings;
            },
            onPickOutputDirectory: () async => '/tmp/output',
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('均衡方案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('微信发送').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('/Users/leftzhou/Desktop'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(
      savedSettings!.defaultSmartCompressionPreset,
      SmartCompressionPreset.chat,
    );
    expect(savedSettings!.defaultOutputDirectory, '/tmp/output');
  });
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/app_settings_dialog_test.dart
```

Expected: FAIL because `WorkbenchAppSettingsDialog` does not exist.

**Step 3: Write minimal implementation**

Create `lib/features/workbench/pages/workbench_page/app_settings_dialog.dart`.

Core API:

```dart
typedef AppSettingsSaveCallback = Future<void> Function(AppSettings settings);
typedef AppSettingsPathPicker = Future<String?> Function();

class WorkbenchAppSettingsDialog extends StatefulWidget {
  const WorkbenchAppSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.fallbackDefaultDirectory,
    required this.onClose,
    required this.onSave,
    required this.onPickOutputDirectory,
    required this.onPickFfmpegPath,
    required this.onPickFfprobePath,
  });

  final AppSettings initialSettings;
  final String fallbackDefaultDirectory;
  final VoidCallback onClose;
  final AppSettingsSaveCallback onSave;
  final AppSettingsPathPicker onPickOutputDirectory;
  final AppSettingsPathPicker onPickFfmpegPath;
  final AppSettingsPathPicker onPickFfprobePath;
}
```

State values:

```dart
late SmartCompressionPreset _selectedPreset;
late VideoCodec _selectedCodec;
late DefaultOutputFileNameTemplate _selectedFileNameTemplate;
late TextEditingController _outputDirectoryController;
late TextEditingController _ffmpegPathController;
late TextEditingController _ffprobePathController;
late bool _saveToSourceDirectory;
bool _advancedVisible = false;
bool _saving = false;
```

Build shape:

```dart
return Dialog(
  backgroundColor: Colors.white,
  insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 410),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 22, 25, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsHeader(onClose: widget.onClose),
            const SizedBox(height: 18),
            _SettingsLabel('默认压缩配置'),
            const SizedBox(height: 8),
            _SettingsSelect<SmartCompressionPreset>(
              value: _selectedPreset,
              values: SmartCompressionPreset.values,
              labelFor: settingsPresetLabel,
              onChanged: (value) => setState(() => _selectedPreset = value),
            ),
            const SizedBox(height: 18),
            _SettingsLabel('默认导出地址'),
            const SizedBox(height: 8),
            _SaveToSourceCheckbox(
              value: _saveToSourceDirectory,
              onChanged: (value) {
                setState(() {
                  _saveToSourceDirectory = value;
                });
              },
            ),
            const SizedBox(height: 9),
            _SettingsPathField(
              controller: _outputDirectoryController,
              enabled: !_saveToSourceDirectory,
              onTap: _pickOutputDirectory,
            ),
            const SizedBox(height: 18),
            _SettingsLabel('默认导出文件名'),
            const SizedBox(height: 8),
            _SettingsSelect<DefaultOutputFileNameTemplate>(
              value: _selectedFileNameTemplate,
              values: DefaultOutputFileNameTemplate.values,
              labelFor: (value) => value.label,
              onChanged: (value) {
                setState(() => _selectedFileNameTemplate = value);
              },
            ),
            if (_advancedVisible) ...[
              const SizedBox(height: 18),
              _SettingsLabel('FFmpeg路径'),
              const SizedBox(height: 8),
              _SettingsPathField(
                controller: _ffmpegPathController,
                enabled: true,
                onTap: _pickFfmpegPath,
              ),
              const SizedBox(height: 18),
              _SettingsLabel('FFprobe路径'),
              const SizedBox(height: 8),
              _SettingsPathField(
                controller: _ffprobePathController,
                enabled: true,
                onTap: _pickFfprobePath,
              ),
            ],
            SizedBox(height: _advancedVisible ? 32 : 28),
            _SettingsActions(
              showAdvancedButton: !_advancedVisible,
              saving: _saving,
              onAdvanced: () => setState(() => _advancedVisible = true),
              onCancel: widget.onClose,
              onSave: _save,
            ),
          ],
        ),
      ),
    ),
  ),
);
```

Required visual details:

```dart
const _labelStyle = TextStyle(
  color: Color(0xFF111111),
  fontSize: 12,
  fontWeight: FontWeight.w400,
);
const _fieldHeight = 34.0;
const _fieldBorderColor = Color(0xFFE0E0E0);
const _fieldTextStyle = TextStyle(color: Color(0xFF111111), fontSize: 11);
const _mutedTextStyle = TextStyle(color: Color(0xFFB8B8B8), fontSize: 11);
const _orange = Color(0xFFFF6B00);
const _grey = Color(0xFFB8B8B8);
const _blue = Color(0xFF6290FF);
```

Use these exact button dimensions:

```dart
// advanced button
width: 75,
height: 28,
borderRadius: 8,

// cancel/save buttons
width: 75,
height: 28,
borderRadius: 8,
```

Use this label function for prototype text without changing task-dialog labels:

```dart
String settingsPresetLabel(SmartCompressionPreset value) {
  switch (value) {
    case SmartCompressionPreset.balanced:
      return '均衡方案';
    case SmartCompressionPreset.chat:
      return '微信发送';
    case SmartCompressionPreset.clear:
      return '清晰优先';
    case SmartCompressionPreset.compact:
      return '体积优先';
  }
}
```

`_save()` must trim paths and clear disabled directory:

```dart
Future<void> _save() async {
  if (_saving) {
    return;
  }
  setState(() => _saving = true);
  final outputDirectory = _saveToSourceDirectory
      ? null
      : emptyToNull(_outputDirectoryController.text);
  final ffmpegPath = emptyToNull(_ffmpegPathController.text);
  final ffprobePath = emptyToNull(_ffprobePathController.text);

  final updatedSettings = widget.initialSettings.copyWith(
    defaultOutputDirectory: outputDirectory,
    customFfmpegPath: ffmpegPath,
    customFfprobePath: ffprobePath,
    defaultSmartCompressionPreset: _selectedPreset,
    defaultOutputVideoCodec: _selectedCodec,
    defaultOutputFileNameTemplate: _selectedFileNameTemplate,
  );

  await widget.onSave(updatedSettings);
  if (mounted) {
    setState(() => _saving = false);
  }
}

String? emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
```

**Step 4: Run tests to verify they pass**

Run:

```bash
flutter test test/app_settings_dialog_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/features/workbench/pages/workbench_page/app_settings_dialog.dart test/app_settings_dialog_test.dart
git commit -m "feat: add app settings dialog UI"
```

### Task 5: Wire The Dialog Into Workbench And Restore The Gear Button

**Files:**
- Modify: `lib/features/workbench/pages/workbench_page/bottom_bar.dart:11-52`
- Modify: `lib/features/workbench/pages/workbench_page.dart:1-205`

**Step 1: Write the failing widget test**

Add to `test/app_settings_dialog_test.dart` or a new `test/workbench_bottom_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/features/workbench/pages/workbench_page/bottom_bar.dart';

void main() {
  testWidgets('bottom bar exposes settings gear', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchBottomBar(
            taskList: const AsyncData<List<MediaTask>>([]),
            hasRunningTask: false,
            queueActionInFlight: false,
            onAddTask: () {},
            onOpenSettings: () {
              opened = true;
            },
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/workbench_bottom_bar_test.dart
```

Expected: FAIL because the settings button is commented out.

**Step 3: Restore the bottom bar button**

Update `lib/features/workbench/pages/workbench_page/bottom_bar.dart`:

```dart
required this.onOpenSettings,
```

Remove `// ignore: unused_element`.

Uncomment the button:

```dart
const SizedBox(width: 12),
_DockIconButton(
  tooltip: '设置',
  icon: Icons.settings,
  onPressed: onOpenSettings,
),
```

**Step 4: Wire `WorkbenchPage` to the real dialog**

Add imports:

```dart
import 'package:machining/features/workbench/pages/workbench_page/app_settings_dialog.dart';
import 'package:machining/infrastructure/providers/drift_provider.dart';
```

Replace the placeholder at `lib/features/workbench/pages/workbench_page.dart:193-198`:

```dart
onOpenSettings: () {
  unawaited(showAppSettingsDialog());
},
```

Add this method to `_WorkbenchPageState` near `showTaskConfigurationDialog`:

```dart
Future<void> showAppSettingsDialog() async {
  final settingsRepository = ref.read(appSettingsRepositoryProvider);

  try {
    final settings = await settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return WorkbenchAppSettingsDialog(
          initialSettings: settings,
          fallbackDefaultDirectory: defaultExportPath,
          onClose: () => Navigator.of(dialogContext).pop(),
          onPickOutputDirectory: pickAppSettingsDirectory,
          onPickFfmpegPath: pickAppSettingsExecutable,
          onPickFfprobePath: pickAppSettingsExecutable,
          onSave: (updatedSettings) async {
            await saveAppSettings(updatedSettings);
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );
  } on Object catch (error) {
    showWorkbenchSnackBar('设置打开失败: $error');
  }
}

Future<String?> pickAppSettingsDirectory() {
  return getDirectoryPath(confirmButtonText: '选择导出文件夹');
}

Future<String?> pickAppSettingsExecutable() async {
  final file = await openFile();
  return file?.path;
}

Future<void> saveAppSettings(AppSettings updatedSettings) async {
  final locator = ref.read(ffmpegLocatorProvider);
  final ffmpegPath = updatedSettings.customFfmpegPath;
  final ffprobePath = updatedSettings.customFfprobePath;

  if (ffmpegPath != null && ffmpegPath.trim().isNotEmpty) {
    await locator.validateCustomFfmpegPath(ffmpegPath);
  }
  if (ffprobePath != null && ffprobePath.trim().isNotEmpty) {
    await locator.validateCustomFfprobePath(ffprobePath);
  }

  await ref.read(appSettingsRepositoryProvider).saveSettings(updatedSettings);
  ref.invalidate(ffmpegRuntimeProvider);
}
```

Also import `AppSettings`:

```dart
import 'package:machining/domain/entities/app_settings.dart';
```

**Step 5: Run tests to verify they pass**

Run:

```bash
flutter test test/workbench_bottom_bar_test.dart test/app_settings_dialog_test.dart
```

Expected: PASS.

**Step 6: Commit**

```bash
git add lib/features/workbench/pages/workbench_page/bottom_bar.dart lib/features/workbench/pages/workbench_page.dart test/workbench_bottom_bar_test.dart
git commit -m "feat: wire app settings dialog"
```

### Task 6: Polish Layout Against The Prototype

**Files:**
- Modify: `lib/features/workbench/pages/workbench_page/app_settings_dialog.dart`
- Optional Test: `test/app_settings_dialog_test.dart`

**Step 1: Add layout guard tests**

Extend `test/app_settings_dialog_test.dart`:

```dart
testWidgets('settings dialog keeps prototype width and button sizes', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial().copyWith(
              defaultOutputDirectory: '/Users/leftzhou/Desktop',
            ),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (_) async {},
            onPickOutputDirectory: () async => null,
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    ),
  );

  final dialogSize = tester.getSize(find.byType(Dialog));
  expect(dialogSize.width, lessThanOrEqualTo(410));

  expect(tester.getSize(find.text('保存')), const Size(75, 28));
  expect(tester.getSize(find.text('取消')), const Size(75, 28));
  expect(tester.getSize(find.text('高级设置')), const Size(75, 28));
});
```

If text widgets do not directly report button sizes, add keys to the buttons:

```dart
static const saveButtonKey = Key('app-settings-save-button');
static const cancelButtonKey = Key('app-settings-cancel-button');
static const advancedButtonKey = Key('app-settings-advanced-button');
```

Then assert by key.

**Step 2: Run test to verify it fails if dimensions are off**

Run:

```bash
flutter test test/app_settings_dialog_test.dart
```

Expected: PASS after keys/dimensions are correct; fix if not.

**Step 3: Manual visual run**

Run:

```bash
flutter run -d macos
```

Manual checks:

- App opens with the same workbench backdrop seen in the prototype.
- Gear is bottom-left next to `+`.
- Compact dialog visually matches Image #1.
- Click `高级设置`; the dialog grows to match Image #2.
- Cancel closes without saving.
- Save closes after persisting.

**Step 4: Commit**

```bash
git add lib/features/workbench/pages/workbench_page/app_settings_dialog.dart test/app_settings_dialog_test.dart
git commit -m "style: match app settings prototype"
```

### Task 7: Final Verification

**Files:**
- All touched files.

**Step 1: Format**

Run:

```bash
dart format lib/domain lib/infrastructure lib/features test
```

Expected: files are formatted without errors.

**Step 2: Run focused tests**

Run:

```bash
flutter test test/app_settings_test.dart test/drift_app_settings_repository_test.dart test/media_task_notifier_test.dart test/app_settings_dialog_test.dart test/workbench_bottom_bar_test.dart
```

Expected: PASS.

**Step 3: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS.

**Step 4: Analyze**

Run:

```bash
flutter analyze
```

Expected: No issues.

**Step 5: Manual smoke test**

Run:

```bash
flutter run -d macos
```

Expected:

- Gear opens the settings dialog.
- `高级设置` expands the existing modal.
- Picking an output directory fills the directory field.
- Picking invalid FFmpeg/FFprobe executable shows the existing workbench notice through `showWorkbenchSnackBar`.
- Saving valid values persists them; reopening the dialog shows the saved values.
- Creating a new task applies the saved default output directory, smart preset, codec, and filename template.

**Step 6: Commit**

```bash
git status --short
git add lib test docs/develop/data-model.md
git commit -m "test: verify app settings dialog"
```

## Implementation Notes

- Keep the settings modal under `workbench_page/` because it is a workbench modal, not a standalone settings route.
- Do not remove `/settings` in `lib/app/app_router.dart`; it can remain a placeholder unless product scope later asks for a route-based settings page.
- Do not expose CPU/GPU controls in this dialog. Keep current GPU-first automatic behavior internal.
- Keep the orange `高级设置` button only in compact mode; advanced mode should show only `取消` and `保存`.
- Prefer `AnimatedSize` for the height transition. It matches the requested "弹窗变高" behavior while keeping state in one widget.
- Keep all user-facing strings exactly as the prototype unless validation messages come from existing services.
