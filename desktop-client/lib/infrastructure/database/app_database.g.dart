// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsRowsTable extends SettingsRows
    with TableInfo<$SettingsRowsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultOutputDirectoryMeta =
      const VerificationMeta('defaultOutputDirectory');
  @override
  late final GeneratedColumn<String> defaultOutputDirectory =
      GeneratedColumn<String>(
        'default_output_directory',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSelectedOutputDirectoryMeta =
      const VerificationMeta('lastSelectedOutputDirectory');
  @override
  late final GeneratedColumn<String> lastSelectedOutputDirectory =
      GeneratedColumn<String>(
        'last_selected_output_directory',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _saveOutputToSourceDirectoryMeta =
      const VerificationMeta('saveOutputToSourceDirectory');
  @override
  late final GeneratedColumn<bool> saveOutputToSourceDirectory =
      GeneratedColumn<bool>(
        'save_output_to_source_directory',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("save_output_to_source_directory" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _showRawLogMeta = const VerificationMeta(
    'showRawLog',
  );
  @override
  late final GeneratedColumn<bool> showRawLog = GeneratedColumn<bool>(
    'show_raw_log',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_raw_log" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showAdvancedOptionsMeta =
      const VerificationMeta('showAdvancedOptions');
  @override
  late final GeneratedColumn<bool> showAdvancedOptions = GeneratedColumn<bool>(
    'show_advanced_options',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_advanced_options" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _defaultOutputVideoCodecMeta =
      const VerificationMeta('defaultOutputVideoCodec');
  @override
  late final GeneratedColumn<String> defaultOutputVideoCodec =
      GeneratedColumn<String>(
        'default_output_video_codec',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('h264'),
      );
  static const VerificationMeta _defaultCompressionSmartPresetMeta =
      const VerificationMeta('defaultCompressionSmartPreset');
  @override
  late final GeneratedColumn<String> defaultCompressionSmartPreset =
      GeneratedColumn<String>(
        'default_compression_smart_preset',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('chat'),
      );
  static const VerificationMeta _defaultOutputFileNameTemplateMeta =
      const VerificationMeta('defaultOutputFileNameTemplate');
  @override
  late final GeneratedColumn<String> defaultOutputFileNameTemplate =
      GeneratedColumn<String>(
        'default_output_file_name_template',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{source}-{action}'),
      );
  static const VerificationMeta _defaultMediaConfigJsonMeta =
      const VerificationMeta('defaultMediaConfigJson');
  @override
  late final GeneratedColumn<String> defaultMediaConfigJson =
      GeneratedColumn<String>(
        'default_media_config_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _hideNotificationBadgeMeta =
      const VerificationMeta('hideNotificationBadge');
  @override
  late final GeneratedColumn<bool> hideNotificationBadge =
      GeneratedColumn<bool>(
        'hide_notification_badge',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("hide_notification_badge" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _showTaskCompletionDialogMeta =
      const VerificationMeta('showTaskCompletionDialog');
  @override
  late final GeneratedColumn<bool> showTaskCompletionDialog =
      GeneratedColumn<bool>(
        'show_task_completion_dialog',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("show_task_completion_dialog" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _taskCompletionSoundMeta =
      const VerificationMeta('taskCompletionSound');
  @override
  late final GeneratedColumn<String> taskCompletionSound =
      GeneratedColumn<String>(
        'task_completion_sound',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('clean_success'),
      );
  static const VerificationMeta _folderImportScanDepthMeta =
      const VerificationMeta('folderImportScanDepth');
  @override
  late final GeneratedColumn<int> folderImportScanDepth = GeneratedColumn<int>(
    'folder_import_scan_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _notificationPoliciesJsonMeta =
      const VerificationMeta('notificationPoliciesJson');
  @override
  late final GeneratedColumn<String> notificationPoliciesJson =
      GeneratedColumn<String>(
        'notification_policies_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _shortcutBindingsJsonMeta =
      const VerificationMeta('shortcutBindingsJson');
  @override
  late final GeneratedColumn<String> shortcutBindingsJson =
      GeneratedColumn<String>(
        'shortcut_bindings_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _closeBehaviorMeta = const VerificationMeta(
    'closeBehavior',
  );
  @override
  late final GeneratedColumn<String> closeBehavior = GeneratedColumn<String>(
    'close_behavior',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('background'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    defaultOutputDirectory,
    lastSelectedOutputDirectory,
    saveOutputToSourceDirectory,
    showRawLog,
    showAdvancedOptions,
    defaultOutputVideoCodec,
    defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate,
    defaultMediaConfigJson,
    themeMode,
    hideNotificationBadge,
    showTaskCompletionDialog,
    taskCompletionSound,
    folderImportScanDepth,
    notificationPoliciesJson,
    shortcutBindingsJson,
    closeBehavior,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('default_output_directory')) {
      context.handle(
        _defaultOutputDirectoryMeta,
        defaultOutputDirectory.isAcceptableOrUnknown(
          data['default_output_directory']!,
          _defaultOutputDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('last_selected_output_directory')) {
      context.handle(
        _lastSelectedOutputDirectoryMeta,
        lastSelectedOutputDirectory.isAcceptableOrUnknown(
          data['last_selected_output_directory']!,
          _lastSelectedOutputDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('save_output_to_source_directory')) {
      context.handle(
        _saveOutputToSourceDirectoryMeta,
        saveOutputToSourceDirectory.isAcceptableOrUnknown(
          data['save_output_to_source_directory']!,
          _saveOutputToSourceDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('show_raw_log')) {
      context.handle(
        _showRawLogMeta,
        showRawLog.isAcceptableOrUnknown(
          data['show_raw_log']!,
          _showRawLogMeta,
        ),
      );
    }
    if (data.containsKey('show_advanced_options')) {
      context.handle(
        _showAdvancedOptionsMeta,
        showAdvancedOptions.isAcceptableOrUnknown(
          data['show_advanced_options']!,
          _showAdvancedOptionsMeta,
        ),
      );
    }
    if (data.containsKey('default_output_video_codec')) {
      context.handle(
        _defaultOutputVideoCodecMeta,
        defaultOutputVideoCodec.isAcceptableOrUnknown(
          data['default_output_video_codec']!,
          _defaultOutputVideoCodecMeta,
        ),
      );
    }
    if (data.containsKey('default_compression_smart_preset')) {
      context.handle(
        _defaultCompressionSmartPresetMeta,
        defaultCompressionSmartPreset.isAcceptableOrUnknown(
          data['default_compression_smart_preset']!,
          _defaultCompressionSmartPresetMeta,
        ),
      );
    }
    if (data.containsKey('default_output_file_name_template')) {
      context.handle(
        _defaultOutputFileNameTemplateMeta,
        defaultOutputFileNameTemplate.isAcceptableOrUnknown(
          data['default_output_file_name_template']!,
          _defaultOutputFileNameTemplateMeta,
        ),
      );
    }
    if (data.containsKey('default_media_config_json')) {
      context.handle(
        _defaultMediaConfigJsonMeta,
        defaultMediaConfigJson.isAcceptableOrUnknown(
          data['default_media_config_json']!,
          _defaultMediaConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('hide_notification_badge')) {
      context.handle(
        _hideNotificationBadgeMeta,
        hideNotificationBadge.isAcceptableOrUnknown(
          data['hide_notification_badge']!,
          _hideNotificationBadgeMeta,
        ),
      );
    }
    if (data.containsKey('show_task_completion_dialog')) {
      context.handle(
        _showTaskCompletionDialogMeta,
        showTaskCompletionDialog.isAcceptableOrUnknown(
          data['show_task_completion_dialog']!,
          _showTaskCompletionDialogMeta,
        ),
      );
    }
    if (data.containsKey('task_completion_sound')) {
      context.handle(
        _taskCompletionSoundMeta,
        taskCompletionSound.isAcceptableOrUnknown(
          data['task_completion_sound']!,
          _taskCompletionSoundMeta,
        ),
      );
    }
    if (data.containsKey('folder_import_scan_depth')) {
      context.handle(
        _folderImportScanDepthMeta,
        folderImportScanDepth.isAcceptableOrUnknown(
          data['folder_import_scan_depth']!,
          _folderImportScanDepthMeta,
        ),
      );
    }
    if (data.containsKey('notification_policies_json')) {
      context.handle(
        _notificationPoliciesJsonMeta,
        notificationPoliciesJson.isAcceptableOrUnknown(
          data['notification_policies_json']!,
          _notificationPoliciesJsonMeta,
        ),
      );
    }
    if (data.containsKey('shortcut_bindings_json')) {
      context.handle(
        _shortcutBindingsJsonMeta,
        shortcutBindingsJson.isAcceptableOrUnknown(
          data['shortcut_bindings_json']!,
          _shortcutBindingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('close_behavior')) {
      context.handle(
        _closeBehaviorMeta,
        closeBehavior.isAcceptableOrUnknown(
          data['close_behavior']!,
          _closeBehaviorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      defaultOutputDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_output_directory'],
      ),
      lastSelectedOutputDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_selected_output_directory'],
      ),
      saveOutputToSourceDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}save_output_to_source_directory'],
      )!,
      showRawLog: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_raw_log'],
      )!,
      showAdvancedOptions: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_advanced_options'],
      )!,
      defaultOutputVideoCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_output_video_codec'],
      )!,
      defaultCompressionSmartPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_compression_smart_preset'],
      )!,
      defaultOutputFileNameTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_output_file_name_template'],
      )!,
      defaultMediaConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_media_config_json'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      hideNotificationBadge: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hide_notification_badge'],
      )!,
      showTaskCompletionDialog: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_task_completion_dialog'],
      )!,
      taskCompletionSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_completion_sound'],
      )!,
      folderImportScanDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_import_scan_depth'],
      )!,
      notificationPoliciesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_policies_json'],
      )!,
      shortcutBindingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shortcut_bindings_json'],
      )!,
      closeBehavior: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}close_behavior'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsRowsTable createAlias(String alias) {
    return $SettingsRowsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;
  final String? defaultOutputDirectory;
  final String? lastSelectedOutputDirectory;
  final bool saveOutputToSourceDirectory;
  final bool showRawLog;
  final bool showAdvancedOptions;
  final String defaultOutputVideoCodec;
  final String defaultCompressionSmartPreset;
  final String defaultOutputFileNameTemplate;
  final String? defaultMediaConfigJson;
  final String themeMode;
  final bool hideNotificationBadge;
  final bool showTaskCompletionDialog;
  final String taskCompletionSound;
  final int folderImportScanDepth;
  final String notificationPoliciesJson;
  final String shortcutBindingsJson;
  final String closeBehavior;
  final int createdAt;
  final int updatedAt;
  const SettingsRow({
    required this.id,
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    required this.saveOutputToSourceDirectory,
    required this.showRawLog,
    required this.showAdvancedOptions,
    required this.defaultOutputVideoCodec,
    required this.defaultCompressionSmartPreset,
    required this.defaultOutputFileNameTemplate,
    this.defaultMediaConfigJson,
    required this.themeMode,
    required this.hideNotificationBadge,
    required this.showTaskCompletionDialog,
    required this.taskCompletionSound,
    required this.folderImportScanDepth,
    required this.notificationPoliciesJson,
    required this.shortcutBindingsJson,
    required this.closeBehavior,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || defaultOutputDirectory != null) {
      map['default_output_directory'] = Variable<String>(
        defaultOutputDirectory,
      );
    }
    if (!nullToAbsent || lastSelectedOutputDirectory != null) {
      map['last_selected_output_directory'] = Variable<String>(
        lastSelectedOutputDirectory,
      );
    }
    map['save_output_to_source_directory'] = Variable<bool>(
      saveOutputToSourceDirectory,
    );
    map['show_raw_log'] = Variable<bool>(showRawLog);
    map['show_advanced_options'] = Variable<bool>(showAdvancedOptions);
    map['default_output_video_codec'] = Variable<String>(
      defaultOutputVideoCodec,
    );
    map['default_compression_smart_preset'] = Variable<String>(
      defaultCompressionSmartPreset,
    );
    map['default_output_file_name_template'] = Variable<String>(
      defaultOutputFileNameTemplate,
    );
    if (!nullToAbsent || defaultMediaConfigJson != null) {
      map['default_media_config_json'] = Variable<String>(
        defaultMediaConfigJson,
      );
    }
    map['theme_mode'] = Variable<String>(themeMode);
    map['hide_notification_badge'] = Variable<bool>(hideNotificationBadge);
    map['show_task_completion_dialog'] = Variable<bool>(
      showTaskCompletionDialog,
    );
    map['task_completion_sound'] = Variable<String>(taskCompletionSound);
    map['folder_import_scan_depth'] = Variable<int>(folderImportScanDepth);
    map['notification_policies_json'] = Variable<String>(
      notificationPoliciesJson,
    );
    map['shortcut_bindings_json'] = Variable<String>(shortcutBindingsJson);
    map['close_behavior'] = Variable<String>(closeBehavior);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return SettingsRowsCompanion(
      id: Value(id),
      defaultOutputDirectory: defaultOutputDirectory == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultOutputDirectory),
      lastSelectedOutputDirectory:
          lastSelectedOutputDirectory == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSelectedOutputDirectory),
      saveOutputToSourceDirectory: Value(saveOutputToSourceDirectory),
      showRawLog: Value(showRawLog),
      showAdvancedOptions: Value(showAdvancedOptions),
      defaultOutputVideoCodec: Value(defaultOutputVideoCodec),
      defaultCompressionSmartPreset: Value(defaultCompressionSmartPreset),
      defaultOutputFileNameTemplate: Value(defaultOutputFileNameTemplate),
      defaultMediaConfigJson: defaultMediaConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultMediaConfigJson),
      themeMode: Value(themeMode),
      hideNotificationBadge: Value(hideNotificationBadge),
      showTaskCompletionDialog: Value(showTaskCompletionDialog),
      taskCompletionSound: Value(taskCompletionSound),
      folderImportScanDepth: Value(folderImportScanDepth),
      notificationPoliciesJson: Value(notificationPoliciesJson),
      shortcutBindingsJson: Value(shortcutBindingsJson),
      closeBehavior: Value(closeBehavior),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      defaultOutputDirectory: serializer.fromJson<String?>(
        json['defaultOutputDirectory'],
      ),
      lastSelectedOutputDirectory: serializer.fromJson<String?>(
        json['lastSelectedOutputDirectory'],
      ),
      saveOutputToSourceDirectory: serializer.fromJson<bool>(
        json['saveOutputToSourceDirectory'],
      ),
      showRawLog: serializer.fromJson<bool>(json['showRawLog']),
      showAdvancedOptions: serializer.fromJson<bool>(
        json['showAdvancedOptions'],
      ),
      defaultOutputVideoCodec: serializer.fromJson<String>(
        json['defaultOutputVideoCodec'],
      ),
      defaultCompressionSmartPreset: serializer.fromJson<String>(
        json['defaultCompressionSmartPreset'],
      ),
      defaultOutputFileNameTemplate: serializer.fromJson<String>(
        json['defaultOutputFileNameTemplate'],
      ),
      defaultMediaConfigJson: serializer.fromJson<String?>(
        json['defaultMediaConfigJson'],
      ),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      hideNotificationBadge: serializer.fromJson<bool>(
        json['hideNotificationBadge'],
      ),
      showTaskCompletionDialog: serializer.fromJson<bool>(
        json['showTaskCompletionDialog'],
      ),
      taskCompletionSound: serializer.fromJson<String>(
        json['taskCompletionSound'],
      ),
      folderImportScanDepth: serializer.fromJson<int>(
        json['folderImportScanDepth'],
      ),
      notificationPoliciesJson: serializer.fromJson<String>(
        json['notificationPoliciesJson'],
      ),
      shortcutBindingsJson: serializer.fromJson<String>(
        json['shortcutBindingsJson'],
      ),
      closeBehavior: serializer.fromJson<String>(json['closeBehavior']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'defaultOutputDirectory': serializer.toJson<String?>(
        defaultOutputDirectory,
      ),
      'lastSelectedOutputDirectory': serializer.toJson<String?>(
        lastSelectedOutputDirectory,
      ),
      'saveOutputToSourceDirectory': serializer.toJson<bool>(
        saveOutputToSourceDirectory,
      ),
      'showRawLog': serializer.toJson<bool>(showRawLog),
      'showAdvancedOptions': serializer.toJson<bool>(showAdvancedOptions),
      'defaultOutputVideoCodec': serializer.toJson<String>(
        defaultOutputVideoCodec,
      ),
      'defaultCompressionSmartPreset': serializer.toJson<String>(
        defaultCompressionSmartPreset,
      ),
      'defaultOutputFileNameTemplate': serializer.toJson<String>(
        defaultOutputFileNameTemplate,
      ),
      'defaultMediaConfigJson': serializer.toJson<String?>(
        defaultMediaConfigJson,
      ),
      'themeMode': serializer.toJson<String>(themeMode),
      'hideNotificationBadge': serializer.toJson<bool>(hideNotificationBadge),
      'showTaskCompletionDialog': serializer.toJson<bool>(
        showTaskCompletionDialog,
      ),
      'taskCompletionSound': serializer.toJson<String>(taskCompletionSound),
      'folderImportScanDepth': serializer.toJson<int>(folderImportScanDepth),
      'notificationPoliciesJson': serializer.toJson<String>(
        notificationPoliciesJson,
      ),
      'shortcutBindingsJson': serializer.toJson<String>(shortcutBindingsJson),
      'closeBehavior': serializer.toJson<String>(closeBehavior),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SettingsRow copyWith({
    int? id,
    Value<String?> defaultOutputDirectory = const Value.absent(),
    Value<String?> lastSelectedOutputDirectory = const Value.absent(),
    bool? saveOutputToSourceDirectory,
    bool? showRawLog,
    bool? showAdvancedOptions,
    String? defaultOutputVideoCodec,
    String? defaultCompressionSmartPreset,
    String? defaultOutputFileNameTemplate,
    Value<String?> defaultMediaConfigJson = const Value.absent(),
    String? themeMode,
    bool? hideNotificationBadge,
    bool? showTaskCompletionDialog,
    String? taskCompletionSound,
    int? folderImportScanDepth,
    String? notificationPoliciesJson,
    String? shortcutBindingsJson,
    String? closeBehavior,
    int? createdAt,
    int? updatedAt,
  }) => SettingsRow(
    id: id ?? this.id,
    defaultOutputDirectory: defaultOutputDirectory.present
        ? defaultOutputDirectory.value
        : this.defaultOutputDirectory,
    lastSelectedOutputDirectory: lastSelectedOutputDirectory.present
        ? lastSelectedOutputDirectory.value
        : this.lastSelectedOutputDirectory,
    saveOutputToSourceDirectory:
        saveOutputToSourceDirectory ?? this.saveOutputToSourceDirectory,
    showRawLog: showRawLog ?? this.showRawLog,
    showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
    defaultOutputVideoCodec:
        defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
    defaultCompressionSmartPreset:
        defaultCompressionSmartPreset ?? this.defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate:
        defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
    defaultMediaConfigJson: defaultMediaConfigJson.present
        ? defaultMediaConfigJson.value
        : this.defaultMediaConfigJson,
    themeMode: themeMode ?? this.themeMode,
    hideNotificationBadge: hideNotificationBadge ?? this.hideNotificationBadge,
    showTaskCompletionDialog:
        showTaskCompletionDialog ?? this.showTaskCompletionDialog,
    taskCompletionSound: taskCompletionSound ?? this.taskCompletionSound,
    folderImportScanDepth: folderImportScanDepth ?? this.folderImportScanDepth,
    notificationPoliciesJson:
        notificationPoliciesJson ?? this.notificationPoliciesJson,
    shortcutBindingsJson: shortcutBindingsJson ?? this.shortcutBindingsJson,
    closeBehavior: closeBehavior ?? this.closeBehavior,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SettingsRow copyWithCompanion(SettingsRowsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      defaultOutputDirectory: data.defaultOutputDirectory.present
          ? data.defaultOutputDirectory.value
          : this.defaultOutputDirectory,
      lastSelectedOutputDirectory: data.lastSelectedOutputDirectory.present
          ? data.lastSelectedOutputDirectory.value
          : this.lastSelectedOutputDirectory,
      saveOutputToSourceDirectory: data.saveOutputToSourceDirectory.present
          ? data.saveOutputToSourceDirectory.value
          : this.saveOutputToSourceDirectory,
      showRawLog: data.showRawLog.present
          ? data.showRawLog.value
          : this.showRawLog,
      showAdvancedOptions: data.showAdvancedOptions.present
          ? data.showAdvancedOptions.value
          : this.showAdvancedOptions,
      defaultOutputVideoCodec: data.defaultOutputVideoCodec.present
          ? data.defaultOutputVideoCodec.value
          : this.defaultOutputVideoCodec,
      defaultCompressionSmartPreset: data.defaultCompressionSmartPreset.present
          ? data.defaultCompressionSmartPreset.value
          : this.defaultCompressionSmartPreset,
      defaultOutputFileNameTemplate: data.defaultOutputFileNameTemplate.present
          ? data.defaultOutputFileNameTemplate.value
          : this.defaultOutputFileNameTemplate,
      defaultMediaConfigJson: data.defaultMediaConfigJson.present
          ? data.defaultMediaConfigJson.value
          : this.defaultMediaConfigJson,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      hideNotificationBadge: data.hideNotificationBadge.present
          ? data.hideNotificationBadge.value
          : this.hideNotificationBadge,
      showTaskCompletionDialog: data.showTaskCompletionDialog.present
          ? data.showTaskCompletionDialog.value
          : this.showTaskCompletionDialog,
      taskCompletionSound: data.taskCompletionSound.present
          ? data.taskCompletionSound.value
          : this.taskCompletionSound,
      folderImportScanDepth: data.folderImportScanDepth.present
          ? data.folderImportScanDepth.value
          : this.folderImportScanDepth,
      notificationPoliciesJson: data.notificationPoliciesJson.present
          ? data.notificationPoliciesJson.value
          : this.notificationPoliciesJson,
      shortcutBindingsJson: data.shortcutBindingsJson.present
          ? data.shortcutBindingsJson.value
          : this.shortcutBindingsJson,
      closeBehavior: data.closeBehavior.present
          ? data.closeBehavior.value
          : this.closeBehavior,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('defaultOutputDirectory: $defaultOutputDirectory, ')
          ..write('lastSelectedOutputDirectory: $lastSelectedOutputDirectory, ')
          ..write('saveOutputToSourceDirectory: $saveOutputToSourceDirectory, ')
          ..write('showRawLog: $showRawLog, ')
          ..write('showAdvancedOptions: $showAdvancedOptions, ')
          ..write('defaultOutputVideoCodec: $defaultOutputVideoCodec, ')
          ..write(
            'defaultCompressionSmartPreset: $defaultCompressionSmartPreset, ',
          )
          ..write(
            'defaultOutputFileNameTemplate: $defaultOutputFileNameTemplate, ',
          )
          ..write('defaultMediaConfigJson: $defaultMediaConfigJson, ')
          ..write('themeMode: $themeMode, ')
          ..write('hideNotificationBadge: $hideNotificationBadge, ')
          ..write('showTaskCompletionDialog: $showTaskCompletionDialog, ')
          ..write('taskCompletionSound: $taskCompletionSound, ')
          ..write('folderImportScanDepth: $folderImportScanDepth, ')
          ..write('notificationPoliciesJson: $notificationPoliciesJson, ')
          ..write('shortcutBindingsJson: $shortcutBindingsJson, ')
          ..write('closeBehavior: $closeBehavior, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    defaultOutputDirectory,
    lastSelectedOutputDirectory,
    saveOutputToSourceDirectory,
    showRawLog,
    showAdvancedOptions,
    defaultOutputVideoCodec,
    defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate,
    defaultMediaConfigJson,
    themeMode,
    hideNotificationBadge,
    showTaskCompletionDialog,
    taskCompletionSound,
    folderImportScanDepth,
    notificationPoliciesJson,
    shortcutBindingsJson,
    closeBehavior,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.defaultOutputDirectory == this.defaultOutputDirectory &&
          other.lastSelectedOutputDirectory ==
              this.lastSelectedOutputDirectory &&
          other.saveOutputToSourceDirectory ==
              this.saveOutputToSourceDirectory &&
          other.showRawLog == this.showRawLog &&
          other.showAdvancedOptions == this.showAdvancedOptions &&
          other.defaultOutputVideoCodec == this.defaultOutputVideoCodec &&
          other.defaultCompressionSmartPreset ==
              this.defaultCompressionSmartPreset &&
          other.defaultOutputFileNameTemplate ==
              this.defaultOutputFileNameTemplate &&
          other.defaultMediaConfigJson == this.defaultMediaConfigJson &&
          other.themeMode == this.themeMode &&
          other.hideNotificationBadge == this.hideNotificationBadge &&
          other.showTaskCompletionDialog == this.showTaskCompletionDialog &&
          other.taskCompletionSound == this.taskCompletionSound &&
          other.folderImportScanDepth == this.folderImportScanDepth &&
          other.notificationPoliciesJson == this.notificationPoliciesJson &&
          other.shortcutBindingsJson == this.shortcutBindingsJson &&
          other.closeBehavior == this.closeBehavior &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String?> defaultOutputDirectory;
  final Value<String?> lastSelectedOutputDirectory;
  final Value<bool> saveOutputToSourceDirectory;
  final Value<bool> showRawLog;
  final Value<bool> showAdvancedOptions;
  final Value<String> defaultOutputVideoCodec;
  final Value<String> defaultCompressionSmartPreset;
  final Value<String> defaultOutputFileNameTemplate;
  final Value<String?> defaultMediaConfigJson;
  final Value<String> themeMode;
  final Value<bool> hideNotificationBadge;
  final Value<bool> showTaskCompletionDialog;
  final Value<String> taskCompletionSound;
  final Value<int> folderImportScanDepth;
  final Value<String> notificationPoliciesJson;
  final Value<String> shortcutBindingsJson;
  final Value<String> closeBehavior;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const SettingsRowsCompanion({
    this.id = const Value.absent(),
    this.defaultOutputDirectory = const Value.absent(),
    this.lastSelectedOutputDirectory = const Value.absent(),
    this.saveOutputToSourceDirectory = const Value.absent(),
    this.showRawLog = const Value.absent(),
    this.showAdvancedOptions = const Value.absent(),
    this.defaultOutputVideoCodec = const Value.absent(),
    this.defaultCompressionSmartPreset = const Value.absent(),
    this.defaultOutputFileNameTemplate = const Value.absent(),
    this.defaultMediaConfigJson = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.hideNotificationBadge = const Value.absent(),
    this.showTaskCompletionDialog = const Value.absent(),
    this.taskCompletionSound = const Value.absent(),
    this.folderImportScanDepth = const Value.absent(),
    this.notificationPoliciesJson = const Value.absent(),
    this.shortcutBindingsJson = const Value.absent(),
    this.closeBehavior = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    this.id = const Value.absent(),
    this.defaultOutputDirectory = const Value.absent(),
    this.lastSelectedOutputDirectory = const Value.absent(),
    this.saveOutputToSourceDirectory = const Value.absent(),
    this.showRawLog = const Value.absent(),
    this.showAdvancedOptions = const Value.absent(),
    this.defaultOutputVideoCodec = const Value.absent(),
    this.defaultCompressionSmartPreset = const Value.absent(),
    this.defaultOutputFileNameTemplate = const Value.absent(),
    this.defaultMediaConfigJson = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.hideNotificationBadge = const Value.absent(),
    this.showTaskCompletionDialog = const Value.absent(),
    this.taskCompletionSound = const Value.absent(),
    this.folderImportScanDepth = const Value.absent(),
    this.notificationPoliciesJson = const Value.absent(),
    this.shortcutBindingsJson = const Value.absent(),
    this.closeBehavior = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? defaultOutputDirectory,
    Expression<String>? lastSelectedOutputDirectory,
    Expression<bool>? saveOutputToSourceDirectory,
    Expression<bool>? showRawLog,
    Expression<bool>? showAdvancedOptions,
    Expression<String>? defaultOutputVideoCodec,
    Expression<String>? defaultCompressionSmartPreset,
    Expression<String>? defaultOutputFileNameTemplate,
    Expression<String>? defaultMediaConfigJson,
    Expression<String>? themeMode,
    Expression<bool>? hideNotificationBadge,
    Expression<bool>? showTaskCompletionDialog,
    Expression<String>? taskCompletionSound,
    Expression<int>? folderImportScanDepth,
    Expression<String>? notificationPoliciesJson,
    Expression<String>? shortcutBindingsJson,
    Expression<String>? closeBehavior,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (defaultOutputDirectory != null)
        'default_output_directory': defaultOutputDirectory,
      if (lastSelectedOutputDirectory != null)
        'last_selected_output_directory': lastSelectedOutputDirectory,
      if (saveOutputToSourceDirectory != null)
        'save_output_to_source_directory': saveOutputToSourceDirectory,
      if (showRawLog != null) 'show_raw_log': showRawLog,
      if (showAdvancedOptions != null)
        'show_advanced_options': showAdvancedOptions,
      if (defaultOutputVideoCodec != null)
        'default_output_video_codec': defaultOutputVideoCodec,
      if (defaultCompressionSmartPreset != null)
        'default_compression_smart_preset': defaultCompressionSmartPreset,
      if (defaultOutputFileNameTemplate != null)
        'default_output_file_name_template': defaultOutputFileNameTemplate,
      if (defaultMediaConfigJson != null)
        'default_media_config_json': defaultMediaConfigJson,
      if (themeMode != null) 'theme_mode': themeMode,
      if (hideNotificationBadge != null)
        'hide_notification_badge': hideNotificationBadge,
      if (showTaskCompletionDialog != null)
        'show_task_completion_dialog': showTaskCompletionDialog,
      if (taskCompletionSound != null)
        'task_completion_sound': taskCompletionSound,
      if (folderImportScanDepth != null)
        'folder_import_scan_depth': folderImportScanDepth,
      if (notificationPoliciesJson != null)
        'notification_policies_json': notificationPoliciesJson,
      if (shortcutBindingsJson != null)
        'shortcut_bindings_json': shortcutBindingsJson,
      if (closeBehavior != null) 'close_behavior': closeBehavior,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<int>? id,
    Value<String?>? defaultOutputDirectory,
    Value<String?>? lastSelectedOutputDirectory,
    Value<bool>? saveOutputToSourceDirectory,
    Value<bool>? showRawLog,
    Value<bool>? showAdvancedOptions,
    Value<String>? defaultOutputVideoCodec,
    Value<String>? defaultCompressionSmartPreset,
    Value<String>? defaultOutputFileNameTemplate,
    Value<String?>? defaultMediaConfigJson,
    Value<String>? themeMode,
    Value<bool>? hideNotificationBadge,
    Value<bool>? showTaskCompletionDialog,
    Value<String>? taskCompletionSound,
    Value<int>? folderImportScanDepth,
    Value<String>? notificationPoliciesJson,
    Value<String>? shortcutBindingsJson,
    Value<String>? closeBehavior,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return SettingsRowsCompanion(
      id: id ?? this.id,
      defaultOutputDirectory:
          defaultOutputDirectory ?? this.defaultOutputDirectory,
      lastSelectedOutputDirectory:
          lastSelectedOutputDirectory ?? this.lastSelectedOutputDirectory,
      saveOutputToSourceDirectory:
          saveOutputToSourceDirectory ?? this.saveOutputToSourceDirectory,
      showRawLog: showRawLog ?? this.showRawLog,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      defaultOutputVideoCodec:
          defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
      defaultCompressionSmartPreset:
          defaultCompressionSmartPreset ?? this.defaultCompressionSmartPreset,
      defaultOutputFileNameTemplate:
          defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
      defaultMediaConfigJson:
          defaultMediaConfigJson ?? this.defaultMediaConfigJson,
      themeMode: themeMode ?? this.themeMode,
      hideNotificationBadge:
          hideNotificationBadge ?? this.hideNotificationBadge,
      showTaskCompletionDialog:
          showTaskCompletionDialog ?? this.showTaskCompletionDialog,
      taskCompletionSound: taskCompletionSound ?? this.taskCompletionSound,
      folderImportScanDepth:
          folderImportScanDepth ?? this.folderImportScanDepth,
      notificationPoliciesJson:
          notificationPoliciesJson ?? this.notificationPoliciesJson,
      shortcutBindingsJson: shortcutBindingsJson ?? this.shortcutBindingsJson,
      closeBehavior: closeBehavior ?? this.closeBehavior,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (defaultOutputDirectory.present) {
      map['default_output_directory'] = Variable<String>(
        defaultOutputDirectory.value,
      );
    }
    if (lastSelectedOutputDirectory.present) {
      map['last_selected_output_directory'] = Variable<String>(
        lastSelectedOutputDirectory.value,
      );
    }
    if (saveOutputToSourceDirectory.present) {
      map['save_output_to_source_directory'] = Variable<bool>(
        saveOutputToSourceDirectory.value,
      );
    }
    if (showRawLog.present) {
      map['show_raw_log'] = Variable<bool>(showRawLog.value);
    }
    if (showAdvancedOptions.present) {
      map['show_advanced_options'] = Variable<bool>(showAdvancedOptions.value);
    }
    if (defaultOutputVideoCodec.present) {
      map['default_output_video_codec'] = Variable<String>(
        defaultOutputVideoCodec.value,
      );
    }
    if (defaultCompressionSmartPreset.present) {
      map['default_compression_smart_preset'] = Variable<String>(
        defaultCompressionSmartPreset.value,
      );
    }
    if (defaultOutputFileNameTemplate.present) {
      map['default_output_file_name_template'] = Variable<String>(
        defaultOutputFileNameTemplate.value,
      );
    }
    if (defaultMediaConfigJson.present) {
      map['default_media_config_json'] = Variable<String>(
        defaultMediaConfigJson.value,
      );
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (hideNotificationBadge.present) {
      map['hide_notification_badge'] = Variable<bool>(
        hideNotificationBadge.value,
      );
    }
    if (showTaskCompletionDialog.present) {
      map['show_task_completion_dialog'] = Variable<bool>(
        showTaskCompletionDialog.value,
      );
    }
    if (taskCompletionSound.present) {
      map['task_completion_sound'] = Variable<String>(
        taskCompletionSound.value,
      );
    }
    if (folderImportScanDepth.present) {
      map['folder_import_scan_depth'] = Variable<int>(
        folderImportScanDepth.value,
      );
    }
    if (notificationPoliciesJson.present) {
      map['notification_policies_json'] = Variable<String>(
        notificationPoliciesJson.value,
      );
    }
    if (shortcutBindingsJson.present) {
      map['shortcut_bindings_json'] = Variable<String>(
        shortcutBindingsJson.value,
      );
    }
    if (closeBehavior.present) {
      map['close_behavior'] = Variable<String>(closeBehavior.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('defaultOutputDirectory: $defaultOutputDirectory, ')
          ..write('lastSelectedOutputDirectory: $lastSelectedOutputDirectory, ')
          ..write('saveOutputToSourceDirectory: $saveOutputToSourceDirectory, ')
          ..write('showRawLog: $showRawLog, ')
          ..write('showAdvancedOptions: $showAdvancedOptions, ')
          ..write('defaultOutputVideoCodec: $defaultOutputVideoCodec, ')
          ..write(
            'defaultCompressionSmartPreset: $defaultCompressionSmartPreset, ',
          )
          ..write(
            'defaultOutputFileNameTemplate: $defaultOutputFileNameTemplate, ',
          )
          ..write('defaultMediaConfigJson: $defaultMediaConfigJson, ')
          ..write('themeMode: $themeMode, ')
          ..write('hideNotificationBadge: $hideNotificationBadge, ')
          ..write('showTaskCompletionDialog: $showTaskCompletionDialog, ')
          ..write('taskCompletionSound: $taskCompletionSound, ')
          ..write('folderImportScanDepth: $folderImportScanDepth, ')
          ..write('notificationPoliciesJson: $notificationPoliciesJson, ')
          ..write('shortcutBindingsJson: $shortcutBindingsJson, ')
          ..write('closeBehavior: $closeBehavior, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TaskRowsTable extends TaskRows with TableInfo<$TaskRowsTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputPathMeta = const VerificationMeta(
    'inputPath',
  );
  @override
  late final GeneratedColumn<String> inputPath = GeneratedColumn<String>(
    'input_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('video'),
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderSortOrderMeta = const VerificationMeta(
    'folderSortOrder',
  );
  @override
  late final GeneratedColumn<int> folderSortOrder = GeneratedColumn<int>(
    'folder_sort_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputPathMeta = const VerificationMeta(
    'outputPath',
  );
  @override
  late final GeneratedColumn<String> outputPath = GeneratedColumn<String>(
    'output_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputFileSizeMeta = const VerificationMeta(
    'outputFileSize',
  );
  @override
  late final GeneratedColumn<int> outputFileSize = GeneratedColumn<int>(
    'output_file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureJsonMeta = const VerificationMeta(
    'failureJson',
  );
  @override
  late final GeneratedColumn<String> failureJson = GeneratedColumn<String>(
    'failure_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policyTagsJsonMeta = const VerificationMeta(
    'policyTagsJson',
  );
  @override
  late final GeneratedColumn<String> policyTagsJson = GeneratedColumn<String>(
    'policy_tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFileSizeMeta = const VerificationMeta(
    'sourceFileSize',
  );
  @override
  late final GeneratedColumn<int> sourceFileSize = GeneratedColumn<int>(
    'source_file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceLastModifiedAtMeta =
      const VerificationMeta('sourceLastModifiedAt');
  @override
  late final GeneratedColumn<int> sourceLastModifiedAt = GeneratedColumn<int>(
    'source_last_modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisDurationMsMeta =
      const VerificationMeta('analysisDurationMs');
  @override
  late final GeneratedColumn<int> analysisDurationMs = GeneratedColumn<int>(
    'analysis_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisVideoWidthMeta =
      const VerificationMeta('analysisVideoWidth');
  @override
  late final GeneratedColumn<int> analysisVideoWidth = GeneratedColumn<int>(
    'analysis_video_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisVideoHeightMeta =
      const VerificationMeta('analysisVideoHeight');
  @override
  late final GeneratedColumn<int> analysisVideoHeight = GeneratedColumn<int>(
    'analysis_video_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisVideoCodecMeta =
      const VerificationMeta('analysisVideoCodec');
  @override
  late final GeneratedColumn<String> analysisVideoCodec =
      GeneratedColumn<String>(
        'analysis_video_codec',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAudioCodecMeta =
      const VerificationMeta('analysisAudioCodec');
  @override
  late final GeneratedColumn<String> analysisAudioCodec =
      GeneratedColumn<String>(
        'analysis_audio_codec',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisVideoPixelFormatMeta =
      const VerificationMeta('analysisVideoPixelFormat');
  @override
  late final GeneratedColumn<String> analysisVideoPixelFormat =
      GeneratedColumn<String>(
        'analysis_video_pixel_format',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisVideoBitDepthMeta =
      const VerificationMeta('analysisVideoBitDepth');
  @override
  late final GeneratedColumn<int> analysisVideoBitDepth = GeneratedColumn<int>(
    'analysis_video_bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisColorRangeMeta =
      const VerificationMeta('analysisColorRange');
  @override
  late final GeneratedColumn<String> analysisColorRange =
      GeneratedColumn<String>(
        'analysis_color_range',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisColorSpaceMeta =
      const VerificationMeta('analysisColorSpace');
  @override
  late final GeneratedColumn<String> analysisColorSpace =
      GeneratedColumn<String>(
        'analysis_color_space',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisColorTransferMeta =
      const VerificationMeta('analysisColorTransfer');
  @override
  late final GeneratedColumn<String> analysisColorTransfer =
      GeneratedColumn<String>(
        'analysis_color_transfer',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisColorPrimariesMeta =
      const VerificationMeta('analysisColorPrimaries');
  @override
  late final GeneratedColumn<String> analysisColorPrimaries =
      GeneratedColumn<String>(
        'analysis_color_primaries',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisChromaLocationMeta =
      const VerificationMeta('analysisChromaLocation');
  @override
  late final GeneratedColumn<String> analysisChromaLocation =
      GeneratedColumn<String>(
        'analysis_chroma_location',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisMasteringDisplayMetadataMeta =
      const VerificationMeta('analysisMasteringDisplayMetadata');
  @override
  late final GeneratedColumn<String> analysisMasteringDisplayMetadata =
      GeneratedColumn<String>(
        'analysis_mastering_display_metadata',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisMasteringDisplayMaxLuminanceMeta =
      const VerificationMeta('analysisMasteringDisplayMaxLuminance');
  @override
  late final GeneratedColumn<double> analysisMasteringDisplayMaxLuminance =
      GeneratedColumn<double>(
        'analysis_mastering_display_max_luminance',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisMaxContentLightLevelMeta =
      const VerificationMeta('analysisMaxContentLightLevel');
  @override
  late final GeneratedColumn<int> analysisMaxContentLightLevel =
      GeneratedColumn<int>(
        'analysis_max_content_light_level',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisMaxFrameAverageLightLevelMeta =
      const VerificationMeta('analysisMaxFrameAverageLightLevel');
  @override
  late final GeneratedColumn<int> analysisMaxFrameAverageLightLevel =
      GeneratedColumn<int>(
        'analysis_max_frame_average_light_level',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisDolbyVisionProfileMeta =
      const VerificationMeta('analysisDolbyVisionProfile');
  @override
  late final GeneratedColumn<int> analysisDolbyVisionProfile =
      GeneratedColumn<int>(
        'analysis_dolby_vision_profile',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisDolbyVisionCompatibilityIdMeta =
      const VerificationMeta('analysisDolbyVisionCompatibilityId');
  @override
  late final GeneratedColumn<int> analysisDolbyVisionCompatibilityId =
      GeneratedColumn<int>(
        'analysis_dolby_vision_compatibility_id',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAverageFrameRateMeta =
      const VerificationMeta('analysisAverageFrameRate');
  @override
  late final GeneratedColumn<String> analysisAverageFrameRate =
      GeneratedColumn<String>(
        'analysis_average_frame_rate',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisRealFrameRateMeta =
      const VerificationMeta('analysisRealFrameRate');
  @override
  late final GeneratedColumn<String> analysisRealFrameRate =
      GeneratedColumn<String>(
        'analysis_real_frame_rate',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisSampleAspectRatioMeta =
      const VerificationMeta('analysisSampleAspectRatio');
  @override
  late final GeneratedColumn<String> analysisSampleAspectRatio =
      GeneratedColumn<String>(
        'analysis_sample_aspect_ratio',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisDisplayAspectRatioMeta =
      const VerificationMeta('analysisDisplayAspectRatio');
  @override
  late final GeneratedColumn<String> analysisDisplayAspectRatio =
      GeneratedColumn<String>(
        'analysis_display_aspect_ratio',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisVideoRotationDegreesMeta =
      const VerificationMeta('analysisVideoRotationDegrees');
  @override
  late final GeneratedColumn<int> analysisVideoRotationDegrees =
      GeneratedColumn<int>(
        'analysis_video_rotation_degrees',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisFieldOrderMeta =
      const VerificationMeta('analysisFieldOrder');
  @override
  late final GeneratedColumn<String> analysisFieldOrder =
      GeneratedColumn<String>(
        'analysis_field_order',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisVideoBitrateMeta =
      const VerificationMeta('analysisVideoBitrate');
  @override
  late final GeneratedColumn<int> analysisVideoBitrate = GeneratedColumn<int>(
    'analysis_video_bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisAudioBitrateMeta =
      const VerificationMeta('analysisAudioBitrate');
  @override
  late final GeneratedColumn<int> analysisAudioBitrate = GeneratedColumn<int>(
    'analysis_audio_bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisContainerBitrateMeta =
      const VerificationMeta('analysisContainerBitrate');
  @override
  late final GeneratedColumn<int> analysisContainerBitrate =
      GeneratedColumn<int>(
        'analysis_container_bitrate',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisEstimatedBitrateMeta =
      const VerificationMeta('analysisEstimatedBitrate');
  @override
  late final GeneratedColumn<int> analysisEstimatedBitrate =
      GeneratedColumn<int>(
        'analysis_estimated_bitrate',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisContainerFormatMeta =
      const VerificationMeta('analysisContainerFormat');
  @override
  late final GeneratedColumn<String> analysisContainerFormat =
      GeneratedColumn<String>(
        'analysis_container_format',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAudioChannelsMeta =
      const VerificationMeta('analysisAudioChannels');
  @override
  late final GeneratedColumn<int> analysisAudioChannels = GeneratedColumn<int>(
    'analysis_audio_channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisAudioSampleRateMeta =
      const VerificationMeta('analysisAudioSampleRate');
  @override
  late final GeneratedColumn<int> analysisAudioSampleRate =
      GeneratedColumn<int>(
        'analysis_audio_sample_rate',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAudioChannelLayoutMeta =
      const VerificationMeta('analysisAudioChannelLayout');
  @override
  late final GeneratedColumn<String> analysisAudioChannelLayout =
      GeneratedColumn<String>(
        'analysis_audio_channel_layout',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAudioStreamIndexMeta =
      const VerificationMeta('analysisAudioStreamIndex');
  @override
  late final GeneratedColumn<int> analysisAudioStreamIndex =
      GeneratedColumn<int>(
        'analysis_audio_stream_index',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisAudioStreamsJsonMeta =
      const VerificationMeta('analysisAudioStreamsJson');
  @override
  late final GeneratedColumn<String> analysisAudioStreamsJson =
      GeneratedColumn<String>(
        'analysis_audio_streams_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _mediaConfigJsonMeta = const VerificationMeta(
    'mediaConfigJson',
  );
  @override
  late final GeneratedColumn<String> mediaConfigJson = GeneratedColumn<String>(
    'media_config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisImageWidthMeta =
      const VerificationMeta('analysisImageWidth');
  @override
  late final GeneratedColumn<int> analysisImageWidth = GeneratedColumn<int>(
    'analysis_image_width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisImageHeightMeta =
      const VerificationMeta('analysisImageHeight');
  @override
  late final GeneratedColumn<int> analysisImageHeight = GeneratedColumn<int>(
    'analysis_image_height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisImageCodecMeta =
      const VerificationMeta('analysisImageCodec');
  @override
  late final GeneratedColumn<String> analysisImageCodec =
      GeneratedColumn<String>(
        'analysis_image_codec',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisImagePixelFormatMeta =
      const VerificationMeta('analysisImagePixelFormat');
  @override
  late final GeneratedColumn<String> analysisImagePixelFormat =
      GeneratedColumn<String>(
        'analysis_image_pixel_format',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisImageBitDepthMeta =
      const VerificationMeta('analysisImageBitDepth');
  @override
  late final GeneratedColumn<int> analysisImageBitDepth = GeneratedColumn<int>(
    'analysis_image_bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisUpdatedAtMeta = const VerificationMeta(
    'analysisUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> analysisUpdatedAt = GeneratedColumn<int>(
    'analysis_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisErrorMessageMeta =
      const VerificationMeta('analysisErrorMessage');
  @override
  late final GeneratedColumn<String> analysisErrorMessage =
      GeneratedColumn<String>(
        'analysis_error_message',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _outputFormatMeta = const VerificationMeta(
    'outputFormat',
  );
  @override
  late final GeneratedColumn<String> outputFormat = GeneratedColumn<String>(
    'output_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoCodecMeta = const VerificationMeta(
    'videoCodec',
  );
  @override
  late final GeneratedColumn<String> videoCodec = GeneratedColumn<String>(
    'video_codec',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encoderBackendMeta = const VerificationMeta(
    'encoderBackend',
  );
  @override
  late final GeneratedColumn<String> encoderBackend = GeneratedColumn<String>(
    'encoder_backend',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolutionPresetMeta = const VerificationMeta(
    'resolutionPreset',
  );
  @override
  late final GeneratedColumn<String> resolutionPreset = GeneratedColumn<String>(
    'resolution_preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputDirectoryMeta = const VerificationMeta(
    'outputDirectory',
  );
  @override
  late final GeneratedColumn<String> outputDirectory = GeneratedColumn<String>(
    'output_directory',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compressionCrfMeta = const VerificationMeta(
    'compressionCrf',
  );
  @override
  late final GeneratedColumn<int> compressionCrf = GeneratedColumn<int>(
    'compression_crf',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(28),
  );
  static const VerificationMeta _compressionModeMeta = const VerificationMeta(
    'compressionMode',
  );
  @override
  late final GeneratedColumn<String> compressionMode = GeneratedColumn<String>(
    'compression_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('preset'),
  );
  static const VerificationMeta _smartPresetMeta = const VerificationMeta(
    'smartPreset',
  );
  @override
  late final GeneratedColumn<String> smartPreset = GeneratedColumn<String>(
    'smart_preset',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetSizeBytesMeta = const VerificationMeta(
    'targetSizeBytes',
  );
  @override
  late final GeneratedColumn<int> targetSizeBytes = GeneratedColumn<int>(
    'target_size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetSizeRatioMeta = const VerificationMeta(
    'targetSizeRatio',
  );
  @override
  late final GeneratedColumn<double> targetSizeRatio = GeneratedColumn<double>(
    'target_size_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputFileNameMeta = const VerificationMeta(
    'outputFileName',
  );
  @override
  late final GeneratedColumn<String> outputFileName = GeneratedColumn<String>(
    'output_file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedAtMeta = const VerificationMeta(
    'failedAt',
  );
  @override
  late final GeneratedColumn<int> failedAt = GeneratedColumn<int>(
    'failed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    inputPath,
    fileName,
    mediaKind,
    purpose,
    status,
    progress,
    sortOrder,
    folderId,
    folderSortOrder,
    outputPath,
    outputFileSize,
    errorMessage,
    failureJson,
    policyTagsJson,
    sourceFileSize,
    sourceLastModifiedAt,
    analysisDurationMs,
    analysisVideoWidth,
    analysisVideoHeight,
    analysisVideoCodec,
    analysisAudioCodec,
    analysisVideoPixelFormat,
    analysisVideoBitDepth,
    analysisColorRange,
    analysisColorSpace,
    analysisColorTransfer,
    analysisColorPrimaries,
    analysisChromaLocation,
    analysisMasteringDisplayMetadata,
    analysisMasteringDisplayMaxLuminance,
    analysisMaxContentLightLevel,
    analysisMaxFrameAverageLightLevel,
    analysisDolbyVisionProfile,
    analysisDolbyVisionCompatibilityId,
    analysisAverageFrameRate,
    analysisRealFrameRate,
    analysisSampleAspectRatio,
    analysisDisplayAspectRatio,
    analysisVideoRotationDegrees,
    analysisFieldOrder,
    analysisVideoBitrate,
    analysisAudioBitrate,
    analysisContainerBitrate,
    analysisEstimatedBitrate,
    analysisContainerFormat,
    analysisAudioChannels,
    analysisAudioSampleRate,
    analysisAudioChannelLayout,
    analysisAudioStreamIndex,
    analysisAudioStreamsJson,
    mediaConfigJson,
    analysisImageWidth,
    analysisImageHeight,
    analysisImageCodec,
    analysisImagePixelFormat,
    analysisImageBitDepth,
    analysisUpdatedAt,
    analysisErrorMessage,
    outputFormat,
    videoCodec,
    encoderBackend,
    resolutionPreset,
    outputDirectory,
    compressionCrf,
    compressionMode,
    smartPreset,
    targetSizeBytes,
    targetSizeRatio,
    outputFileName,
    createdAt,
    startedAt,
    completedAt,
    failedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('input_path')) {
      context.handle(
        _inputPathMeta,
        inputPath.isAcceptableOrUnknown(data['input_path']!, _inputPathMeta),
      );
    } else if (isInserting) {
      context.missing(_inputPathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    } else if (isInserting) {
      context.missing(_purposeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('folder_sort_order')) {
      context.handle(
        _folderSortOrderMeta,
        folderSortOrder.isAcceptableOrUnknown(
          data['folder_sort_order']!,
          _folderSortOrderMeta,
        ),
      );
    }
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
      );
    }
    if (data.containsKey('output_file_size')) {
      context.handle(
        _outputFileSizeMeta,
        outputFileSize.isAcceptableOrUnknown(
          data['output_file_size']!,
          _outputFileSizeMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('failure_json')) {
      context.handle(
        _failureJsonMeta,
        failureJson.isAcceptableOrUnknown(
          data['failure_json']!,
          _failureJsonMeta,
        ),
      );
    }
    if (data.containsKey('policy_tags_json')) {
      context.handle(
        _policyTagsJsonMeta,
        policyTagsJson.isAcceptableOrUnknown(
          data['policy_tags_json']!,
          _policyTagsJsonMeta,
        ),
      );
    }
    if (data.containsKey('source_file_size')) {
      context.handle(
        _sourceFileSizeMeta,
        sourceFileSize.isAcceptableOrUnknown(
          data['source_file_size']!,
          _sourceFileSizeMeta,
        ),
      );
    }
    if (data.containsKey('source_last_modified_at')) {
      context.handle(
        _sourceLastModifiedAtMeta,
        sourceLastModifiedAt.isAcceptableOrUnknown(
          data['source_last_modified_at']!,
          _sourceLastModifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('analysis_duration_ms')) {
      context.handle(
        _analysisDurationMsMeta,
        analysisDurationMs.isAcceptableOrUnknown(
          data['analysis_duration_ms']!,
          _analysisDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_width')) {
      context.handle(
        _analysisVideoWidthMeta,
        analysisVideoWidth.isAcceptableOrUnknown(
          data['analysis_video_width']!,
          _analysisVideoWidthMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_height')) {
      context.handle(
        _analysisVideoHeightMeta,
        analysisVideoHeight.isAcceptableOrUnknown(
          data['analysis_video_height']!,
          _analysisVideoHeightMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_codec')) {
      context.handle(
        _analysisVideoCodecMeta,
        analysisVideoCodec.isAcceptableOrUnknown(
          data['analysis_video_codec']!,
          _analysisVideoCodecMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_codec')) {
      context.handle(
        _analysisAudioCodecMeta,
        analysisAudioCodec.isAcceptableOrUnknown(
          data['analysis_audio_codec']!,
          _analysisAudioCodecMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_pixel_format')) {
      context.handle(
        _analysisVideoPixelFormatMeta,
        analysisVideoPixelFormat.isAcceptableOrUnknown(
          data['analysis_video_pixel_format']!,
          _analysisVideoPixelFormatMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_bit_depth')) {
      context.handle(
        _analysisVideoBitDepthMeta,
        analysisVideoBitDepth.isAcceptableOrUnknown(
          data['analysis_video_bit_depth']!,
          _analysisVideoBitDepthMeta,
        ),
      );
    }
    if (data.containsKey('analysis_color_range')) {
      context.handle(
        _analysisColorRangeMeta,
        analysisColorRange.isAcceptableOrUnknown(
          data['analysis_color_range']!,
          _analysisColorRangeMeta,
        ),
      );
    }
    if (data.containsKey('analysis_color_space')) {
      context.handle(
        _analysisColorSpaceMeta,
        analysisColorSpace.isAcceptableOrUnknown(
          data['analysis_color_space']!,
          _analysisColorSpaceMeta,
        ),
      );
    }
    if (data.containsKey('analysis_color_transfer')) {
      context.handle(
        _analysisColorTransferMeta,
        analysisColorTransfer.isAcceptableOrUnknown(
          data['analysis_color_transfer']!,
          _analysisColorTransferMeta,
        ),
      );
    }
    if (data.containsKey('analysis_color_primaries')) {
      context.handle(
        _analysisColorPrimariesMeta,
        analysisColorPrimaries.isAcceptableOrUnknown(
          data['analysis_color_primaries']!,
          _analysisColorPrimariesMeta,
        ),
      );
    }
    if (data.containsKey('analysis_chroma_location')) {
      context.handle(
        _analysisChromaLocationMeta,
        analysisChromaLocation.isAcceptableOrUnknown(
          data['analysis_chroma_location']!,
          _analysisChromaLocationMeta,
        ),
      );
    }
    if (data.containsKey('analysis_mastering_display_metadata')) {
      context.handle(
        _analysisMasteringDisplayMetadataMeta,
        analysisMasteringDisplayMetadata.isAcceptableOrUnknown(
          data['analysis_mastering_display_metadata']!,
          _analysisMasteringDisplayMetadataMeta,
        ),
      );
    }
    if (data.containsKey('analysis_mastering_display_max_luminance')) {
      context.handle(
        _analysisMasteringDisplayMaxLuminanceMeta,
        analysisMasteringDisplayMaxLuminance.isAcceptableOrUnknown(
          data['analysis_mastering_display_max_luminance']!,
          _analysisMasteringDisplayMaxLuminanceMeta,
        ),
      );
    }
    if (data.containsKey('analysis_max_content_light_level')) {
      context.handle(
        _analysisMaxContentLightLevelMeta,
        analysisMaxContentLightLevel.isAcceptableOrUnknown(
          data['analysis_max_content_light_level']!,
          _analysisMaxContentLightLevelMeta,
        ),
      );
    }
    if (data.containsKey('analysis_max_frame_average_light_level')) {
      context.handle(
        _analysisMaxFrameAverageLightLevelMeta,
        analysisMaxFrameAverageLightLevel.isAcceptableOrUnknown(
          data['analysis_max_frame_average_light_level']!,
          _analysisMaxFrameAverageLightLevelMeta,
        ),
      );
    }
    if (data.containsKey('analysis_dolby_vision_profile')) {
      context.handle(
        _analysisDolbyVisionProfileMeta,
        analysisDolbyVisionProfile.isAcceptableOrUnknown(
          data['analysis_dolby_vision_profile']!,
          _analysisDolbyVisionProfileMeta,
        ),
      );
    }
    if (data.containsKey('analysis_dolby_vision_compatibility_id')) {
      context.handle(
        _analysisDolbyVisionCompatibilityIdMeta,
        analysisDolbyVisionCompatibilityId.isAcceptableOrUnknown(
          data['analysis_dolby_vision_compatibility_id']!,
          _analysisDolbyVisionCompatibilityIdMeta,
        ),
      );
    }
    if (data.containsKey('analysis_average_frame_rate')) {
      context.handle(
        _analysisAverageFrameRateMeta,
        analysisAverageFrameRate.isAcceptableOrUnknown(
          data['analysis_average_frame_rate']!,
          _analysisAverageFrameRateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_real_frame_rate')) {
      context.handle(
        _analysisRealFrameRateMeta,
        analysisRealFrameRate.isAcceptableOrUnknown(
          data['analysis_real_frame_rate']!,
          _analysisRealFrameRateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_sample_aspect_ratio')) {
      context.handle(
        _analysisSampleAspectRatioMeta,
        analysisSampleAspectRatio.isAcceptableOrUnknown(
          data['analysis_sample_aspect_ratio']!,
          _analysisSampleAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('analysis_display_aspect_ratio')) {
      context.handle(
        _analysisDisplayAspectRatioMeta,
        analysisDisplayAspectRatio.isAcceptableOrUnknown(
          data['analysis_display_aspect_ratio']!,
          _analysisDisplayAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_rotation_degrees')) {
      context.handle(
        _analysisVideoRotationDegreesMeta,
        analysisVideoRotationDegrees.isAcceptableOrUnknown(
          data['analysis_video_rotation_degrees']!,
          _analysisVideoRotationDegreesMeta,
        ),
      );
    }
    if (data.containsKey('analysis_field_order')) {
      context.handle(
        _analysisFieldOrderMeta,
        analysisFieldOrder.isAcceptableOrUnknown(
          data['analysis_field_order']!,
          _analysisFieldOrderMeta,
        ),
      );
    }
    if (data.containsKey('analysis_video_bitrate')) {
      context.handle(
        _analysisVideoBitrateMeta,
        analysisVideoBitrate.isAcceptableOrUnknown(
          data['analysis_video_bitrate']!,
          _analysisVideoBitrateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_bitrate')) {
      context.handle(
        _analysisAudioBitrateMeta,
        analysisAudioBitrate.isAcceptableOrUnknown(
          data['analysis_audio_bitrate']!,
          _analysisAudioBitrateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_container_bitrate')) {
      context.handle(
        _analysisContainerBitrateMeta,
        analysisContainerBitrate.isAcceptableOrUnknown(
          data['analysis_container_bitrate']!,
          _analysisContainerBitrateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_estimated_bitrate')) {
      context.handle(
        _analysisEstimatedBitrateMeta,
        analysisEstimatedBitrate.isAcceptableOrUnknown(
          data['analysis_estimated_bitrate']!,
          _analysisEstimatedBitrateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_container_format')) {
      context.handle(
        _analysisContainerFormatMeta,
        analysisContainerFormat.isAcceptableOrUnknown(
          data['analysis_container_format']!,
          _analysisContainerFormatMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_channels')) {
      context.handle(
        _analysisAudioChannelsMeta,
        analysisAudioChannels.isAcceptableOrUnknown(
          data['analysis_audio_channels']!,
          _analysisAudioChannelsMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_sample_rate')) {
      context.handle(
        _analysisAudioSampleRateMeta,
        analysisAudioSampleRate.isAcceptableOrUnknown(
          data['analysis_audio_sample_rate']!,
          _analysisAudioSampleRateMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_channel_layout')) {
      context.handle(
        _analysisAudioChannelLayoutMeta,
        analysisAudioChannelLayout.isAcceptableOrUnknown(
          data['analysis_audio_channel_layout']!,
          _analysisAudioChannelLayoutMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_stream_index')) {
      context.handle(
        _analysisAudioStreamIndexMeta,
        analysisAudioStreamIndex.isAcceptableOrUnknown(
          data['analysis_audio_stream_index']!,
          _analysisAudioStreamIndexMeta,
        ),
      );
    }
    if (data.containsKey('analysis_audio_streams_json')) {
      context.handle(
        _analysisAudioStreamsJsonMeta,
        analysisAudioStreamsJson.isAcceptableOrUnknown(
          data['analysis_audio_streams_json']!,
          _analysisAudioStreamsJsonMeta,
        ),
      );
    }
    if (data.containsKey('media_config_json')) {
      context.handle(
        _mediaConfigJsonMeta,
        mediaConfigJson.isAcceptableOrUnknown(
          data['media_config_json']!,
          _mediaConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('analysis_image_width')) {
      context.handle(
        _analysisImageWidthMeta,
        analysisImageWidth.isAcceptableOrUnknown(
          data['analysis_image_width']!,
          _analysisImageWidthMeta,
        ),
      );
    }
    if (data.containsKey('analysis_image_height')) {
      context.handle(
        _analysisImageHeightMeta,
        analysisImageHeight.isAcceptableOrUnknown(
          data['analysis_image_height']!,
          _analysisImageHeightMeta,
        ),
      );
    }
    if (data.containsKey('analysis_image_codec')) {
      context.handle(
        _analysisImageCodecMeta,
        analysisImageCodec.isAcceptableOrUnknown(
          data['analysis_image_codec']!,
          _analysisImageCodecMeta,
        ),
      );
    }
    if (data.containsKey('analysis_image_pixel_format')) {
      context.handle(
        _analysisImagePixelFormatMeta,
        analysisImagePixelFormat.isAcceptableOrUnknown(
          data['analysis_image_pixel_format']!,
          _analysisImagePixelFormatMeta,
        ),
      );
    }
    if (data.containsKey('analysis_image_bit_depth')) {
      context.handle(
        _analysisImageBitDepthMeta,
        analysisImageBitDepth.isAcceptableOrUnknown(
          data['analysis_image_bit_depth']!,
          _analysisImageBitDepthMeta,
        ),
      );
    }
    if (data.containsKey('analysis_updated_at')) {
      context.handle(
        _analysisUpdatedAtMeta,
        analysisUpdatedAt.isAcceptableOrUnknown(
          data['analysis_updated_at']!,
          _analysisUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('analysis_error_message')) {
      context.handle(
        _analysisErrorMessageMeta,
        analysisErrorMessage.isAcceptableOrUnknown(
          data['analysis_error_message']!,
          _analysisErrorMessageMeta,
        ),
      );
    }
    if (data.containsKey('output_format')) {
      context.handle(
        _outputFormatMeta,
        outputFormat.isAcceptableOrUnknown(
          data['output_format']!,
          _outputFormatMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputFormatMeta);
    }
    if (data.containsKey('video_codec')) {
      context.handle(
        _videoCodecMeta,
        videoCodec.isAcceptableOrUnknown(data['video_codec']!, _videoCodecMeta),
      );
    } else if (isInserting) {
      context.missing(_videoCodecMeta);
    }
    if (data.containsKey('encoder_backend')) {
      context.handle(
        _encoderBackendMeta,
        encoderBackend.isAcceptableOrUnknown(
          data['encoder_backend']!,
          _encoderBackendMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encoderBackendMeta);
    }
    if (data.containsKey('resolution_preset')) {
      context.handle(
        _resolutionPresetMeta,
        resolutionPreset.isAcceptableOrUnknown(
          data['resolution_preset']!,
          _resolutionPresetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resolutionPresetMeta);
    }
    if (data.containsKey('output_directory')) {
      context.handle(
        _outputDirectoryMeta,
        outputDirectory.isAcceptableOrUnknown(
          data['output_directory']!,
          _outputDirectoryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outputDirectoryMeta);
    }
    if (data.containsKey('compression_crf')) {
      context.handle(
        _compressionCrfMeta,
        compressionCrf.isAcceptableOrUnknown(
          data['compression_crf']!,
          _compressionCrfMeta,
        ),
      );
    }
    if (data.containsKey('compression_mode')) {
      context.handle(
        _compressionModeMeta,
        compressionMode.isAcceptableOrUnknown(
          data['compression_mode']!,
          _compressionModeMeta,
        ),
      );
    }
    if (data.containsKey('smart_preset')) {
      context.handle(
        _smartPresetMeta,
        smartPreset.isAcceptableOrUnknown(
          data['smart_preset']!,
          _smartPresetMeta,
        ),
      );
    }
    if (data.containsKey('target_size_bytes')) {
      context.handle(
        _targetSizeBytesMeta,
        targetSizeBytes.isAcceptableOrUnknown(
          data['target_size_bytes']!,
          _targetSizeBytesMeta,
        ),
      );
    }
    if (data.containsKey('target_size_ratio')) {
      context.handle(
        _targetSizeRatioMeta,
        targetSizeRatio.isAcceptableOrUnknown(
          data['target_size_ratio']!,
          _targetSizeRatioMeta,
        ),
      );
    }
    if (data.containsKey('output_file_name')) {
      context.handle(
        _outputFileNameMeta,
        outputFileName.isAcceptableOrUnknown(
          data['output_file_name']!,
          _outputFileNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('failed_at')) {
      context.handle(
        _failedAtMeta,
        failedAt.isAcceptableOrUnknown(data['failed_at']!, _failedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      inputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      folderSortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_sort_order'],
      ),
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      outputFileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_file_size'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      failureJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_json'],
      ),
      policyTagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_tags_json'],
      ),
      sourceFileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_file_size'],
      ),
      sourceLastModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_last_modified_at'],
      ),
      analysisDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_duration_ms'],
      ),
      analysisVideoWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_video_width'],
      ),
      analysisVideoHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_video_height'],
      ),
      analysisVideoCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_video_codec'],
      ),
      analysisAudioCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_audio_codec'],
      ),
      analysisVideoPixelFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_video_pixel_format'],
      ),
      analysisVideoBitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_video_bit_depth'],
      ),
      analysisColorRange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_color_range'],
      ),
      analysisColorSpace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_color_space'],
      ),
      analysisColorTransfer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_color_transfer'],
      ),
      analysisColorPrimaries: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_color_primaries'],
      ),
      analysisChromaLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_chroma_location'],
      ),
      analysisMasteringDisplayMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_mastering_display_metadata'],
      ),
      analysisMasteringDisplayMaxLuminance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}analysis_mastering_display_max_luminance'],
      ),
      analysisMaxContentLightLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_max_content_light_level'],
      ),
      analysisMaxFrameAverageLightLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_max_frame_average_light_level'],
      ),
      analysisDolbyVisionProfile: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_dolby_vision_profile'],
      ),
      analysisDolbyVisionCompatibilityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_dolby_vision_compatibility_id'],
      ),
      analysisAverageFrameRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_average_frame_rate'],
      ),
      analysisRealFrameRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_real_frame_rate'],
      ),
      analysisSampleAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_sample_aspect_ratio'],
      ),
      analysisDisplayAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_display_aspect_ratio'],
      ),
      analysisVideoRotationDegrees: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_video_rotation_degrees'],
      ),
      analysisFieldOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_field_order'],
      ),
      analysisVideoBitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_video_bitrate'],
      ),
      analysisAudioBitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_audio_bitrate'],
      ),
      analysisContainerBitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_container_bitrate'],
      ),
      analysisEstimatedBitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_estimated_bitrate'],
      ),
      analysisContainerFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_container_format'],
      ),
      analysisAudioChannels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_audio_channels'],
      ),
      analysisAudioSampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_audio_sample_rate'],
      ),
      analysisAudioChannelLayout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_audio_channel_layout'],
      ),
      analysisAudioStreamIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_audio_stream_index'],
      ),
      analysisAudioStreamsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_audio_streams_json'],
      ),
      mediaConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_config_json'],
      ),
      analysisImageWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_image_width'],
      ),
      analysisImageHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_image_height'],
      ),
      analysisImageCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_image_codec'],
      ),
      analysisImagePixelFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_image_pixel_format'],
      ),
      analysisImageBitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_image_bit_depth'],
      ),
      analysisUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_updated_at'],
      ),
      analysisErrorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_error_message'],
      ),
      outputFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_format'],
      )!,
      videoCodec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_codec'],
      )!,
      encoderBackend: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoder_backend'],
      )!,
      resolutionPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution_preset'],
      )!,
      outputDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_directory'],
      )!,
      compressionCrf: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compression_crf'],
      )!,
      compressionMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compression_mode'],
      )!,
      smartPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smart_preset'],
      ),
      targetSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_size_bytes'],
      ),
      targetSizeRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_size_ratio'],
      ),
      outputFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_file_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      failedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_at'],
      ),
    );
  }

  @override
  $TaskRowsTable createAlias(String alias) {
    return $TaskRowsTable(attachedDatabase, alias);
  }
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  /// 这里id用String类型 因为实体类media_task里面用的是uuid
  final String id;
  final String inputPath;
  final String fileName;
  final String mediaKind;
  final String purpose;
  final String status;
  final double progress;
  final int sortOrder;
  final String? folderId;
  final int? folderSortOrder;
  final String? outputPath;
  final int? outputFileSize;
  final String? errorMessage;
  final String? failureJson;
  final String? policyTagsJson;
  final int? sourceFileSize;
  final int? sourceLastModifiedAt;
  final int? analysisDurationMs;
  final int? analysisVideoWidth;
  final int? analysisVideoHeight;
  final String? analysisVideoCodec;
  final String? analysisAudioCodec;
  final String? analysisVideoPixelFormat;
  final int? analysisVideoBitDepth;
  final String? analysisColorRange;
  final String? analysisColorSpace;
  final String? analysisColorTransfer;
  final String? analysisColorPrimaries;
  final String? analysisChromaLocation;
  final String? analysisMasteringDisplayMetadata;
  final double? analysisMasteringDisplayMaxLuminance;
  final int? analysisMaxContentLightLevel;
  final int? analysisMaxFrameAverageLightLevel;
  final int? analysisDolbyVisionProfile;
  final int? analysisDolbyVisionCompatibilityId;
  final String? analysisAverageFrameRate;
  final String? analysisRealFrameRate;
  final String? analysisSampleAspectRatio;
  final String? analysisDisplayAspectRatio;
  final int? analysisVideoRotationDegrees;
  final String? analysisFieldOrder;
  final int? analysisVideoBitrate;
  final int? analysisAudioBitrate;
  final int? analysisContainerBitrate;
  final int? analysisEstimatedBitrate;
  final String? analysisContainerFormat;
  final int? analysisAudioChannels;
  final int? analysisAudioSampleRate;
  final String? analysisAudioChannelLayout;
  final int? analysisAudioStreamIndex;
  final String? analysisAudioStreamsJson;
  final String? mediaConfigJson;
  final int? analysisImageWidth;
  final int? analysisImageHeight;
  final String? analysisImageCodec;
  final String? analysisImagePixelFormat;
  final int? analysisImageBitDepth;
  final int? analysisUpdatedAt;
  final String? analysisErrorMessage;
  final String outputFormat;
  final String videoCodec;
  final String encoderBackend;
  final String resolutionPreset;
  final String outputDirectory;
  final int compressionCrf;
  final String compressionMode;
  final String? smartPreset;
  final int? targetSizeBytes;
  final double? targetSizeRatio;
  final String outputFileName;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final int? failedAt;
  const TaskRow({
    required this.id,
    required this.inputPath,
    required this.fileName,
    required this.mediaKind,
    required this.purpose,
    required this.status,
    required this.progress,
    required this.sortOrder,
    this.folderId,
    this.folderSortOrder,
    this.outputPath,
    this.outputFileSize,
    this.errorMessage,
    this.failureJson,
    this.policyTagsJson,
    this.sourceFileSize,
    this.sourceLastModifiedAt,
    this.analysisDurationMs,
    this.analysisVideoWidth,
    this.analysisVideoHeight,
    this.analysisVideoCodec,
    this.analysisAudioCodec,
    this.analysisVideoPixelFormat,
    this.analysisVideoBitDepth,
    this.analysisColorRange,
    this.analysisColorSpace,
    this.analysisColorTransfer,
    this.analysisColorPrimaries,
    this.analysisChromaLocation,
    this.analysisMasteringDisplayMetadata,
    this.analysisMasteringDisplayMaxLuminance,
    this.analysisMaxContentLightLevel,
    this.analysisMaxFrameAverageLightLevel,
    this.analysisDolbyVisionProfile,
    this.analysisDolbyVisionCompatibilityId,
    this.analysisAverageFrameRate,
    this.analysisRealFrameRate,
    this.analysisSampleAspectRatio,
    this.analysisDisplayAspectRatio,
    this.analysisVideoRotationDegrees,
    this.analysisFieldOrder,
    this.analysisVideoBitrate,
    this.analysisAudioBitrate,
    this.analysisContainerBitrate,
    this.analysisEstimatedBitrate,
    this.analysisContainerFormat,
    this.analysisAudioChannels,
    this.analysisAudioSampleRate,
    this.analysisAudioChannelLayout,
    this.analysisAudioStreamIndex,
    this.analysisAudioStreamsJson,
    this.mediaConfigJson,
    this.analysisImageWidth,
    this.analysisImageHeight,
    this.analysisImageCodec,
    this.analysisImagePixelFormat,
    this.analysisImageBitDepth,
    this.analysisUpdatedAt,
    this.analysisErrorMessage,
    required this.outputFormat,
    required this.videoCodec,
    required this.encoderBackend,
    required this.resolutionPreset,
    required this.outputDirectory,
    required this.compressionCrf,
    required this.compressionMode,
    this.smartPreset,
    this.targetSizeBytes,
    this.targetSizeRatio,
    required this.outputFileName,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.failedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['input_path'] = Variable<String>(inputPath);
    map['file_name'] = Variable<String>(fileName);
    map['media_kind'] = Variable<String>(mediaKind);
    map['purpose'] = Variable<String>(purpose);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<double>(progress);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || folderSortOrder != null) {
      map['folder_sort_order'] = Variable<int>(folderSortOrder);
    }
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    if (!nullToAbsent || outputFileSize != null) {
      map['output_file_size'] = Variable<int>(outputFileSize);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || failureJson != null) {
      map['failure_json'] = Variable<String>(failureJson);
    }
    if (!nullToAbsent || policyTagsJson != null) {
      map['policy_tags_json'] = Variable<String>(policyTagsJson);
    }
    if (!nullToAbsent || sourceFileSize != null) {
      map['source_file_size'] = Variable<int>(sourceFileSize);
    }
    if (!nullToAbsent || sourceLastModifiedAt != null) {
      map['source_last_modified_at'] = Variable<int>(sourceLastModifiedAt);
    }
    if (!nullToAbsent || analysisDurationMs != null) {
      map['analysis_duration_ms'] = Variable<int>(analysisDurationMs);
    }
    if (!nullToAbsent || analysisVideoWidth != null) {
      map['analysis_video_width'] = Variable<int>(analysisVideoWidth);
    }
    if (!nullToAbsent || analysisVideoHeight != null) {
      map['analysis_video_height'] = Variable<int>(analysisVideoHeight);
    }
    if (!nullToAbsent || analysisVideoCodec != null) {
      map['analysis_video_codec'] = Variable<String>(analysisVideoCodec);
    }
    if (!nullToAbsent || analysisAudioCodec != null) {
      map['analysis_audio_codec'] = Variable<String>(analysisAudioCodec);
    }
    if (!nullToAbsent || analysisVideoPixelFormat != null) {
      map['analysis_video_pixel_format'] = Variable<String>(
        analysisVideoPixelFormat,
      );
    }
    if (!nullToAbsent || analysisVideoBitDepth != null) {
      map['analysis_video_bit_depth'] = Variable<int>(analysisVideoBitDepth);
    }
    if (!nullToAbsent || analysisColorRange != null) {
      map['analysis_color_range'] = Variable<String>(analysisColorRange);
    }
    if (!nullToAbsent || analysisColorSpace != null) {
      map['analysis_color_space'] = Variable<String>(analysisColorSpace);
    }
    if (!nullToAbsent || analysisColorTransfer != null) {
      map['analysis_color_transfer'] = Variable<String>(analysisColorTransfer);
    }
    if (!nullToAbsent || analysisColorPrimaries != null) {
      map['analysis_color_primaries'] = Variable<String>(
        analysisColorPrimaries,
      );
    }
    if (!nullToAbsent || analysisChromaLocation != null) {
      map['analysis_chroma_location'] = Variable<String>(
        analysisChromaLocation,
      );
    }
    if (!nullToAbsent || analysisMasteringDisplayMetadata != null) {
      map['analysis_mastering_display_metadata'] = Variable<String>(
        analysisMasteringDisplayMetadata,
      );
    }
    if (!nullToAbsent || analysisMasteringDisplayMaxLuminance != null) {
      map['analysis_mastering_display_max_luminance'] = Variable<double>(
        analysisMasteringDisplayMaxLuminance,
      );
    }
    if (!nullToAbsent || analysisMaxContentLightLevel != null) {
      map['analysis_max_content_light_level'] = Variable<int>(
        analysisMaxContentLightLevel,
      );
    }
    if (!nullToAbsent || analysisMaxFrameAverageLightLevel != null) {
      map['analysis_max_frame_average_light_level'] = Variable<int>(
        analysisMaxFrameAverageLightLevel,
      );
    }
    if (!nullToAbsent || analysisDolbyVisionProfile != null) {
      map['analysis_dolby_vision_profile'] = Variable<int>(
        analysisDolbyVisionProfile,
      );
    }
    if (!nullToAbsent || analysisDolbyVisionCompatibilityId != null) {
      map['analysis_dolby_vision_compatibility_id'] = Variable<int>(
        analysisDolbyVisionCompatibilityId,
      );
    }
    if (!nullToAbsent || analysisAverageFrameRate != null) {
      map['analysis_average_frame_rate'] = Variable<String>(
        analysisAverageFrameRate,
      );
    }
    if (!nullToAbsent || analysisRealFrameRate != null) {
      map['analysis_real_frame_rate'] = Variable<String>(analysisRealFrameRate);
    }
    if (!nullToAbsent || analysisSampleAspectRatio != null) {
      map['analysis_sample_aspect_ratio'] = Variable<String>(
        analysisSampleAspectRatio,
      );
    }
    if (!nullToAbsent || analysisDisplayAspectRatio != null) {
      map['analysis_display_aspect_ratio'] = Variable<String>(
        analysisDisplayAspectRatio,
      );
    }
    if (!nullToAbsent || analysisVideoRotationDegrees != null) {
      map['analysis_video_rotation_degrees'] = Variable<int>(
        analysisVideoRotationDegrees,
      );
    }
    if (!nullToAbsent || analysisFieldOrder != null) {
      map['analysis_field_order'] = Variable<String>(analysisFieldOrder);
    }
    if (!nullToAbsent || analysisVideoBitrate != null) {
      map['analysis_video_bitrate'] = Variable<int>(analysisVideoBitrate);
    }
    if (!nullToAbsent || analysisAudioBitrate != null) {
      map['analysis_audio_bitrate'] = Variable<int>(analysisAudioBitrate);
    }
    if (!nullToAbsent || analysisContainerBitrate != null) {
      map['analysis_container_bitrate'] = Variable<int>(
        analysisContainerBitrate,
      );
    }
    if (!nullToAbsent || analysisEstimatedBitrate != null) {
      map['analysis_estimated_bitrate'] = Variable<int>(
        analysisEstimatedBitrate,
      );
    }
    if (!nullToAbsent || analysisContainerFormat != null) {
      map['analysis_container_format'] = Variable<String>(
        analysisContainerFormat,
      );
    }
    if (!nullToAbsent || analysisAudioChannels != null) {
      map['analysis_audio_channels'] = Variable<int>(analysisAudioChannels);
    }
    if (!nullToAbsent || analysisAudioSampleRate != null) {
      map['analysis_audio_sample_rate'] = Variable<int>(
        analysisAudioSampleRate,
      );
    }
    if (!nullToAbsent || analysisAudioChannelLayout != null) {
      map['analysis_audio_channel_layout'] = Variable<String>(
        analysisAudioChannelLayout,
      );
    }
    if (!nullToAbsent || analysisAudioStreamIndex != null) {
      map['analysis_audio_stream_index'] = Variable<int>(
        analysisAudioStreamIndex,
      );
    }
    if (!nullToAbsent || analysisAudioStreamsJson != null) {
      map['analysis_audio_streams_json'] = Variable<String>(
        analysisAudioStreamsJson,
      );
    }
    if (!nullToAbsent || mediaConfigJson != null) {
      map['media_config_json'] = Variable<String>(mediaConfigJson);
    }
    if (!nullToAbsent || analysisImageWidth != null) {
      map['analysis_image_width'] = Variable<int>(analysisImageWidth);
    }
    if (!nullToAbsent || analysisImageHeight != null) {
      map['analysis_image_height'] = Variable<int>(analysisImageHeight);
    }
    if (!nullToAbsent || analysisImageCodec != null) {
      map['analysis_image_codec'] = Variable<String>(analysisImageCodec);
    }
    if (!nullToAbsent || analysisImagePixelFormat != null) {
      map['analysis_image_pixel_format'] = Variable<String>(
        analysisImagePixelFormat,
      );
    }
    if (!nullToAbsent || analysisImageBitDepth != null) {
      map['analysis_image_bit_depth'] = Variable<int>(analysisImageBitDepth);
    }
    if (!nullToAbsent || analysisUpdatedAt != null) {
      map['analysis_updated_at'] = Variable<int>(analysisUpdatedAt);
    }
    if (!nullToAbsent || analysisErrorMessage != null) {
      map['analysis_error_message'] = Variable<String>(analysisErrorMessage);
    }
    map['output_format'] = Variable<String>(outputFormat);
    map['video_codec'] = Variable<String>(videoCodec);
    map['encoder_backend'] = Variable<String>(encoderBackend);
    map['resolution_preset'] = Variable<String>(resolutionPreset);
    map['output_directory'] = Variable<String>(outputDirectory);
    map['compression_crf'] = Variable<int>(compressionCrf);
    map['compression_mode'] = Variable<String>(compressionMode);
    if (!nullToAbsent || smartPreset != null) {
      map['smart_preset'] = Variable<String>(smartPreset);
    }
    if (!nullToAbsent || targetSizeBytes != null) {
      map['target_size_bytes'] = Variable<int>(targetSizeBytes);
    }
    if (!nullToAbsent || targetSizeRatio != null) {
      map['target_size_ratio'] = Variable<double>(targetSizeRatio);
    }
    map['output_file_name'] = Variable<String>(outputFileName);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || failedAt != null) {
      map['failed_at'] = Variable<int>(failedAt);
    }
    return map;
  }

  TaskRowsCompanion toCompanion(bool nullToAbsent) {
    return TaskRowsCompanion(
      id: Value(id),
      inputPath: Value(inputPath),
      fileName: Value(fileName),
      mediaKind: Value(mediaKind),
      purpose: Value(purpose),
      status: Value(status),
      progress: Value(progress),
      sortOrder: Value(sortOrder),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      folderSortOrder: folderSortOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(folderSortOrder),
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      outputFileSize: outputFileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(outputFileSize),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      failureJson: failureJson == null && nullToAbsent
          ? const Value.absent()
          : Value(failureJson),
      policyTagsJson: policyTagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(policyTagsJson),
      sourceFileSize: sourceFileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFileSize),
      sourceLastModifiedAt: sourceLastModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceLastModifiedAt),
      analysisDurationMs: analysisDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisDurationMs),
      analysisVideoWidth: analysisVideoWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoWidth),
      analysisVideoHeight: analysisVideoHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoHeight),
      analysisVideoCodec: analysisVideoCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoCodec),
      analysisAudioCodec: analysisAudioCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioCodec),
      analysisVideoPixelFormat: analysisVideoPixelFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoPixelFormat),
      analysisVideoBitDepth: analysisVideoBitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoBitDepth),
      analysisColorRange: analysisColorRange == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisColorRange),
      analysisColorSpace: analysisColorSpace == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisColorSpace),
      analysisColorTransfer: analysisColorTransfer == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisColorTransfer),
      analysisColorPrimaries: analysisColorPrimaries == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisColorPrimaries),
      analysisChromaLocation: analysisChromaLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisChromaLocation),
      analysisMasteringDisplayMetadata:
          analysisMasteringDisplayMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisMasteringDisplayMetadata),
      analysisMasteringDisplayMaxLuminance:
          analysisMasteringDisplayMaxLuminance == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisMasteringDisplayMaxLuminance),
      analysisMaxContentLightLevel:
          analysisMaxContentLightLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisMaxContentLightLevel),
      analysisMaxFrameAverageLightLevel:
          analysisMaxFrameAverageLightLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisMaxFrameAverageLightLevel),
      analysisDolbyVisionProfile:
          analysisDolbyVisionProfile == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisDolbyVisionProfile),
      analysisDolbyVisionCompatibilityId:
          analysisDolbyVisionCompatibilityId == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisDolbyVisionCompatibilityId),
      analysisAverageFrameRate: analysisAverageFrameRate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAverageFrameRate),
      analysisRealFrameRate: analysisRealFrameRate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisRealFrameRate),
      analysisSampleAspectRatio:
          analysisSampleAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisSampleAspectRatio),
      analysisDisplayAspectRatio:
          analysisDisplayAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisDisplayAspectRatio),
      analysisVideoRotationDegrees:
          analysisVideoRotationDegrees == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoRotationDegrees),
      analysisFieldOrder: analysisFieldOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisFieldOrder),
      analysisVideoBitrate: analysisVideoBitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisVideoBitrate),
      analysisAudioBitrate: analysisAudioBitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioBitrate),
      analysisContainerBitrate: analysisContainerBitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisContainerBitrate),
      analysisEstimatedBitrate: analysisEstimatedBitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisEstimatedBitrate),
      analysisContainerFormat: analysisContainerFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisContainerFormat),
      analysisAudioChannels: analysisAudioChannels == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioChannels),
      analysisAudioSampleRate: analysisAudioSampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioSampleRate),
      analysisAudioChannelLayout:
          analysisAudioChannelLayout == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioChannelLayout),
      analysisAudioStreamIndex: analysisAudioStreamIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioStreamIndex),
      analysisAudioStreamsJson: analysisAudioStreamsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisAudioStreamsJson),
      mediaConfigJson: mediaConfigJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaConfigJson),
      analysisImageWidth: analysisImageWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisImageWidth),
      analysisImageHeight: analysisImageHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisImageHeight),
      analysisImageCodec: analysisImageCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisImageCodec),
      analysisImagePixelFormat: analysisImagePixelFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisImagePixelFormat),
      analysisImageBitDepth: analysisImageBitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisImageBitDepth),
      analysisUpdatedAt: analysisUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisUpdatedAt),
      analysisErrorMessage: analysisErrorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisErrorMessage),
      outputFormat: Value(outputFormat),
      videoCodec: Value(videoCodec),
      encoderBackend: Value(encoderBackend),
      resolutionPreset: Value(resolutionPreset),
      outputDirectory: Value(outputDirectory),
      compressionCrf: Value(compressionCrf),
      compressionMode: Value(compressionMode),
      smartPreset: smartPreset == null && nullToAbsent
          ? const Value.absent()
          : Value(smartPreset),
      targetSizeBytes: targetSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSizeBytes),
      targetSizeRatio: targetSizeRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSizeRatio),
      outputFileName: Value(outputFileName),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      failedAt: failedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(failedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      inputPath: serializer.fromJson<String>(json['inputPath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      purpose: serializer.fromJson<String>(json['purpose']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      folderSortOrder: serializer.fromJson<int?>(json['folderSortOrder']),
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      outputFileSize: serializer.fromJson<int?>(json['outputFileSize']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      failureJson: serializer.fromJson<String?>(json['failureJson']),
      policyTagsJson: serializer.fromJson<String?>(json['policyTagsJson']),
      sourceFileSize: serializer.fromJson<int?>(json['sourceFileSize']),
      sourceLastModifiedAt: serializer.fromJson<int?>(
        json['sourceLastModifiedAt'],
      ),
      analysisDurationMs: serializer.fromJson<int?>(json['analysisDurationMs']),
      analysisVideoWidth: serializer.fromJson<int?>(json['analysisVideoWidth']),
      analysisVideoHeight: serializer.fromJson<int?>(
        json['analysisVideoHeight'],
      ),
      analysisVideoCodec: serializer.fromJson<String?>(
        json['analysisVideoCodec'],
      ),
      analysisAudioCodec: serializer.fromJson<String?>(
        json['analysisAudioCodec'],
      ),
      analysisVideoPixelFormat: serializer.fromJson<String?>(
        json['analysisVideoPixelFormat'],
      ),
      analysisVideoBitDepth: serializer.fromJson<int?>(
        json['analysisVideoBitDepth'],
      ),
      analysisColorRange: serializer.fromJson<String?>(
        json['analysisColorRange'],
      ),
      analysisColorSpace: serializer.fromJson<String?>(
        json['analysisColorSpace'],
      ),
      analysisColorTransfer: serializer.fromJson<String?>(
        json['analysisColorTransfer'],
      ),
      analysisColorPrimaries: serializer.fromJson<String?>(
        json['analysisColorPrimaries'],
      ),
      analysisChromaLocation: serializer.fromJson<String?>(
        json['analysisChromaLocation'],
      ),
      analysisMasteringDisplayMetadata: serializer.fromJson<String?>(
        json['analysisMasteringDisplayMetadata'],
      ),
      analysisMasteringDisplayMaxLuminance: serializer.fromJson<double?>(
        json['analysisMasteringDisplayMaxLuminance'],
      ),
      analysisMaxContentLightLevel: serializer.fromJson<int?>(
        json['analysisMaxContentLightLevel'],
      ),
      analysisMaxFrameAverageLightLevel: serializer.fromJson<int?>(
        json['analysisMaxFrameAverageLightLevel'],
      ),
      analysisDolbyVisionProfile: serializer.fromJson<int?>(
        json['analysisDolbyVisionProfile'],
      ),
      analysisDolbyVisionCompatibilityId: serializer.fromJson<int?>(
        json['analysisDolbyVisionCompatibilityId'],
      ),
      analysisAverageFrameRate: serializer.fromJson<String?>(
        json['analysisAverageFrameRate'],
      ),
      analysisRealFrameRate: serializer.fromJson<String?>(
        json['analysisRealFrameRate'],
      ),
      analysisSampleAspectRatio: serializer.fromJson<String?>(
        json['analysisSampleAspectRatio'],
      ),
      analysisDisplayAspectRatio: serializer.fromJson<String?>(
        json['analysisDisplayAspectRatio'],
      ),
      analysisVideoRotationDegrees: serializer.fromJson<int?>(
        json['analysisVideoRotationDegrees'],
      ),
      analysisFieldOrder: serializer.fromJson<String?>(
        json['analysisFieldOrder'],
      ),
      analysisVideoBitrate: serializer.fromJson<int?>(
        json['analysisVideoBitrate'],
      ),
      analysisAudioBitrate: serializer.fromJson<int?>(
        json['analysisAudioBitrate'],
      ),
      analysisContainerBitrate: serializer.fromJson<int?>(
        json['analysisContainerBitrate'],
      ),
      analysisEstimatedBitrate: serializer.fromJson<int?>(
        json['analysisEstimatedBitrate'],
      ),
      analysisContainerFormat: serializer.fromJson<String?>(
        json['analysisContainerFormat'],
      ),
      analysisAudioChannels: serializer.fromJson<int?>(
        json['analysisAudioChannels'],
      ),
      analysisAudioSampleRate: serializer.fromJson<int?>(
        json['analysisAudioSampleRate'],
      ),
      analysisAudioChannelLayout: serializer.fromJson<String?>(
        json['analysisAudioChannelLayout'],
      ),
      analysisAudioStreamIndex: serializer.fromJson<int?>(
        json['analysisAudioStreamIndex'],
      ),
      analysisAudioStreamsJson: serializer.fromJson<String?>(
        json['analysisAudioStreamsJson'],
      ),
      mediaConfigJson: serializer.fromJson<String?>(json['mediaConfigJson']),
      analysisImageWidth: serializer.fromJson<int?>(json['analysisImageWidth']),
      analysisImageHeight: serializer.fromJson<int?>(
        json['analysisImageHeight'],
      ),
      analysisImageCodec: serializer.fromJson<String?>(
        json['analysisImageCodec'],
      ),
      analysisImagePixelFormat: serializer.fromJson<String?>(
        json['analysisImagePixelFormat'],
      ),
      analysisImageBitDepth: serializer.fromJson<int?>(
        json['analysisImageBitDepth'],
      ),
      analysisUpdatedAt: serializer.fromJson<int?>(json['analysisUpdatedAt']),
      analysisErrorMessage: serializer.fromJson<String?>(
        json['analysisErrorMessage'],
      ),
      outputFormat: serializer.fromJson<String>(json['outputFormat']),
      videoCodec: serializer.fromJson<String>(json['videoCodec']),
      encoderBackend: serializer.fromJson<String>(json['encoderBackend']),
      resolutionPreset: serializer.fromJson<String>(json['resolutionPreset']),
      outputDirectory: serializer.fromJson<String>(json['outputDirectory']),
      compressionCrf: serializer.fromJson<int>(json['compressionCrf']),
      compressionMode: serializer.fromJson<String>(json['compressionMode']),
      smartPreset: serializer.fromJson<String?>(json['smartPreset']),
      targetSizeBytes: serializer.fromJson<int?>(json['targetSizeBytes']),
      targetSizeRatio: serializer.fromJson<double?>(json['targetSizeRatio']),
      outputFileName: serializer.fromJson<String>(json['outputFileName']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      failedAt: serializer.fromJson<int?>(json['failedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'inputPath': serializer.toJson<String>(inputPath),
      'fileName': serializer.toJson<String>(fileName),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'purpose': serializer.toJson<String>(purpose),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double>(progress),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'folderId': serializer.toJson<String?>(folderId),
      'folderSortOrder': serializer.toJson<int?>(folderSortOrder),
      'outputPath': serializer.toJson<String?>(outputPath),
      'outputFileSize': serializer.toJson<int?>(outputFileSize),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'failureJson': serializer.toJson<String?>(failureJson),
      'policyTagsJson': serializer.toJson<String?>(policyTagsJson),
      'sourceFileSize': serializer.toJson<int?>(sourceFileSize),
      'sourceLastModifiedAt': serializer.toJson<int?>(sourceLastModifiedAt),
      'analysisDurationMs': serializer.toJson<int?>(analysisDurationMs),
      'analysisVideoWidth': serializer.toJson<int?>(analysisVideoWidth),
      'analysisVideoHeight': serializer.toJson<int?>(analysisVideoHeight),
      'analysisVideoCodec': serializer.toJson<String?>(analysisVideoCodec),
      'analysisAudioCodec': serializer.toJson<String?>(analysisAudioCodec),
      'analysisVideoPixelFormat': serializer.toJson<String?>(
        analysisVideoPixelFormat,
      ),
      'analysisVideoBitDepth': serializer.toJson<int?>(analysisVideoBitDepth),
      'analysisColorRange': serializer.toJson<String?>(analysisColorRange),
      'analysisColorSpace': serializer.toJson<String?>(analysisColorSpace),
      'analysisColorTransfer': serializer.toJson<String?>(
        analysisColorTransfer,
      ),
      'analysisColorPrimaries': serializer.toJson<String?>(
        analysisColorPrimaries,
      ),
      'analysisChromaLocation': serializer.toJson<String?>(
        analysisChromaLocation,
      ),
      'analysisMasteringDisplayMetadata': serializer.toJson<String?>(
        analysisMasteringDisplayMetadata,
      ),
      'analysisMasteringDisplayMaxLuminance': serializer.toJson<double?>(
        analysisMasteringDisplayMaxLuminance,
      ),
      'analysisMaxContentLightLevel': serializer.toJson<int?>(
        analysisMaxContentLightLevel,
      ),
      'analysisMaxFrameAverageLightLevel': serializer.toJson<int?>(
        analysisMaxFrameAverageLightLevel,
      ),
      'analysisDolbyVisionProfile': serializer.toJson<int?>(
        analysisDolbyVisionProfile,
      ),
      'analysisDolbyVisionCompatibilityId': serializer.toJson<int?>(
        analysisDolbyVisionCompatibilityId,
      ),
      'analysisAverageFrameRate': serializer.toJson<String?>(
        analysisAverageFrameRate,
      ),
      'analysisRealFrameRate': serializer.toJson<String?>(
        analysisRealFrameRate,
      ),
      'analysisSampleAspectRatio': serializer.toJson<String?>(
        analysisSampleAspectRatio,
      ),
      'analysisDisplayAspectRatio': serializer.toJson<String?>(
        analysisDisplayAspectRatio,
      ),
      'analysisVideoRotationDegrees': serializer.toJson<int?>(
        analysisVideoRotationDegrees,
      ),
      'analysisFieldOrder': serializer.toJson<String?>(analysisFieldOrder),
      'analysisVideoBitrate': serializer.toJson<int?>(analysisVideoBitrate),
      'analysisAudioBitrate': serializer.toJson<int?>(analysisAudioBitrate),
      'analysisContainerBitrate': serializer.toJson<int?>(
        analysisContainerBitrate,
      ),
      'analysisEstimatedBitrate': serializer.toJson<int?>(
        analysisEstimatedBitrate,
      ),
      'analysisContainerFormat': serializer.toJson<String?>(
        analysisContainerFormat,
      ),
      'analysisAudioChannels': serializer.toJson<int?>(analysisAudioChannels),
      'analysisAudioSampleRate': serializer.toJson<int?>(
        analysisAudioSampleRate,
      ),
      'analysisAudioChannelLayout': serializer.toJson<String?>(
        analysisAudioChannelLayout,
      ),
      'analysisAudioStreamIndex': serializer.toJson<int?>(
        analysisAudioStreamIndex,
      ),
      'analysisAudioStreamsJson': serializer.toJson<String?>(
        analysisAudioStreamsJson,
      ),
      'mediaConfigJson': serializer.toJson<String?>(mediaConfigJson),
      'analysisImageWidth': serializer.toJson<int?>(analysisImageWidth),
      'analysisImageHeight': serializer.toJson<int?>(analysisImageHeight),
      'analysisImageCodec': serializer.toJson<String?>(analysisImageCodec),
      'analysisImagePixelFormat': serializer.toJson<String?>(
        analysisImagePixelFormat,
      ),
      'analysisImageBitDepth': serializer.toJson<int?>(analysisImageBitDepth),
      'analysisUpdatedAt': serializer.toJson<int?>(analysisUpdatedAt),
      'analysisErrorMessage': serializer.toJson<String?>(analysisErrorMessage),
      'outputFormat': serializer.toJson<String>(outputFormat),
      'videoCodec': serializer.toJson<String>(videoCodec),
      'encoderBackend': serializer.toJson<String>(encoderBackend),
      'resolutionPreset': serializer.toJson<String>(resolutionPreset),
      'outputDirectory': serializer.toJson<String>(outputDirectory),
      'compressionCrf': serializer.toJson<int>(compressionCrf),
      'compressionMode': serializer.toJson<String>(compressionMode),
      'smartPreset': serializer.toJson<String?>(smartPreset),
      'targetSizeBytes': serializer.toJson<int?>(targetSizeBytes),
      'targetSizeRatio': serializer.toJson<double?>(targetSizeRatio),
      'outputFileName': serializer.toJson<String>(outputFileName),
      'createdAt': serializer.toJson<int>(createdAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'failedAt': serializer.toJson<int?>(failedAt),
    };
  }

  TaskRow copyWith({
    String? id,
    String? inputPath,
    String? fileName,
    String? mediaKind,
    String? purpose,
    String? status,
    double? progress,
    int? sortOrder,
    Value<String?> folderId = const Value.absent(),
    Value<int?> folderSortOrder = const Value.absent(),
    Value<String?> outputPath = const Value.absent(),
    Value<int?> outputFileSize = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> failureJson = const Value.absent(),
    Value<String?> policyTagsJson = const Value.absent(),
    Value<int?> sourceFileSize = const Value.absent(),
    Value<int?> sourceLastModifiedAt = const Value.absent(),
    Value<int?> analysisDurationMs = const Value.absent(),
    Value<int?> analysisVideoWidth = const Value.absent(),
    Value<int?> analysisVideoHeight = const Value.absent(),
    Value<String?> analysisVideoCodec = const Value.absent(),
    Value<String?> analysisAudioCodec = const Value.absent(),
    Value<String?> analysisVideoPixelFormat = const Value.absent(),
    Value<int?> analysisVideoBitDepth = const Value.absent(),
    Value<String?> analysisColorRange = const Value.absent(),
    Value<String?> analysisColorSpace = const Value.absent(),
    Value<String?> analysisColorTransfer = const Value.absent(),
    Value<String?> analysisColorPrimaries = const Value.absent(),
    Value<String?> analysisChromaLocation = const Value.absent(),
    Value<String?> analysisMasteringDisplayMetadata = const Value.absent(),
    Value<double?> analysisMasteringDisplayMaxLuminance = const Value.absent(),
    Value<int?> analysisMaxContentLightLevel = const Value.absent(),
    Value<int?> analysisMaxFrameAverageLightLevel = const Value.absent(),
    Value<int?> analysisDolbyVisionProfile = const Value.absent(),
    Value<int?> analysisDolbyVisionCompatibilityId = const Value.absent(),
    Value<String?> analysisAverageFrameRate = const Value.absent(),
    Value<String?> analysisRealFrameRate = const Value.absent(),
    Value<String?> analysisSampleAspectRatio = const Value.absent(),
    Value<String?> analysisDisplayAspectRatio = const Value.absent(),
    Value<int?> analysisVideoRotationDegrees = const Value.absent(),
    Value<String?> analysisFieldOrder = const Value.absent(),
    Value<int?> analysisVideoBitrate = const Value.absent(),
    Value<int?> analysisAudioBitrate = const Value.absent(),
    Value<int?> analysisContainerBitrate = const Value.absent(),
    Value<int?> analysisEstimatedBitrate = const Value.absent(),
    Value<String?> analysisContainerFormat = const Value.absent(),
    Value<int?> analysisAudioChannels = const Value.absent(),
    Value<int?> analysisAudioSampleRate = const Value.absent(),
    Value<String?> analysisAudioChannelLayout = const Value.absent(),
    Value<int?> analysisAudioStreamIndex = const Value.absent(),
    Value<String?> analysisAudioStreamsJson = const Value.absent(),
    Value<String?> mediaConfigJson = const Value.absent(),
    Value<int?> analysisImageWidth = const Value.absent(),
    Value<int?> analysisImageHeight = const Value.absent(),
    Value<String?> analysisImageCodec = const Value.absent(),
    Value<String?> analysisImagePixelFormat = const Value.absent(),
    Value<int?> analysisImageBitDepth = const Value.absent(),
    Value<int?> analysisUpdatedAt = const Value.absent(),
    Value<String?> analysisErrorMessage = const Value.absent(),
    String? outputFormat,
    String? videoCodec,
    String? encoderBackend,
    String? resolutionPreset,
    String? outputDirectory,
    int? compressionCrf,
    String? compressionMode,
    Value<String?> smartPreset = const Value.absent(),
    Value<int?> targetSizeBytes = const Value.absent(),
    Value<double?> targetSizeRatio = const Value.absent(),
    String? outputFileName,
    int? createdAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    Value<int?> failedAt = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    inputPath: inputPath ?? this.inputPath,
    fileName: fileName ?? this.fileName,
    mediaKind: mediaKind ?? this.mediaKind,
    purpose: purpose ?? this.purpose,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    sortOrder: sortOrder ?? this.sortOrder,
    folderId: folderId.present ? folderId.value : this.folderId,
    folderSortOrder: folderSortOrder.present
        ? folderSortOrder.value
        : this.folderSortOrder,
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    outputFileSize: outputFileSize.present
        ? outputFileSize.value
        : this.outputFileSize,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    failureJson: failureJson.present ? failureJson.value : this.failureJson,
    policyTagsJson: policyTagsJson.present
        ? policyTagsJson.value
        : this.policyTagsJson,
    sourceFileSize: sourceFileSize.present
        ? sourceFileSize.value
        : this.sourceFileSize,
    sourceLastModifiedAt: sourceLastModifiedAt.present
        ? sourceLastModifiedAt.value
        : this.sourceLastModifiedAt,
    analysisDurationMs: analysisDurationMs.present
        ? analysisDurationMs.value
        : this.analysisDurationMs,
    analysisVideoWidth: analysisVideoWidth.present
        ? analysisVideoWidth.value
        : this.analysisVideoWidth,
    analysisVideoHeight: analysisVideoHeight.present
        ? analysisVideoHeight.value
        : this.analysisVideoHeight,
    analysisVideoCodec: analysisVideoCodec.present
        ? analysisVideoCodec.value
        : this.analysisVideoCodec,
    analysisAudioCodec: analysisAudioCodec.present
        ? analysisAudioCodec.value
        : this.analysisAudioCodec,
    analysisVideoPixelFormat: analysisVideoPixelFormat.present
        ? analysisVideoPixelFormat.value
        : this.analysisVideoPixelFormat,
    analysisVideoBitDepth: analysisVideoBitDepth.present
        ? analysisVideoBitDepth.value
        : this.analysisVideoBitDepth,
    analysisColorRange: analysisColorRange.present
        ? analysisColorRange.value
        : this.analysisColorRange,
    analysisColorSpace: analysisColorSpace.present
        ? analysisColorSpace.value
        : this.analysisColorSpace,
    analysisColorTransfer: analysisColorTransfer.present
        ? analysisColorTransfer.value
        : this.analysisColorTransfer,
    analysisColorPrimaries: analysisColorPrimaries.present
        ? analysisColorPrimaries.value
        : this.analysisColorPrimaries,
    analysisChromaLocation: analysisChromaLocation.present
        ? analysisChromaLocation.value
        : this.analysisChromaLocation,
    analysisMasteringDisplayMetadata: analysisMasteringDisplayMetadata.present
        ? analysisMasteringDisplayMetadata.value
        : this.analysisMasteringDisplayMetadata,
    analysisMasteringDisplayMaxLuminance:
        analysisMasteringDisplayMaxLuminance.present
        ? analysisMasteringDisplayMaxLuminance.value
        : this.analysisMasteringDisplayMaxLuminance,
    analysisMaxContentLightLevel: analysisMaxContentLightLevel.present
        ? analysisMaxContentLightLevel.value
        : this.analysisMaxContentLightLevel,
    analysisMaxFrameAverageLightLevel: analysisMaxFrameAverageLightLevel.present
        ? analysisMaxFrameAverageLightLevel.value
        : this.analysisMaxFrameAverageLightLevel,
    analysisDolbyVisionProfile: analysisDolbyVisionProfile.present
        ? analysisDolbyVisionProfile.value
        : this.analysisDolbyVisionProfile,
    analysisDolbyVisionCompatibilityId:
        analysisDolbyVisionCompatibilityId.present
        ? analysisDolbyVisionCompatibilityId.value
        : this.analysisDolbyVisionCompatibilityId,
    analysisAverageFrameRate: analysisAverageFrameRate.present
        ? analysisAverageFrameRate.value
        : this.analysisAverageFrameRate,
    analysisRealFrameRate: analysisRealFrameRate.present
        ? analysisRealFrameRate.value
        : this.analysisRealFrameRate,
    analysisSampleAspectRatio: analysisSampleAspectRatio.present
        ? analysisSampleAspectRatio.value
        : this.analysisSampleAspectRatio,
    analysisDisplayAspectRatio: analysisDisplayAspectRatio.present
        ? analysisDisplayAspectRatio.value
        : this.analysisDisplayAspectRatio,
    analysisVideoRotationDegrees: analysisVideoRotationDegrees.present
        ? analysisVideoRotationDegrees.value
        : this.analysisVideoRotationDegrees,
    analysisFieldOrder: analysisFieldOrder.present
        ? analysisFieldOrder.value
        : this.analysisFieldOrder,
    analysisVideoBitrate: analysisVideoBitrate.present
        ? analysisVideoBitrate.value
        : this.analysisVideoBitrate,
    analysisAudioBitrate: analysisAudioBitrate.present
        ? analysisAudioBitrate.value
        : this.analysisAudioBitrate,
    analysisContainerBitrate: analysisContainerBitrate.present
        ? analysisContainerBitrate.value
        : this.analysisContainerBitrate,
    analysisEstimatedBitrate: analysisEstimatedBitrate.present
        ? analysisEstimatedBitrate.value
        : this.analysisEstimatedBitrate,
    analysisContainerFormat: analysisContainerFormat.present
        ? analysisContainerFormat.value
        : this.analysisContainerFormat,
    analysisAudioChannels: analysisAudioChannels.present
        ? analysisAudioChannels.value
        : this.analysisAudioChannels,
    analysisAudioSampleRate: analysisAudioSampleRate.present
        ? analysisAudioSampleRate.value
        : this.analysisAudioSampleRate,
    analysisAudioChannelLayout: analysisAudioChannelLayout.present
        ? analysisAudioChannelLayout.value
        : this.analysisAudioChannelLayout,
    analysisAudioStreamIndex: analysisAudioStreamIndex.present
        ? analysisAudioStreamIndex.value
        : this.analysisAudioStreamIndex,
    analysisAudioStreamsJson: analysisAudioStreamsJson.present
        ? analysisAudioStreamsJson.value
        : this.analysisAudioStreamsJson,
    mediaConfigJson: mediaConfigJson.present
        ? mediaConfigJson.value
        : this.mediaConfigJson,
    analysisImageWidth: analysisImageWidth.present
        ? analysisImageWidth.value
        : this.analysisImageWidth,
    analysisImageHeight: analysisImageHeight.present
        ? analysisImageHeight.value
        : this.analysisImageHeight,
    analysisImageCodec: analysisImageCodec.present
        ? analysisImageCodec.value
        : this.analysisImageCodec,
    analysisImagePixelFormat: analysisImagePixelFormat.present
        ? analysisImagePixelFormat.value
        : this.analysisImagePixelFormat,
    analysisImageBitDepth: analysisImageBitDepth.present
        ? analysisImageBitDepth.value
        : this.analysisImageBitDepth,
    analysisUpdatedAt: analysisUpdatedAt.present
        ? analysisUpdatedAt.value
        : this.analysisUpdatedAt,
    analysisErrorMessage: analysisErrorMessage.present
        ? analysisErrorMessage.value
        : this.analysisErrorMessage,
    outputFormat: outputFormat ?? this.outputFormat,
    videoCodec: videoCodec ?? this.videoCodec,
    encoderBackend: encoderBackend ?? this.encoderBackend,
    resolutionPreset: resolutionPreset ?? this.resolutionPreset,
    outputDirectory: outputDirectory ?? this.outputDirectory,
    compressionCrf: compressionCrf ?? this.compressionCrf,
    compressionMode: compressionMode ?? this.compressionMode,
    smartPreset: smartPreset.present ? smartPreset.value : this.smartPreset,
    targetSizeBytes: targetSizeBytes.present
        ? targetSizeBytes.value
        : this.targetSizeBytes,
    targetSizeRatio: targetSizeRatio.present
        ? targetSizeRatio.value
        : this.targetSizeRatio,
    outputFileName: outputFileName ?? this.outputFileName,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    failedAt: failedAt.present ? failedAt.value : this.failedAt,
  );
  TaskRow copyWithCompanion(TaskRowsCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      inputPath: data.inputPath.present ? data.inputPath.value : this.inputPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      folderSortOrder: data.folderSortOrder.present
          ? data.folderSortOrder.value
          : this.folderSortOrder,
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      outputFileSize: data.outputFileSize.present
          ? data.outputFileSize.value
          : this.outputFileSize,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      failureJson: data.failureJson.present
          ? data.failureJson.value
          : this.failureJson,
      policyTagsJson: data.policyTagsJson.present
          ? data.policyTagsJson.value
          : this.policyTagsJson,
      sourceFileSize: data.sourceFileSize.present
          ? data.sourceFileSize.value
          : this.sourceFileSize,
      sourceLastModifiedAt: data.sourceLastModifiedAt.present
          ? data.sourceLastModifiedAt.value
          : this.sourceLastModifiedAt,
      analysisDurationMs: data.analysisDurationMs.present
          ? data.analysisDurationMs.value
          : this.analysisDurationMs,
      analysisVideoWidth: data.analysisVideoWidth.present
          ? data.analysisVideoWidth.value
          : this.analysisVideoWidth,
      analysisVideoHeight: data.analysisVideoHeight.present
          ? data.analysisVideoHeight.value
          : this.analysisVideoHeight,
      analysisVideoCodec: data.analysisVideoCodec.present
          ? data.analysisVideoCodec.value
          : this.analysisVideoCodec,
      analysisAudioCodec: data.analysisAudioCodec.present
          ? data.analysisAudioCodec.value
          : this.analysisAudioCodec,
      analysisVideoPixelFormat: data.analysisVideoPixelFormat.present
          ? data.analysisVideoPixelFormat.value
          : this.analysisVideoPixelFormat,
      analysisVideoBitDepth: data.analysisVideoBitDepth.present
          ? data.analysisVideoBitDepth.value
          : this.analysisVideoBitDepth,
      analysisColorRange: data.analysisColorRange.present
          ? data.analysisColorRange.value
          : this.analysisColorRange,
      analysisColorSpace: data.analysisColorSpace.present
          ? data.analysisColorSpace.value
          : this.analysisColorSpace,
      analysisColorTransfer: data.analysisColorTransfer.present
          ? data.analysisColorTransfer.value
          : this.analysisColorTransfer,
      analysisColorPrimaries: data.analysisColorPrimaries.present
          ? data.analysisColorPrimaries.value
          : this.analysisColorPrimaries,
      analysisChromaLocation: data.analysisChromaLocation.present
          ? data.analysisChromaLocation.value
          : this.analysisChromaLocation,
      analysisMasteringDisplayMetadata:
          data.analysisMasteringDisplayMetadata.present
          ? data.analysisMasteringDisplayMetadata.value
          : this.analysisMasteringDisplayMetadata,
      analysisMasteringDisplayMaxLuminance:
          data.analysisMasteringDisplayMaxLuminance.present
          ? data.analysisMasteringDisplayMaxLuminance.value
          : this.analysisMasteringDisplayMaxLuminance,
      analysisMaxContentLightLevel: data.analysisMaxContentLightLevel.present
          ? data.analysisMaxContentLightLevel.value
          : this.analysisMaxContentLightLevel,
      analysisMaxFrameAverageLightLevel:
          data.analysisMaxFrameAverageLightLevel.present
          ? data.analysisMaxFrameAverageLightLevel.value
          : this.analysisMaxFrameAverageLightLevel,
      analysisDolbyVisionProfile: data.analysisDolbyVisionProfile.present
          ? data.analysisDolbyVisionProfile.value
          : this.analysisDolbyVisionProfile,
      analysisDolbyVisionCompatibilityId:
          data.analysisDolbyVisionCompatibilityId.present
          ? data.analysisDolbyVisionCompatibilityId.value
          : this.analysisDolbyVisionCompatibilityId,
      analysisAverageFrameRate: data.analysisAverageFrameRate.present
          ? data.analysisAverageFrameRate.value
          : this.analysisAverageFrameRate,
      analysisRealFrameRate: data.analysisRealFrameRate.present
          ? data.analysisRealFrameRate.value
          : this.analysisRealFrameRate,
      analysisSampleAspectRatio: data.analysisSampleAspectRatio.present
          ? data.analysisSampleAspectRatio.value
          : this.analysisSampleAspectRatio,
      analysisDisplayAspectRatio: data.analysisDisplayAspectRatio.present
          ? data.analysisDisplayAspectRatio.value
          : this.analysisDisplayAspectRatio,
      analysisVideoRotationDegrees: data.analysisVideoRotationDegrees.present
          ? data.analysisVideoRotationDegrees.value
          : this.analysisVideoRotationDegrees,
      analysisFieldOrder: data.analysisFieldOrder.present
          ? data.analysisFieldOrder.value
          : this.analysisFieldOrder,
      analysisVideoBitrate: data.analysisVideoBitrate.present
          ? data.analysisVideoBitrate.value
          : this.analysisVideoBitrate,
      analysisAudioBitrate: data.analysisAudioBitrate.present
          ? data.analysisAudioBitrate.value
          : this.analysisAudioBitrate,
      analysisContainerBitrate: data.analysisContainerBitrate.present
          ? data.analysisContainerBitrate.value
          : this.analysisContainerBitrate,
      analysisEstimatedBitrate: data.analysisEstimatedBitrate.present
          ? data.analysisEstimatedBitrate.value
          : this.analysisEstimatedBitrate,
      analysisContainerFormat: data.analysisContainerFormat.present
          ? data.analysisContainerFormat.value
          : this.analysisContainerFormat,
      analysisAudioChannels: data.analysisAudioChannels.present
          ? data.analysisAudioChannels.value
          : this.analysisAudioChannels,
      analysisAudioSampleRate: data.analysisAudioSampleRate.present
          ? data.analysisAudioSampleRate.value
          : this.analysisAudioSampleRate,
      analysisAudioChannelLayout: data.analysisAudioChannelLayout.present
          ? data.analysisAudioChannelLayout.value
          : this.analysisAudioChannelLayout,
      analysisAudioStreamIndex: data.analysisAudioStreamIndex.present
          ? data.analysisAudioStreamIndex.value
          : this.analysisAudioStreamIndex,
      analysisAudioStreamsJson: data.analysisAudioStreamsJson.present
          ? data.analysisAudioStreamsJson.value
          : this.analysisAudioStreamsJson,
      mediaConfigJson: data.mediaConfigJson.present
          ? data.mediaConfigJson.value
          : this.mediaConfigJson,
      analysisImageWidth: data.analysisImageWidth.present
          ? data.analysisImageWidth.value
          : this.analysisImageWidth,
      analysisImageHeight: data.analysisImageHeight.present
          ? data.analysisImageHeight.value
          : this.analysisImageHeight,
      analysisImageCodec: data.analysisImageCodec.present
          ? data.analysisImageCodec.value
          : this.analysisImageCodec,
      analysisImagePixelFormat: data.analysisImagePixelFormat.present
          ? data.analysisImagePixelFormat.value
          : this.analysisImagePixelFormat,
      analysisImageBitDepth: data.analysisImageBitDepth.present
          ? data.analysisImageBitDepth.value
          : this.analysisImageBitDepth,
      analysisUpdatedAt: data.analysisUpdatedAt.present
          ? data.analysisUpdatedAt.value
          : this.analysisUpdatedAt,
      analysisErrorMessage: data.analysisErrorMessage.present
          ? data.analysisErrorMessage.value
          : this.analysisErrorMessage,
      outputFormat: data.outputFormat.present
          ? data.outputFormat.value
          : this.outputFormat,
      videoCodec: data.videoCodec.present
          ? data.videoCodec.value
          : this.videoCodec,
      encoderBackend: data.encoderBackend.present
          ? data.encoderBackend.value
          : this.encoderBackend,
      resolutionPreset: data.resolutionPreset.present
          ? data.resolutionPreset.value
          : this.resolutionPreset,
      outputDirectory: data.outputDirectory.present
          ? data.outputDirectory.value
          : this.outputDirectory,
      compressionCrf: data.compressionCrf.present
          ? data.compressionCrf.value
          : this.compressionCrf,
      compressionMode: data.compressionMode.present
          ? data.compressionMode.value
          : this.compressionMode,
      smartPreset: data.smartPreset.present
          ? data.smartPreset.value
          : this.smartPreset,
      targetSizeBytes: data.targetSizeBytes.present
          ? data.targetSizeBytes.value
          : this.targetSizeBytes,
      targetSizeRatio: data.targetSizeRatio.present
          ? data.targetSizeRatio.value
          : this.targetSizeRatio,
      outputFileName: data.outputFileName.present
          ? data.outputFileName.value
          : this.outputFileName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      failedAt: data.failedAt.present ? data.failedAt.value : this.failedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('inputPath: $inputPath, ')
          ..write('fileName: $fileName, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('folderId: $folderId, ')
          ..write('folderSortOrder: $folderSortOrder, ')
          ..write('outputPath: $outputPath, ')
          ..write('outputFileSize: $outputFileSize, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('failureJson: $failureJson, ')
          ..write('policyTagsJson: $policyTagsJson, ')
          ..write('sourceFileSize: $sourceFileSize, ')
          ..write('sourceLastModifiedAt: $sourceLastModifiedAt, ')
          ..write('analysisDurationMs: $analysisDurationMs, ')
          ..write('analysisVideoWidth: $analysisVideoWidth, ')
          ..write('analysisVideoHeight: $analysisVideoHeight, ')
          ..write('analysisVideoCodec: $analysisVideoCodec, ')
          ..write('analysisAudioCodec: $analysisAudioCodec, ')
          ..write('analysisVideoPixelFormat: $analysisVideoPixelFormat, ')
          ..write('analysisVideoBitDepth: $analysisVideoBitDepth, ')
          ..write('analysisColorRange: $analysisColorRange, ')
          ..write('analysisColorSpace: $analysisColorSpace, ')
          ..write('analysisColorTransfer: $analysisColorTransfer, ')
          ..write('analysisColorPrimaries: $analysisColorPrimaries, ')
          ..write('analysisChromaLocation: $analysisChromaLocation, ')
          ..write(
            'analysisMasteringDisplayMetadata: $analysisMasteringDisplayMetadata, ',
          )
          ..write(
            'analysisMasteringDisplayMaxLuminance: $analysisMasteringDisplayMaxLuminance, ',
          )
          ..write(
            'analysisMaxContentLightLevel: $analysisMaxContentLightLevel, ',
          )
          ..write(
            'analysisMaxFrameAverageLightLevel: $analysisMaxFrameAverageLightLevel, ',
          )
          ..write('analysisDolbyVisionProfile: $analysisDolbyVisionProfile, ')
          ..write(
            'analysisDolbyVisionCompatibilityId: $analysisDolbyVisionCompatibilityId, ',
          )
          ..write('analysisAverageFrameRate: $analysisAverageFrameRate, ')
          ..write('analysisRealFrameRate: $analysisRealFrameRate, ')
          ..write('analysisSampleAspectRatio: $analysisSampleAspectRatio, ')
          ..write('analysisDisplayAspectRatio: $analysisDisplayAspectRatio, ')
          ..write(
            'analysisVideoRotationDegrees: $analysisVideoRotationDegrees, ',
          )
          ..write('analysisFieldOrder: $analysisFieldOrder, ')
          ..write('analysisVideoBitrate: $analysisVideoBitrate, ')
          ..write('analysisAudioBitrate: $analysisAudioBitrate, ')
          ..write('analysisContainerBitrate: $analysisContainerBitrate, ')
          ..write('analysisEstimatedBitrate: $analysisEstimatedBitrate, ')
          ..write('analysisContainerFormat: $analysisContainerFormat, ')
          ..write('analysisAudioChannels: $analysisAudioChannels, ')
          ..write('analysisAudioSampleRate: $analysisAudioSampleRate, ')
          ..write('analysisAudioChannelLayout: $analysisAudioChannelLayout, ')
          ..write('analysisAudioStreamIndex: $analysisAudioStreamIndex, ')
          ..write('analysisAudioStreamsJson: $analysisAudioStreamsJson, ')
          ..write('mediaConfigJson: $mediaConfigJson, ')
          ..write('analysisImageWidth: $analysisImageWidth, ')
          ..write('analysisImageHeight: $analysisImageHeight, ')
          ..write('analysisImageCodec: $analysisImageCodec, ')
          ..write('analysisImagePixelFormat: $analysisImagePixelFormat, ')
          ..write('analysisImageBitDepth: $analysisImageBitDepth, ')
          ..write('analysisUpdatedAt: $analysisUpdatedAt, ')
          ..write('analysisErrorMessage: $analysisErrorMessage, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('encoderBackend: $encoderBackend, ')
          ..write('resolutionPreset: $resolutionPreset, ')
          ..write('outputDirectory: $outputDirectory, ')
          ..write('compressionCrf: $compressionCrf, ')
          ..write('compressionMode: $compressionMode, ')
          ..write('smartPreset: $smartPreset, ')
          ..write('targetSizeBytes: $targetSizeBytes, ')
          ..write('targetSizeRatio: $targetSizeRatio, ')
          ..write('outputFileName: $outputFileName, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('failedAt: $failedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    inputPath,
    fileName,
    mediaKind,
    purpose,
    status,
    progress,
    sortOrder,
    folderId,
    folderSortOrder,
    outputPath,
    outputFileSize,
    errorMessage,
    failureJson,
    policyTagsJson,
    sourceFileSize,
    sourceLastModifiedAt,
    analysisDurationMs,
    analysisVideoWidth,
    analysisVideoHeight,
    analysisVideoCodec,
    analysisAudioCodec,
    analysisVideoPixelFormat,
    analysisVideoBitDepth,
    analysisColorRange,
    analysisColorSpace,
    analysisColorTransfer,
    analysisColorPrimaries,
    analysisChromaLocation,
    analysisMasteringDisplayMetadata,
    analysisMasteringDisplayMaxLuminance,
    analysisMaxContentLightLevel,
    analysisMaxFrameAverageLightLevel,
    analysisDolbyVisionProfile,
    analysisDolbyVisionCompatibilityId,
    analysisAverageFrameRate,
    analysisRealFrameRate,
    analysisSampleAspectRatio,
    analysisDisplayAspectRatio,
    analysisVideoRotationDegrees,
    analysisFieldOrder,
    analysisVideoBitrate,
    analysisAudioBitrate,
    analysisContainerBitrate,
    analysisEstimatedBitrate,
    analysisContainerFormat,
    analysisAudioChannels,
    analysisAudioSampleRate,
    analysisAudioChannelLayout,
    analysisAudioStreamIndex,
    analysisAudioStreamsJson,
    mediaConfigJson,
    analysisImageWidth,
    analysisImageHeight,
    analysisImageCodec,
    analysisImagePixelFormat,
    analysisImageBitDepth,
    analysisUpdatedAt,
    analysisErrorMessage,
    outputFormat,
    videoCodec,
    encoderBackend,
    resolutionPreset,
    outputDirectory,
    compressionCrf,
    compressionMode,
    smartPreset,
    targetSizeBytes,
    targetSizeRatio,
    outputFileName,
    createdAt,
    startedAt,
    completedAt,
    failedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.inputPath == this.inputPath &&
          other.fileName == this.fileName &&
          other.mediaKind == this.mediaKind &&
          other.purpose == this.purpose &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.sortOrder == this.sortOrder &&
          other.folderId == this.folderId &&
          other.folderSortOrder == this.folderSortOrder &&
          other.outputPath == this.outputPath &&
          other.outputFileSize == this.outputFileSize &&
          other.errorMessage == this.errorMessage &&
          other.failureJson == this.failureJson &&
          other.policyTagsJson == this.policyTagsJson &&
          other.sourceFileSize == this.sourceFileSize &&
          other.sourceLastModifiedAt == this.sourceLastModifiedAt &&
          other.analysisDurationMs == this.analysisDurationMs &&
          other.analysisVideoWidth == this.analysisVideoWidth &&
          other.analysisVideoHeight == this.analysisVideoHeight &&
          other.analysisVideoCodec == this.analysisVideoCodec &&
          other.analysisAudioCodec == this.analysisAudioCodec &&
          other.analysisVideoPixelFormat == this.analysisVideoPixelFormat &&
          other.analysisVideoBitDepth == this.analysisVideoBitDepth &&
          other.analysisColorRange == this.analysisColorRange &&
          other.analysisColorSpace == this.analysisColorSpace &&
          other.analysisColorTransfer == this.analysisColorTransfer &&
          other.analysisColorPrimaries == this.analysisColorPrimaries &&
          other.analysisChromaLocation == this.analysisChromaLocation &&
          other.analysisMasteringDisplayMetadata ==
              this.analysisMasteringDisplayMetadata &&
          other.analysisMasteringDisplayMaxLuminance ==
              this.analysisMasteringDisplayMaxLuminance &&
          other.analysisMaxContentLightLevel ==
              this.analysisMaxContentLightLevel &&
          other.analysisMaxFrameAverageLightLevel ==
              this.analysisMaxFrameAverageLightLevel &&
          other.analysisDolbyVisionProfile == this.analysisDolbyVisionProfile &&
          other.analysisDolbyVisionCompatibilityId ==
              this.analysisDolbyVisionCompatibilityId &&
          other.analysisAverageFrameRate == this.analysisAverageFrameRate &&
          other.analysisRealFrameRate == this.analysisRealFrameRate &&
          other.analysisSampleAspectRatio == this.analysisSampleAspectRatio &&
          other.analysisDisplayAspectRatio == this.analysisDisplayAspectRatio &&
          other.analysisVideoRotationDegrees ==
              this.analysisVideoRotationDegrees &&
          other.analysisFieldOrder == this.analysisFieldOrder &&
          other.analysisVideoBitrate == this.analysisVideoBitrate &&
          other.analysisAudioBitrate == this.analysisAudioBitrate &&
          other.analysisContainerBitrate == this.analysisContainerBitrate &&
          other.analysisEstimatedBitrate == this.analysisEstimatedBitrate &&
          other.analysisContainerFormat == this.analysisContainerFormat &&
          other.analysisAudioChannels == this.analysisAudioChannels &&
          other.analysisAudioSampleRate == this.analysisAudioSampleRate &&
          other.analysisAudioChannelLayout == this.analysisAudioChannelLayout &&
          other.analysisAudioStreamIndex == this.analysisAudioStreamIndex &&
          other.analysisAudioStreamsJson == this.analysisAudioStreamsJson &&
          other.mediaConfigJson == this.mediaConfigJson &&
          other.analysisImageWidth == this.analysisImageWidth &&
          other.analysisImageHeight == this.analysisImageHeight &&
          other.analysisImageCodec == this.analysisImageCodec &&
          other.analysisImagePixelFormat == this.analysisImagePixelFormat &&
          other.analysisImageBitDepth == this.analysisImageBitDepth &&
          other.analysisUpdatedAt == this.analysisUpdatedAt &&
          other.analysisErrorMessage == this.analysisErrorMessage &&
          other.outputFormat == this.outputFormat &&
          other.videoCodec == this.videoCodec &&
          other.encoderBackend == this.encoderBackend &&
          other.resolutionPreset == this.resolutionPreset &&
          other.outputDirectory == this.outputDirectory &&
          other.compressionCrf == this.compressionCrf &&
          other.compressionMode == this.compressionMode &&
          other.smartPreset == this.smartPreset &&
          other.targetSizeBytes == this.targetSizeBytes &&
          other.targetSizeRatio == this.targetSizeRatio &&
          other.outputFileName == this.outputFileName &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.failedAt == this.failedAt);
}

class TaskRowsCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String> inputPath;
  final Value<String> fileName;
  final Value<String> mediaKind;
  final Value<String> purpose;
  final Value<String> status;
  final Value<double> progress;
  final Value<int> sortOrder;
  final Value<String?> folderId;
  final Value<int?> folderSortOrder;
  final Value<String?> outputPath;
  final Value<int?> outputFileSize;
  final Value<String?> errorMessage;
  final Value<String?> failureJson;
  final Value<String?> policyTagsJson;
  final Value<int?> sourceFileSize;
  final Value<int?> sourceLastModifiedAt;
  final Value<int?> analysisDurationMs;
  final Value<int?> analysisVideoWidth;
  final Value<int?> analysisVideoHeight;
  final Value<String?> analysisVideoCodec;
  final Value<String?> analysisAudioCodec;
  final Value<String?> analysisVideoPixelFormat;
  final Value<int?> analysisVideoBitDepth;
  final Value<String?> analysisColorRange;
  final Value<String?> analysisColorSpace;
  final Value<String?> analysisColorTransfer;
  final Value<String?> analysisColorPrimaries;
  final Value<String?> analysisChromaLocation;
  final Value<String?> analysisMasteringDisplayMetadata;
  final Value<double?> analysisMasteringDisplayMaxLuminance;
  final Value<int?> analysisMaxContentLightLevel;
  final Value<int?> analysisMaxFrameAverageLightLevel;
  final Value<int?> analysisDolbyVisionProfile;
  final Value<int?> analysisDolbyVisionCompatibilityId;
  final Value<String?> analysisAverageFrameRate;
  final Value<String?> analysisRealFrameRate;
  final Value<String?> analysisSampleAspectRatio;
  final Value<String?> analysisDisplayAspectRatio;
  final Value<int?> analysisVideoRotationDegrees;
  final Value<String?> analysisFieldOrder;
  final Value<int?> analysisVideoBitrate;
  final Value<int?> analysisAudioBitrate;
  final Value<int?> analysisContainerBitrate;
  final Value<int?> analysisEstimatedBitrate;
  final Value<String?> analysisContainerFormat;
  final Value<int?> analysisAudioChannels;
  final Value<int?> analysisAudioSampleRate;
  final Value<String?> analysisAudioChannelLayout;
  final Value<int?> analysisAudioStreamIndex;
  final Value<String?> analysisAudioStreamsJson;
  final Value<String?> mediaConfigJson;
  final Value<int?> analysisImageWidth;
  final Value<int?> analysisImageHeight;
  final Value<String?> analysisImageCodec;
  final Value<String?> analysisImagePixelFormat;
  final Value<int?> analysisImageBitDepth;
  final Value<int?> analysisUpdatedAt;
  final Value<String?> analysisErrorMessage;
  final Value<String> outputFormat;
  final Value<String> videoCodec;
  final Value<String> encoderBackend;
  final Value<String> resolutionPreset;
  final Value<String> outputDirectory;
  final Value<int> compressionCrf;
  final Value<String> compressionMode;
  final Value<String?> smartPreset;
  final Value<int?> targetSizeBytes;
  final Value<double?> targetSizeRatio;
  final Value<String> outputFileName;
  final Value<int> createdAt;
  final Value<int?> startedAt;
  final Value<int?> completedAt;
  final Value<int?> failedAt;
  final Value<int> rowid;
  const TaskRowsCompanion({
    this.id = const Value.absent(),
    this.inputPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.purpose = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.folderId = const Value.absent(),
    this.folderSortOrder = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.outputFileSize = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.failureJson = const Value.absent(),
    this.policyTagsJson = const Value.absent(),
    this.sourceFileSize = const Value.absent(),
    this.sourceLastModifiedAt = const Value.absent(),
    this.analysisDurationMs = const Value.absent(),
    this.analysisVideoWidth = const Value.absent(),
    this.analysisVideoHeight = const Value.absent(),
    this.analysisVideoCodec = const Value.absent(),
    this.analysisAudioCodec = const Value.absent(),
    this.analysisVideoPixelFormat = const Value.absent(),
    this.analysisVideoBitDepth = const Value.absent(),
    this.analysisColorRange = const Value.absent(),
    this.analysisColorSpace = const Value.absent(),
    this.analysisColorTransfer = const Value.absent(),
    this.analysisColorPrimaries = const Value.absent(),
    this.analysisChromaLocation = const Value.absent(),
    this.analysisMasteringDisplayMetadata = const Value.absent(),
    this.analysisMasteringDisplayMaxLuminance = const Value.absent(),
    this.analysisMaxContentLightLevel = const Value.absent(),
    this.analysisMaxFrameAverageLightLevel = const Value.absent(),
    this.analysisDolbyVisionProfile = const Value.absent(),
    this.analysisDolbyVisionCompatibilityId = const Value.absent(),
    this.analysisAverageFrameRate = const Value.absent(),
    this.analysisRealFrameRate = const Value.absent(),
    this.analysisSampleAspectRatio = const Value.absent(),
    this.analysisDisplayAspectRatio = const Value.absent(),
    this.analysisVideoRotationDegrees = const Value.absent(),
    this.analysisFieldOrder = const Value.absent(),
    this.analysisVideoBitrate = const Value.absent(),
    this.analysisAudioBitrate = const Value.absent(),
    this.analysisContainerBitrate = const Value.absent(),
    this.analysisEstimatedBitrate = const Value.absent(),
    this.analysisContainerFormat = const Value.absent(),
    this.analysisAudioChannels = const Value.absent(),
    this.analysisAudioSampleRate = const Value.absent(),
    this.analysisAudioChannelLayout = const Value.absent(),
    this.analysisAudioStreamIndex = const Value.absent(),
    this.analysisAudioStreamsJson = const Value.absent(),
    this.mediaConfigJson = const Value.absent(),
    this.analysisImageWidth = const Value.absent(),
    this.analysisImageHeight = const Value.absent(),
    this.analysisImageCodec = const Value.absent(),
    this.analysisImagePixelFormat = const Value.absent(),
    this.analysisImageBitDepth = const Value.absent(),
    this.analysisUpdatedAt = const Value.absent(),
    this.analysisErrorMessage = const Value.absent(),
    this.outputFormat = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.encoderBackend = const Value.absent(),
    this.resolutionPreset = const Value.absent(),
    this.outputDirectory = const Value.absent(),
    this.compressionCrf = const Value.absent(),
    this.compressionMode = const Value.absent(),
    this.smartPreset = const Value.absent(),
    this.targetSizeBytes = const Value.absent(),
    this.targetSizeRatio = const Value.absent(),
    this.outputFileName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.failedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskRowsCompanion.insert({
    required String id,
    required String inputPath,
    required String fileName,
    this.mediaKind = const Value.absent(),
    required String purpose,
    required String status,
    this.progress = const Value.absent(),
    required int sortOrder,
    this.folderId = const Value.absent(),
    this.folderSortOrder = const Value.absent(),
    this.outputPath = const Value.absent(),
    this.outputFileSize = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.failureJson = const Value.absent(),
    this.policyTagsJson = const Value.absent(),
    this.sourceFileSize = const Value.absent(),
    this.sourceLastModifiedAt = const Value.absent(),
    this.analysisDurationMs = const Value.absent(),
    this.analysisVideoWidth = const Value.absent(),
    this.analysisVideoHeight = const Value.absent(),
    this.analysisVideoCodec = const Value.absent(),
    this.analysisAudioCodec = const Value.absent(),
    this.analysisVideoPixelFormat = const Value.absent(),
    this.analysisVideoBitDepth = const Value.absent(),
    this.analysisColorRange = const Value.absent(),
    this.analysisColorSpace = const Value.absent(),
    this.analysisColorTransfer = const Value.absent(),
    this.analysisColorPrimaries = const Value.absent(),
    this.analysisChromaLocation = const Value.absent(),
    this.analysisMasteringDisplayMetadata = const Value.absent(),
    this.analysisMasteringDisplayMaxLuminance = const Value.absent(),
    this.analysisMaxContentLightLevel = const Value.absent(),
    this.analysisMaxFrameAverageLightLevel = const Value.absent(),
    this.analysisDolbyVisionProfile = const Value.absent(),
    this.analysisDolbyVisionCompatibilityId = const Value.absent(),
    this.analysisAverageFrameRate = const Value.absent(),
    this.analysisRealFrameRate = const Value.absent(),
    this.analysisSampleAspectRatio = const Value.absent(),
    this.analysisDisplayAspectRatio = const Value.absent(),
    this.analysisVideoRotationDegrees = const Value.absent(),
    this.analysisFieldOrder = const Value.absent(),
    this.analysisVideoBitrate = const Value.absent(),
    this.analysisAudioBitrate = const Value.absent(),
    this.analysisContainerBitrate = const Value.absent(),
    this.analysisEstimatedBitrate = const Value.absent(),
    this.analysisContainerFormat = const Value.absent(),
    this.analysisAudioChannels = const Value.absent(),
    this.analysisAudioSampleRate = const Value.absent(),
    this.analysisAudioChannelLayout = const Value.absent(),
    this.analysisAudioStreamIndex = const Value.absent(),
    this.analysisAudioStreamsJson = const Value.absent(),
    this.mediaConfigJson = const Value.absent(),
    this.analysisImageWidth = const Value.absent(),
    this.analysisImageHeight = const Value.absent(),
    this.analysisImageCodec = const Value.absent(),
    this.analysisImagePixelFormat = const Value.absent(),
    this.analysisImageBitDepth = const Value.absent(),
    this.analysisUpdatedAt = const Value.absent(),
    this.analysisErrorMessage = const Value.absent(),
    required String outputFormat,
    required String videoCodec,
    required String encoderBackend,
    required String resolutionPreset,
    required String outputDirectory,
    this.compressionCrf = const Value.absent(),
    this.compressionMode = const Value.absent(),
    this.smartPreset = const Value.absent(),
    this.targetSizeBytes = const Value.absent(),
    this.targetSizeRatio = const Value.absent(),
    this.outputFileName = const Value.absent(),
    required int createdAt,
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.failedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       inputPath = Value(inputPath),
       fileName = Value(fileName),
       purpose = Value(purpose),
       status = Value(status),
       sortOrder = Value(sortOrder),
       outputFormat = Value(outputFormat),
       videoCodec = Value(videoCodec),
       encoderBackend = Value(encoderBackend),
       resolutionPreset = Value(resolutionPreset),
       outputDirectory = Value(outputDirectory),
       createdAt = Value(createdAt);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? inputPath,
    Expression<String>? fileName,
    Expression<String>? mediaKind,
    Expression<String>? purpose,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<int>? sortOrder,
    Expression<String>? folderId,
    Expression<int>? folderSortOrder,
    Expression<String>? outputPath,
    Expression<int>? outputFileSize,
    Expression<String>? errorMessage,
    Expression<String>? failureJson,
    Expression<String>? policyTagsJson,
    Expression<int>? sourceFileSize,
    Expression<int>? sourceLastModifiedAt,
    Expression<int>? analysisDurationMs,
    Expression<int>? analysisVideoWidth,
    Expression<int>? analysisVideoHeight,
    Expression<String>? analysisVideoCodec,
    Expression<String>? analysisAudioCodec,
    Expression<String>? analysisVideoPixelFormat,
    Expression<int>? analysisVideoBitDepth,
    Expression<String>? analysisColorRange,
    Expression<String>? analysisColorSpace,
    Expression<String>? analysisColorTransfer,
    Expression<String>? analysisColorPrimaries,
    Expression<String>? analysisChromaLocation,
    Expression<String>? analysisMasteringDisplayMetadata,
    Expression<double>? analysisMasteringDisplayMaxLuminance,
    Expression<int>? analysisMaxContentLightLevel,
    Expression<int>? analysisMaxFrameAverageLightLevel,
    Expression<int>? analysisDolbyVisionProfile,
    Expression<int>? analysisDolbyVisionCompatibilityId,
    Expression<String>? analysisAverageFrameRate,
    Expression<String>? analysisRealFrameRate,
    Expression<String>? analysisSampleAspectRatio,
    Expression<String>? analysisDisplayAspectRatio,
    Expression<int>? analysisVideoRotationDegrees,
    Expression<String>? analysisFieldOrder,
    Expression<int>? analysisVideoBitrate,
    Expression<int>? analysisAudioBitrate,
    Expression<int>? analysisContainerBitrate,
    Expression<int>? analysisEstimatedBitrate,
    Expression<String>? analysisContainerFormat,
    Expression<int>? analysisAudioChannels,
    Expression<int>? analysisAudioSampleRate,
    Expression<String>? analysisAudioChannelLayout,
    Expression<int>? analysisAudioStreamIndex,
    Expression<String>? analysisAudioStreamsJson,
    Expression<String>? mediaConfigJson,
    Expression<int>? analysisImageWidth,
    Expression<int>? analysisImageHeight,
    Expression<String>? analysisImageCodec,
    Expression<String>? analysisImagePixelFormat,
    Expression<int>? analysisImageBitDepth,
    Expression<int>? analysisUpdatedAt,
    Expression<String>? analysisErrorMessage,
    Expression<String>? outputFormat,
    Expression<String>? videoCodec,
    Expression<String>? encoderBackend,
    Expression<String>? resolutionPreset,
    Expression<String>? outputDirectory,
    Expression<int>? compressionCrf,
    Expression<String>? compressionMode,
    Expression<String>? smartPreset,
    Expression<int>? targetSizeBytes,
    Expression<double>? targetSizeRatio,
    Expression<String>? outputFileName,
    Expression<int>? createdAt,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<int>? failedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (inputPath != null) 'input_path': inputPath,
      if (fileName != null) 'file_name': fileName,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (purpose != null) 'purpose': purpose,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (folderId != null) 'folder_id': folderId,
      if (folderSortOrder != null) 'folder_sort_order': folderSortOrder,
      if (outputPath != null) 'output_path': outputPath,
      if (outputFileSize != null) 'output_file_size': outputFileSize,
      if (errorMessage != null) 'error_message': errorMessage,
      if (failureJson != null) 'failure_json': failureJson,
      if (policyTagsJson != null) 'policy_tags_json': policyTagsJson,
      if (sourceFileSize != null) 'source_file_size': sourceFileSize,
      if (sourceLastModifiedAt != null)
        'source_last_modified_at': sourceLastModifiedAt,
      if (analysisDurationMs != null)
        'analysis_duration_ms': analysisDurationMs,
      if (analysisVideoWidth != null)
        'analysis_video_width': analysisVideoWidth,
      if (analysisVideoHeight != null)
        'analysis_video_height': analysisVideoHeight,
      if (analysisVideoCodec != null)
        'analysis_video_codec': analysisVideoCodec,
      if (analysisAudioCodec != null)
        'analysis_audio_codec': analysisAudioCodec,
      if (analysisVideoPixelFormat != null)
        'analysis_video_pixel_format': analysisVideoPixelFormat,
      if (analysisVideoBitDepth != null)
        'analysis_video_bit_depth': analysisVideoBitDepth,
      if (analysisColorRange != null)
        'analysis_color_range': analysisColorRange,
      if (analysisColorSpace != null)
        'analysis_color_space': analysisColorSpace,
      if (analysisColorTransfer != null)
        'analysis_color_transfer': analysisColorTransfer,
      if (analysisColorPrimaries != null)
        'analysis_color_primaries': analysisColorPrimaries,
      if (analysisChromaLocation != null)
        'analysis_chroma_location': analysisChromaLocation,
      if (analysisMasteringDisplayMetadata != null)
        'analysis_mastering_display_metadata': analysisMasteringDisplayMetadata,
      if (analysisMasteringDisplayMaxLuminance != null)
        'analysis_mastering_display_max_luminance':
            analysisMasteringDisplayMaxLuminance,
      if (analysisMaxContentLightLevel != null)
        'analysis_max_content_light_level': analysisMaxContentLightLevel,
      if (analysisMaxFrameAverageLightLevel != null)
        'analysis_max_frame_average_light_level':
            analysisMaxFrameAverageLightLevel,
      if (analysisDolbyVisionProfile != null)
        'analysis_dolby_vision_profile': analysisDolbyVisionProfile,
      if (analysisDolbyVisionCompatibilityId != null)
        'analysis_dolby_vision_compatibility_id':
            analysisDolbyVisionCompatibilityId,
      if (analysisAverageFrameRate != null)
        'analysis_average_frame_rate': analysisAverageFrameRate,
      if (analysisRealFrameRate != null)
        'analysis_real_frame_rate': analysisRealFrameRate,
      if (analysisSampleAspectRatio != null)
        'analysis_sample_aspect_ratio': analysisSampleAspectRatio,
      if (analysisDisplayAspectRatio != null)
        'analysis_display_aspect_ratio': analysisDisplayAspectRatio,
      if (analysisVideoRotationDegrees != null)
        'analysis_video_rotation_degrees': analysisVideoRotationDegrees,
      if (analysisFieldOrder != null)
        'analysis_field_order': analysisFieldOrder,
      if (analysisVideoBitrate != null)
        'analysis_video_bitrate': analysisVideoBitrate,
      if (analysisAudioBitrate != null)
        'analysis_audio_bitrate': analysisAudioBitrate,
      if (analysisContainerBitrate != null)
        'analysis_container_bitrate': analysisContainerBitrate,
      if (analysisEstimatedBitrate != null)
        'analysis_estimated_bitrate': analysisEstimatedBitrate,
      if (analysisContainerFormat != null)
        'analysis_container_format': analysisContainerFormat,
      if (analysisAudioChannels != null)
        'analysis_audio_channels': analysisAudioChannels,
      if (analysisAudioSampleRate != null)
        'analysis_audio_sample_rate': analysisAudioSampleRate,
      if (analysisAudioChannelLayout != null)
        'analysis_audio_channel_layout': analysisAudioChannelLayout,
      if (analysisAudioStreamIndex != null)
        'analysis_audio_stream_index': analysisAudioStreamIndex,
      if (analysisAudioStreamsJson != null)
        'analysis_audio_streams_json': analysisAudioStreamsJson,
      if (mediaConfigJson != null) 'media_config_json': mediaConfigJson,
      if (analysisImageWidth != null)
        'analysis_image_width': analysisImageWidth,
      if (analysisImageHeight != null)
        'analysis_image_height': analysisImageHeight,
      if (analysisImageCodec != null)
        'analysis_image_codec': analysisImageCodec,
      if (analysisImagePixelFormat != null)
        'analysis_image_pixel_format': analysisImagePixelFormat,
      if (analysisImageBitDepth != null)
        'analysis_image_bit_depth': analysisImageBitDepth,
      if (analysisUpdatedAt != null) 'analysis_updated_at': analysisUpdatedAt,
      if (analysisErrorMessage != null)
        'analysis_error_message': analysisErrorMessage,
      if (outputFormat != null) 'output_format': outputFormat,
      if (videoCodec != null) 'video_codec': videoCodec,
      if (encoderBackend != null) 'encoder_backend': encoderBackend,
      if (resolutionPreset != null) 'resolution_preset': resolutionPreset,
      if (outputDirectory != null) 'output_directory': outputDirectory,
      if (compressionCrf != null) 'compression_crf': compressionCrf,
      if (compressionMode != null) 'compression_mode': compressionMode,
      if (smartPreset != null) 'smart_preset': smartPreset,
      if (targetSizeBytes != null) 'target_size_bytes': targetSizeBytes,
      if (targetSizeRatio != null) 'target_size_ratio': targetSizeRatio,
      if (outputFileName != null) 'output_file_name': outputFileName,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (failedAt != null) 'failed_at': failedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? inputPath,
    Value<String>? fileName,
    Value<String>? mediaKind,
    Value<String>? purpose,
    Value<String>? status,
    Value<double>? progress,
    Value<int>? sortOrder,
    Value<String?>? folderId,
    Value<int?>? folderSortOrder,
    Value<String?>? outputPath,
    Value<int?>? outputFileSize,
    Value<String?>? errorMessage,
    Value<String?>? failureJson,
    Value<String?>? policyTagsJson,
    Value<int?>? sourceFileSize,
    Value<int?>? sourceLastModifiedAt,
    Value<int?>? analysisDurationMs,
    Value<int?>? analysisVideoWidth,
    Value<int?>? analysisVideoHeight,
    Value<String?>? analysisVideoCodec,
    Value<String?>? analysisAudioCodec,
    Value<String?>? analysisVideoPixelFormat,
    Value<int?>? analysisVideoBitDepth,
    Value<String?>? analysisColorRange,
    Value<String?>? analysisColorSpace,
    Value<String?>? analysisColorTransfer,
    Value<String?>? analysisColorPrimaries,
    Value<String?>? analysisChromaLocation,
    Value<String?>? analysisMasteringDisplayMetadata,
    Value<double?>? analysisMasteringDisplayMaxLuminance,
    Value<int?>? analysisMaxContentLightLevel,
    Value<int?>? analysisMaxFrameAverageLightLevel,
    Value<int?>? analysisDolbyVisionProfile,
    Value<int?>? analysisDolbyVisionCompatibilityId,
    Value<String?>? analysisAverageFrameRate,
    Value<String?>? analysisRealFrameRate,
    Value<String?>? analysisSampleAspectRatio,
    Value<String?>? analysisDisplayAspectRatio,
    Value<int?>? analysisVideoRotationDegrees,
    Value<String?>? analysisFieldOrder,
    Value<int?>? analysisVideoBitrate,
    Value<int?>? analysisAudioBitrate,
    Value<int?>? analysisContainerBitrate,
    Value<int?>? analysisEstimatedBitrate,
    Value<String?>? analysisContainerFormat,
    Value<int?>? analysisAudioChannels,
    Value<int?>? analysisAudioSampleRate,
    Value<String?>? analysisAudioChannelLayout,
    Value<int?>? analysisAudioStreamIndex,
    Value<String?>? analysisAudioStreamsJson,
    Value<String?>? mediaConfigJson,
    Value<int?>? analysisImageWidth,
    Value<int?>? analysisImageHeight,
    Value<String?>? analysisImageCodec,
    Value<String?>? analysisImagePixelFormat,
    Value<int?>? analysisImageBitDepth,
    Value<int?>? analysisUpdatedAt,
    Value<String?>? analysisErrorMessage,
    Value<String>? outputFormat,
    Value<String>? videoCodec,
    Value<String>? encoderBackend,
    Value<String>? resolutionPreset,
    Value<String>? outputDirectory,
    Value<int>? compressionCrf,
    Value<String>? compressionMode,
    Value<String?>? smartPreset,
    Value<int?>? targetSizeBytes,
    Value<double?>? targetSizeRatio,
    Value<String>? outputFileName,
    Value<int>? createdAt,
    Value<int?>? startedAt,
    Value<int?>? completedAt,
    Value<int?>? failedAt,
    Value<int>? rowid,
  }) {
    return TaskRowsCompanion(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      fileName: fileName ?? this.fileName,
      mediaKind: mediaKind ?? this.mediaKind,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sortOrder: sortOrder ?? this.sortOrder,
      folderId: folderId ?? this.folderId,
      folderSortOrder: folderSortOrder ?? this.folderSortOrder,
      outputPath: outputPath ?? this.outputPath,
      outputFileSize: outputFileSize ?? this.outputFileSize,
      errorMessage: errorMessage ?? this.errorMessage,
      failureJson: failureJson ?? this.failureJson,
      policyTagsJson: policyTagsJson ?? this.policyTagsJson,
      sourceFileSize: sourceFileSize ?? this.sourceFileSize,
      sourceLastModifiedAt: sourceLastModifiedAt ?? this.sourceLastModifiedAt,
      analysisDurationMs: analysisDurationMs ?? this.analysisDurationMs,
      analysisVideoWidth: analysisVideoWidth ?? this.analysisVideoWidth,
      analysisVideoHeight: analysisVideoHeight ?? this.analysisVideoHeight,
      analysisVideoCodec: analysisVideoCodec ?? this.analysisVideoCodec,
      analysisAudioCodec: analysisAudioCodec ?? this.analysisAudioCodec,
      analysisVideoPixelFormat:
          analysisVideoPixelFormat ?? this.analysisVideoPixelFormat,
      analysisVideoBitDepth:
          analysisVideoBitDepth ?? this.analysisVideoBitDepth,
      analysisColorRange: analysisColorRange ?? this.analysisColorRange,
      analysisColorSpace: analysisColorSpace ?? this.analysisColorSpace,
      analysisColorTransfer:
          analysisColorTransfer ?? this.analysisColorTransfer,
      analysisColorPrimaries:
          analysisColorPrimaries ?? this.analysisColorPrimaries,
      analysisChromaLocation:
          analysisChromaLocation ?? this.analysisChromaLocation,
      analysisMasteringDisplayMetadata:
          analysisMasteringDisplayMetadata ??
          this.analysisMasteringDisplayMetadata,
      analysisMasteringDisplayMaxLuminance:
          analysisMasteringDisplayMaxLuminance ??
          this.analysisMasteringDisplayMaxLuminance,
      analysisMaxContentLightLevel:
          analysisMaxContentLightLevel ?? this.analysisMaxContentLightLevel,
      analysisMaxFrameAverageLightLevel:
          analysisMaxFrameAverageLightLevel ??
          this.analysisMaxFrameAverageLightLevel,
      analysisDolbyVisionProfile:
          analysisDolbyVisionProfile ?? this.analysisDolbyVisionProfile,
      analysisDolbyVisionCompatibilityId:
          analysisDolbyVisionCompatibilityId ??
          this.analysisDolbyVisionCompatibilityId,
      analysisAverageFrameRate:
          analysisAverageFrameRate ?? this.analysisAverageFrameRate,
      analysisRealFrameRate:
          analysisRealFrameRate ?? this.analysisRealFrameRate,
      analysisSampleAspectRatio:
          analysisSampleAspectRatio ?? this.analysisSampleAspectRatio,
      analysisDisplayAspectRatio:
          analysisDisplayAspectRatio ?? this.analysisDisplayAspectRatio,
      analysisVideoRotationDegrees:
          analysisVideoRotationDegrees ?? this.analysisVideoRotationDegrees,
      analysisFieldOrder: analysisFieldOrder ?? this.analysisFieldOrder,
      analysisVideoBitrate: analysisVideoBitrate ?? this.analysisVideoBitrate,
      analysisAudioBitrate: analysisAudioBitrate ?? this.analysisAudioBitrate,
      analysisContainerBitrate:
          analysisContainerBitrate ?? this.analysisContainerBitrate,
      analysisEstimatedBitrate:
          analysisEstimatedBitrate ?? this.analysisEstimatedBitrate,
      analysisContainerFormat:
          analysisContainerFormat ?? this.analysisContainerFormat,
      analysisAudioChannels:
          analysisAudioChannels ?? this.analysisAudioChannels,
      analysisAudioSampleRate:
          analysisAudioSampleRate ?? this.analysisAudioSampleRate,
      analysisAudioChannelLayout:
          analysisAudioChannelLayout ?? this.analysisAudioChannelLayout,
      analysisAudioStreamIndex:
          analysisAudioStreamIndex ?? this.analysisAudioStreamIndex,
      analysisAudioStreamsJson:
          analysisAudioStreamsJson ?? this.analysisAudioStreamsJson,
      mediaConfigJson: mediaConfigJson ?? this.mediaConfigJson,
      analysisImageWidth: analysisImageWidth ?? this.analysisImageWidth,
      analysisImageHeight: analysisImageHeight ?? this.analysisImageHeight,
      analysisImageCodec: analysisImageCodec ?? this.analysisImageCodec,
      analysisImagePixelFormat:
          analysisImagePixelFormat ?? this.analysisImagePixelFormat,
      analysisImageBitDepth:
          analysisImageBitDepth ?? this.analysisImageBitDepth,
      analysisUpdatedAt: analysisUpdatedAt ?? this.analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage ?? this.analysisErrorMessage,
      outputFormat: outputFormat ?? this.outputFormat,
      videoCodec: videoCodec ?? this.videoCodec,
      encoderBackend: encoderBackend ?? this.encoderBackend,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      compressionCrf: compressionCrf ?? this.compressionCrf,
      compressionMode: compressionMode ?? this.compressionMode,
      smartPreset: smartPreset ?? this.smartPreset,
      targetSizeBytes: targetSizeBytes ?? this.targetSizeBytes,
      targetSizeRatio: targetSizeRatio ?? this.targetSizeRatio,
      outputFileName: outputFileName ?? this.outputFileName,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      failedAt: failedAt ?? this.failedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (inputPath.present) {
      map['input_path'] = Variable<String>(inputPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (folderSortOrder.present) {
      map['folder_sort_order'] = Variable<int>(folderSortOrder.value);
    }
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (outputFileSize.present) {
      map['output_file_size'] = Variable<int>(outputFileSize.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (failureJson.present) {
      map['failure_json'] = Variable<String>(failureJson.value);
    }
    if (policyTagsJson.present) {
      map['policy_tags_json'] = Variable<String>(policyTagsJson.value);
    }
    if (sourceFileSize.present) {
      map['source_file_size'] = Variable<int>(sourceFileSize.value);
    }
    if (sourceLastModifiedAt.present) {
      map['source_last_modified_at'] = Variable<int>(
        sourceLastModifiedAt.value,
      );
    }
    if (analysisDurationMs.present) {
      map['analysis_duration_ms'] = Variable<int>(analysisDurationMs.value);
    }
    if (analysisVideoWidth.present) {
      map['analysis_video_width'] = Variable<int>(analysisVideoWidth.value);
    }
    if (analysisVideoHeight.present) {
      map['analysis_video_height'] = Variable<int>(analysisVideoHeight.value);
    }
    if (analysisVideoCodec.present) {
      map['analysis_video_codec'] = Variable<String>(analysisVideoCodec.value);
    }
    if (analysisAudioCodec.present) {
      map['analysis_audio_codec'] = Variable<String>(analysisAudioCodec.value);
    }
    if (analysisVideoPixelFormat.present) {
      map['analysis_video_pixel_format'] = Variable<String>(
        analysisVideoPixelFormat.value,
      );
    }
    if (analysisVideoBitDepth.present) {
      map['analysis_video_bit_depth'] = Variable<int>(
        analysisVideoBitDepth.value,
      );
    }
    if (analysisColorRange.present) {
      map['analysis_color_range'] = Variable<String>(analysisColorRange.value);
    }
    if (analysisColorSpace.present) {
      map['analysis_color_space'] = Variable<String>(analysisColorSpace.value);
    }
    if (analysisColorTransfer.present) {
      map['analysis_color_transfer'] = Variable<String>(
        analysisColorTransfer.value,
      );
    }
    if (analysisColorPrimaries.present) {
      map['analysis_color_primaries'] = Variable<String>(
        analysisColorPrimaries.value,
      );
    }
    if (analysisChromaLocation.present) {
      map['analysis_chroma_location'] = Variable<String>(
        analysisChromaLocation.value,
      );
    }
    if (analysisMasteringDisplayMetadata.present) {
      map['analysis_mastering_display_metadata'] = Variable<String>(
        analysisMasteringDisplayMetadata.value,
      );
    }
    if (analysisMasteringDisplayMaxLuminance.present) {
      map['analysis_mastering_display_max_luminance'] = Variable<double>(
        analysisMasteringDisplayMaxLuminance.value,
      );
    }
    if (analysisMaxContentLightLevel.present) {
      map['analysis_max_content_light_level'] = Variable<int>(
        analysisMaxContentLightLevel.value,
      );
    }
    if (analysisMaxFrameAverageLightLevel.present) {
      map['analysis_max_frame_average_light_level'] = Variable<int>(
        analysisMaxFrameAverageLightLevel.value,
      );
    }
    if (analysisDolbyVisionProfile.present) {
      map['analysis_dolby_vision_profile'] = Variable<int>(
        analysisDolbyVisionProfile.value,
      );
    }
    if (analysisDolbyVisionCompatibilityId.present) {
      map['analysis_dolby_vision_compatibility_id'] = Variable<int>(
        analysisDolbyVisionCompatibilityId.value,
      );
    }
    if (analysisAverageFrameRate.present) {
      map['analysis_average_frame_rate'] = Variable<String>(
        analysisAverageFrameRate.value,
      );
    }
    if (analysisRealFrameRate.present) {
      map['analysis_real_frame_rate'] = Variable<String>(
        analysisRealFrameRate.value,
      );
    }
    if (analysisSampleAspectRatio.present) {
      map['analysis_sample_aspect_ratio'] = Variable<String>(
        analysisSampleAspectRatio.value,
      );
    }
    if (analysisDisplayAspectRatio.present) {
      map['analysis_display_aspect_ratio'] = Variable<String>(
        analysisDisplayAspectRatio.value,
      );
    }
    if (analysisVideoRotationDegrees.present) {
      map['analysis_video_rotation_degrees'] = Variable<int>(
        analysisVideoRotationDegrees.value,
      );
    }
    if (analysisFieldOrder.present) {
      map['analysis_field_order'] = Variable<String>(analysisFieldOrder.value);
    }
    if (analysisVideoBitrate.present) {
      map['analysis_video_bitrate'] = Variable<int>(analysisVideoBitrate.value);
    }
    if (analysisAudioBitrate.present) {
      map['analysis_audio_bitrate'] = Variable<int>(analysisAudioBitrate.value);
    }
    if (analysisContainerBitrate.present) {
      map['analysis_container_bitrate'] = Variable<int>(
        analysisContainerBitrate.value,
      );
    }
    if (analysisEstimatedBitrate.present) {
      map['analysis_estimated_bitrate'] = Variable<int>(
        analysisEstimatedBitrate.value,
      );
    }
    if (analysisContainerFormat.present) {
      map['analysis_container_format'] = Variable<String>(
        analysisContainerFormat.value,
      );
    }
    if (analysisAudioChannels.present) {
      map['analysis_audio_channels'] = Variable<int>(
        analysisAudioChannels.value,
      );
    }
    if (analysisAudioSampleRate.present) {
      map['analysis_audio_sample_rate'] = Variable<int>(
        analysisAudioSampleRate.value,
      );
    }
    if (analysisAudioChannelLayout.present) {
      map['analysis_audio_channel_layout'] = Variable<String>(
        analysisAudioChannelLayout.value,
      );
    }
    if (analysisAudioStreamIndex.present) {
      map['analysis_audio_stream_index'] = Variable<int>(
        analysisAudioStreamIndex.value,
      );
    }
    if (analysisAudioStreamsJson.present) {
      map['analysis_audio_streams_json'] = Variable<String>(
        analysisAudioStreamsJson.value,
      );
    }
    if (mediaConfigJson.present) {
      map['media_config_json'] = Variable<String>(mediaConfigJson.value);
    }
    if (analysisImageWidth.present) {
      map['analysis_image_width'] = Variable<int>(analysisImageWidth.value);
    }
    if (analysisImageHeight.present) {
      map['analysis_image_height'] = Variable<int>(analysisImageHeight.value);
    }
    if (analysisImageCodec.present) {
      map['analysis_image_codec'] = Variable<String>(analysisImageCodec.value);
    }
    if (analysisImagePixelFormat.present) {
      map['analysis_image_pixel_format'] = Variable<String>(
        analysisImagePixelFormat.value,
      );
    }
    if (analysisImageBitDepth.present) {
      map['analysis_image_bit_depth'] = Variable<int>(
        analysisImageBitDepth.value,
      );
    }
    if (analysisUpdatedAt.present) {
      map['analysis_updated_at'] = Variable<int>(analysisUpdatedAt.value);
    }
    if (analysisErrorMessage.present) {
      map['analysis_error_message'] = Variable<String>(
        analysisErrorMessage.value,
      );
    }
    if (outputFormat.present) {
      map['output_format'] = Variable<String>(outputFormat.value);
    }
    if (videoCodec.present) {
      map['video_codec'] = Variable<String>(videoCodec.value);
    }
    if (encoderBackend.present) {
      map['encoder_backend'] = Variable<String>(encoderBackend.value);
    }
    if (resolutionPreset.present) {
      map['resolution_preset'] = Variable<String>(resolutionPreset.value);
    }
    if (outputDirectory.present) {
      map['output_directory'] = Variable<String>(outputDirectory.value);
    }
    if (compressionCrf.present) {
      map['compression_crf'] = Variable<int>(compressionCrf.value);
    }
    if (compressionMode.present) {
      map['compression_mode'] = Variable<String>(compressionMode.value);
    }
    if (smartPreset.present) {
      map['smart_preset'] = Variable<String>(smartPreset.value);
    }
    if (targetSizeBytes.present) {
      map['target_size_bytes'] = Variable<int>(targetSizeBytes.value);
    }
    if (targetSizeRatio.present) {
      map['target_size_ratio'] = Variable<double>(targetSizeRatio.value);
    }
    if (outputFileName.present) {
      map['output_file_name'] = Variable<String>(outputFileName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (failedAt.present) {
      map['failed_at'] = Variable<int>(failedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskRowsCompanion(')
          ..write('id: $id, ')
          ..write('inputPath: $inputPath, ')
          ..write('fileName: $fileName, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('purpose: $purpose, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('folderId: $folderId, ')
          ..write('folderSortOrder: $folderSortOrder, ')
          ..write('outputPath: $outputPath, ')
          ..write('outputFileSize: $outputFileSize, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('failureJson: $failureJson, ')
          ..write('policyTagsJson: $policyTagsJson, ')
          ..write('sourceFileSize: $sourceFileSize, ')
          ..write('sourceLastModifiedAt: $sourceLastModifiedAt, ')
          ..write('analysisDurationMs: $analysisDurationMs, ')
          ..write('analysisVideoWidth: $analysisVideoWidth, ')
          ..write('analysisVideoHeight: $analysisVideoHeight, ')
          ..write('analysisVideoCodec: $analysisVideoCodec, ')
          ..write('analysisAudioCodec: $analysisAudioCodec, ')
          ..write('analysisVideoPixelFormat: $analysisVideoPixelFormat, ')
          ..write('analysisVideoBitDepth: $analysisVideoBitDepth, ')
          ..write('analysisColorRange: $analysisColorRange, ')
          ..write('analysisColorSpace: $analysisColorSpace, ')
          ..write('analysisColorTransfer: $analysisColorTransfer, ')
          ..write('analysisColorPrimaries: $analysisColorPrimaries, ')
          ..write('analysisChromaLocation: $analysisChromaLocation, ')
          ..write(
            'analysisMasteringDisplayMetadata: $analysisMasteringDisplayMetadata, ',
          )
          ..write(
            'analysisMasteringDisplayMaxLuminance: $analysisMasteringDisplayMaxLuminance, ',
          )
          ..write(
            'analysisMaxContentLightLevel: $analysisMaxContentLightLevel, ',
          )
          ..write(
            'analysisMaxFrameAverageLightLevel: $analysisMaxFrameAverageLightLevel, ',
          )
          ..write('analysisDolbyVisionProfile: $analysisDolbyVisionProfile, ')
          ..write(
            'analysisDolbyVisionCompatibilityId: $analysisDolbyVisionCompatibilityId, ',
          )
          ..write('analysisAverageFrameRate: $analysisAverageFrameRate, ')
          ..write('analysisRealFrameRate: $analysisRealFrameRate, ')
          ..write('analysisSampleAspectRatio: $analysisSampleAspectRatio, ')
          ..write('analysisDisplayAspectRatio: $analysisDisplayAspectRatio, ')
          ..write(
            'analysisVideoRotationDegrees: $analysisVideoRotationDegrees, ',
          )
          ..write('analysisFieldOrder: $analysisFieldOrder, ')
          ..write('analysisVideoBitrate: $analysisVideoBitrate, ')
          ..write('analysisAudioBitrate: $analysisAudioBitrate, ')
          ..write('analysisContainerBitrate: $analysisContainerBitrate, ')
          ..write('analysisEstimatedBitrate: $analysisEstimatedBitrate, ')
          ..write('analysisContainerFormat: $analysisContainerFormat, ')
          ..write('analysisAudioChannels: $analysisAudioChannels, ')
          ..write('analysisAudioSampleRate: $analysisAudioSampleRate, ')
          ..write('analysisAudioChannelLayout: $analysisAudioChannelLayout, ')
          ..write('analysisAudioStreamIndex: $analysisAudioStreamIndex, ')
          ..write('analysisAudioStreamsJson: $analysisAudioStreamsJson, ')
          ..write('mediaConfigJson: $mediaConfigJson, ')
          ..write('analysisImageWidth: $analysisImageWidth, ')
          ..write('analysisImageHeight: $analysisImageHeight, ')
          ..write('analysisImageCodec: $analysisImageCodec, ')
          ..write('analysisImagePixelFormat: $analysisImagePixelFormat, ')
          ..write('analysisImageBitDepth: $analysisImageBitDepth, ')
          ..write('analysisUpdatedAt: $analysisUpdatedAt, ')
          ..write('analysisErrorMessage: $analysisErrorMessage, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('encoderBackend: $encoderBackend, ')
          ..write('resolutionPreset: $resolutionPreset, ')
          ..write('outputDirectory: $outputDirectory, ')
          ..write('compressionCrf: $compressionCrf, ')
          ..write('compressionMode: $compressionMode, ')
          ..write('smartPreset: $smartPreset, ')
          ..write('targetSizeBytes: $targetSizeBytes, ')
          ..write('targetSizeRatio: $targetSizeRatio, ')
          ..write('outputFileName: $outputFileName, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('failedAt: $failedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskFolderRowsTable extends TaskFolderRows
    with TableInfo<$TaskFolderRowsTable, TaskFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskFolderRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _compatibilityClassMeta =
      const VerificationMeta('compatibilityClass');
  @override
  late final GeneratedColumn<String> compatibilityClass =
      GeneratedColumn<String>(
        'compatibility_class',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    mediaKind,
    origin,
    compatibilityClass,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('compatibility_class')) {
      context.handle(
        _compatibilityClassMeta,
        compatibilityClass.isAcceptableOrUnknown(
          data['compatibility_class']!,
          _compatibilityClassMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskFolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      compatibilityClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compatibility_class'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskFolderRowsTable createAlias(String alias) {
    return $TaskFolderRowsTable(attachedDatabase, alias);
  }
}

class TaskFolderRow extends DataClass implements Insertable<TaskFolderRow> {
  final String id;
  final String name;
  final String mediaKind;
  final String origin;
  final String? compatibilityClass;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const TaskFolderRow({
    required this.id,
    required this.name,
    required this.mediaKind,
    required this.origin,
    this.compatibilityClass,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['media_kind'] = Variable<String>(mediaKind);
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || compatibilityClass != null) {
      map['compatibility_class'] = Variable<String>(compatibilityClass);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TaskFolderRowsCompanion toCompanion(bool nullToAbsent) {
    return TaskFolderRowsCompanion(
      id: Value(id),
      name: Value(name),
      mediaKind: Value(mediaKind),
      origin: Value(origin),
      compatibilityClass: compatibilityClass == null && nullToAbsent
          ? const Value.absent()
          : Value(compatibilityClass),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskFolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      origin: serializer.fromJson<String>(json['origin']),
      compatibilityClass: serializer.fromJson<String?>(
        json['compatibilityClass'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'origin': serializer.toJson<String>(origin),
      'compatibilityClass': serializer.toJson<String?>(compatibilityClass),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TaskFolderRow copyWith({
    String? id,
    String? name,
    String? mediaKind,
    String? origin,
    Value<String?> compatibilityClass = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => TaskFolderRow(
    id: id ?? this.id,
    name: name ?? this.name,
    mediaKind: mediaKind ?? this.mediaKind,
    origin: origin ?? this.origin,
    compatibilityClass: compatibilityClass.present
        ? compatibilityClass.value
        : this.compatibilityClass,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskFolderRow copyWithCompanion(TaskFolderRowsCompanion data) {
    return TaskFolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      origin: data.origin.present ? data.origin.value : this.origin,
      compatibilityClass: data.compatibilityClass.present
          ? data.compatibilityClass.value
          : this.compatibilityClass,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskFolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('origin: $origin, ')
          ..write('compatibilityClass: $compatibilityClass, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    mediaKind,
    origin,
    compatibilityClass,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskFolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.mediaKind == this.mediaKind &&
          other.origin == this.origin &&
          other.compatibilityClass == this.compatibilityClass &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskFolderRowsCompanion extends UpdateCompanion<TaskFolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> mediaKind;
  final Value<String> origin;
  final Value<String?> compatibilityClass;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TaskFolderRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.origin = const Value.absent(),
    this.compatibilityClass = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskFolderRowsCompanion.insert({
    required String id,
    required String name,
    required String mediaKind,
    this.origin = const Value.absent(),
    this.compatibilityClass = const Value.absent(),
    required int sortOrder,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       mediaKind = Value(mediaKind),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskFolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? mediaKind,
    Expression<String>? origin,
    Expression<String>? compatibilityClass,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (origin != null) 'origin': origin,
      if (compatibilityClass != null) 'compatibility_class': compatibilityClass,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskFolderRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? mediaKind,
    Value<String>? origin,
    Value<String?>? compatibilityClass,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TaskFolderRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      mediaKind: mediaKind ?? this.mediaKind,
      origin: origin ?? this.origin,
      compatibilityClass: compatibilityClass ?? this.compatibilityClass,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (compatibilityClass.present) {
      map['compatibility_class'] = Variable<String>(compatibilityClass.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskFolderRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('origin: $origin, ')
          ..write('compatibilityClass: $compatibilityClass, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppNotificationRowsTable extends AppNotificationRows
    with TableInfo<$AppNotificationRowsTable, AppNotificationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppNotificationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<int> readAt = GeneratedColumn<int>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<int> dismissedAt = GeneratedColumn<int>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    level,
    title,
    message,
    source,
    dedupeKey,
    createdAt,
    readAt,
    dismissedAt,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppNotificationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dedupeKey},
  ];
  @override
  AppNotificationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppNotificationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_at'],
      ),
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $AppNotificationRowsTable createAlias(String alias) {
    return $AppNotificationRowsTable(attachedDatabase, alias);
  }
}

class AppNotificationRow extends DataClass
    implements Insertable<AppNotificationRow> {
  final String id;
  final String kind;
  final String level;
  final String title;
  final String message;
  final String source;
  final String? dedupeKey;
  final int createdAt;
  final int? readAt;
  final int? dismissedAt;
  final String? payloadJson;
  const AppNotificationRow({
    required this.id,
    required this.kind,
    required this.level,
    required this.title,
    required this.message,
    required this.source,
    this.dedupeKey,
    required this.createdAt,
    this.readAt,
    this.dismissedAt,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['level'] = Variable<String>(level);
    map['title'] = Variable<String>(title);
    map['message'] = Variable<String>(message);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<int>(readAt);
    }
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<int>(dismissedAt);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  AppNotificationRowsCompanion toCompanion(bool nullToAbsent) {
    return AppNotificationRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      level: Value(level),
      title: Value(title),
      message: Value(message),
      source: Value(source),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
      createdAt: Value(createdAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory AppNotificationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppNotificationRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      level: serializer.fromJson<String>(json['level']),
      title: serializer.fromJson<String>(json['title']),
      message: serializer.fromJson<String>(json['message']),
      source: serializer.fromJson<String>(json['source']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      readAt: serializer.fromJson<int?>(json['readAt']),
      dismissedAt: serializer.fromJson<int?>(json['dismissedAt']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'level': serializer.toJson<String>(level),
      'title': serializer.toJson<String>(title),
      'message': serializer.toJson<String>(message),
      'source': serializer.toJson<String>(source),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
      'createdAt': serializer.toJson<int>(createdAt),
      'readAt': serializer.toJson<int?>(readAt),
      'dismissedAt': serializer.toJson<int?>(dismissedAt),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  AppNotificationRow copyWith({
    String? id,
    String? kind,
    String? level,
    String? title,
    String? message,
    String? source,
    Value<String?> dedupeKey = const Value.absent(),
    int? createdAt,
    Value<int?> readAt = const Value.absent(),
    Value<int?> dismissedAt = const Value.absent(),
    Value<String?> payloadJson = const Value.absent(),
  }) => AppNotificationRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    level: level ?? this.level,
    title: title ?? this.title,
    message: message ?? this.message,
    source: source ?? this.source,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
    createdAt: createdAt ?? this.createdAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  AppNotificationRow copyWithCompanion(AppNotificationRowsCompanion data) {
    return AppNotificationRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      level: data.level.present ? data.level.value : this.level,
      title: data.title.present ? data.title.value : this.title,
      message: data.message.present ? data.message.value : this.message,
      source: data.source.present ? data.source.value : this.source,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppNotificationRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    level,
    title,
    message,
    source,
    dedupeKey,
    createdAt,
    readAt,
    dismissedAt,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppNotificationRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.level == this.level &&
          other.title == this.title &&
          other.message == this.message &&
          other.source == this.source &&
          other.dedupeKey == this.dedupeKey &&
          other.createdAt == this.createdAt &&
          other.readAt == this.readAt &&
          other.dismissedAt == this.dismissedAt &&
          other.payloadJson == this.payloadJson);
}

class AppNotificationRowsCompanion extends UpdateCompanion<AppNotificationRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> level;
  final Value<String> title;
  final Value<String> message;
  final Value<String> source;
  final Value<String?> dedupeKey;
  final Value<int> createdAt;
  final Value<int?> readAt;
  final Value<int?> dismissedAt;
  final Value<String?> payloadJson;
  final Value<int> rowid;
  const AppNotificationRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.level = const Value.absent(),
    this.title = const Value.absent(),
    this.message = const Value.absent(),
    this.source = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppNotificationRowsCompanion.insert({
    required String id,
    this.kind = const Value.absent(),
    required String level,
    required String title,
    this.message = const Value.absent(),
    required String source,
    this.dedupeKey = const Value.absent(),
    required int createdAt,
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       level = Value(level),
       title = Value(title),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<AppNotificationRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? level,
    Expression<String>? title,
    Expression<String>? message,
    Expression<String>? source,
    Expression<String>? dedupeKey,
    Expression<int>? createdAt,
    Expression<int>? readAt,
    Expression<int>? dismissedAt,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (level != null) 'level': level,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (source != null) 'source': source,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (createdAt != null) 'created_at': createdAt,
      if (readAt != null) 'read_at': readAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppNotificationRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? level,
    Value<String>? title,
    Value<String>? message,
    Value<String>? source,
    Value<String?>? dedupeKey,
    Value<int>? createdAt,
    Value<int?>? readAt,
    Value<int?>? dismissedAt,
    Value<String?>? payloadJson,
    Value<int>? rowid,
  }) {
    return AppNotificationRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      level: level ?? this.level,
      title: title ?? this.title,
      message: message ?? this.message,
      source: source ?? this.source,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<int>(readAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<int>(dismissedAt.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppNotificationRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('level: $level, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('source: $source, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EngineAnalysisProjectionRowsTable extends EngineAnalysisProjectionRows
    with
        TableInfo<
          $EngineAnalysisProjectionRowsTable,
          EngineAnalysisProjectionRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EngineAnalysisProjectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientFileIdMeta = const VerificationMeta(
    'clientFileId',
  );
  @override
  late final GeneratedColumn<String> clientFileId = GeneratedColumn<String>(
    'client_file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineSessionIdMeta = const VerificationMeta(
    'engineSessionId',
  );
  @override
  late final GeneratedColumn<String> engineSessionId = GeneratedColumn<String>(
    'engine_session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _analysisIdMeta = const VerificationMeta(
    'analysisId',
  );
  @override
  late final GeneratedColumn<String> analysisId = GeneratedColumn<String>(
    'analysis_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<String> schemaVersion = GeneratedColumn<String>(
    'schema_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validityStatusMeta = const VerificationMeta(
    'validityStatus',
  );
  @override
  late final GeneratedColumn<String> validityStatus = GeneratedColumn<String>(
    'validity_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisWorkIdMeta = const VerificationMeta(
    'analysisWorkId',
  );
  @override
  late final GeneratedColumn<String> analysisWorkId = GeneratedColumn<String>(
    'analysis_work_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisRequestIdMeta = const VerificationMeta(
    'analysisRequestId',
  );
  @override
  late final GeneratedColumn<String> analysisRequestId =
      GeneratedColumn<String>(
        'analysis_request_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _analysisQueuePositionMeta =
      const VerificationMeta('analysisQueuePosition');
  @override
  late final GeneratedColumn<int> analysisQueuePosition = GeneratedColumn<int>(
    'analysis_queue_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _analysisQueueRevisionMeta =
      const VerificationMeta('analysisQueueRevision');
  @override
  late final GeneratedColumn<int> analysisQueueRevision = GeneratedColumn<int>(
    'analysis_queue_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _executionIdMeta = const VerificationMeta(
    'executionId',
  );
  @override
  late final GeneratedColumn<String> executionId = GeneratedColumn<String>(
    'execution_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _executionRequestIdMeta =
      const VerificationMeta('executionRequestId');
  @override
  late final GeneratedColumn<String> executionRequestId =
      GeneratedColumn<String>(
        'execution_request_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _executionQueuePositionMeta =
      const VerificationMeta('executionQueuePosition');
  @override
  late final GeneratedColumn<int> executionQueuePosition = GeneratedColumn<int>(
    'execution_queue_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _executionQueueRevisionMeta =
      const VerificationMeta('executionQueueRevision');
  @override
  late final GeneratedColumn<int> executionQueueRevision = GeneratedColumn<int>(
    'execution_queue_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _executionStateMeta = const VerificationMeta(
    'executionState',
  );
  @override
  late final GeneratedColumn<String> executionState = GeneratedColumn<String>(
    'execution_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pauseReasonMeta = const VerificationMeta(
    'pauseReason',
  );
  @override
  late final GeneratedColumn<String> pauseReason = GeneratedColumn<String>(
    'pause_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preemptedByExecutionIdMeta =
      const VerificationMeta('preemptedByExecutionId');
  @override
  late final GeneratedColumn<String> preemptedByExecutionId =
      GeneratedColumn<String>(
        'preempted_by_execution_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resumeDepthMeta = const VerificationMeta(
    'resumeDepth',
  );
  @override
  late final GeneratedColumn<int> resumeDepth = GeneratedColumn<int>(
    'resume_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTimeUsMeta = const VerificationMeta(
    'mediaTimeUs',
  );
  @override
  late final GeneratedColumn<int> mediaTimeUs = GeneratedColumn<int>(
    'media_time_us',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _processedBytesMeta = const VerificationMeta(
    'processedBytes',
  );
  @override
  late final GeneratedColumn<int> processedBytes = GeneratedColumn<int>(
    'processed_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEventSequenceMeta = const VerificationMeta(
    'lastEventSequence',
  );
  @override
  late final GeneratedColumn<int> lastEventSequence = GeneratedColumn<int>(
    'last_event_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    clientFileId,
    engineSessionId,
    analysisId,
    revision,
    schemaVersion,
    snapshotJson,
    validityStatus,
    analysisWorkId,
    analysisRequestId,
    analysisQueuePosition,
    analysisQueueRevision,
    executionId,
    executionRequestId,
    executionQueuePosition,
    executionQueueRevision,
    executionState,
    pauseReason,
    preemptedByExecutionId,
    resumeDepth,
    mediaTimeUs,
    processedBytes,
    lastEventSequence,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'engine_analysis_projections';
  @override
  VerificationContext validateIntegrity(
    Insertable<EngineAnalysisProjectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('client_file_id')) {
      context.handle(
        _clientFileIdMeta,
        clientFileId.isAcceptableOrUnknown(
          data['client_file_id']!,
          _clientFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientFileIdMeta);
    }
    if (data.containsKey('engine_session_id')) {
      context.handle(
        _engineSessionIdMeta,
        engineSessionId.isAcceptableOrUnknown(
          data['engine_session_id']!,
          _engineSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_engineSessionIdMeta);
    }
    if (data.containsKey('analysis_id')) {
      context.handle(
        _analysisIdMeta,
        analysisId.isAcceptableOrUnknown(data['analysis_id']!, _analysisIdMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('validity_status')) {
      context.handle(
        _validityStatusMeta,
        validityStatus.isAcceptableOrUnknown(
          data['validity_status']!,
          _validityStatusMeta,
        ),
      );
    }
    if (data.containsKey('analysis_work_id')) {
      context.handle(
        _analysisWorkIdMeta,
        analysisWorkId.isAcceptableOrUnknown(
          data['analysis_work_id']!,
          _analysisWorkIdMeta,
        ),
      );
    }
    if (data.containsKey('analysis_request_id')) {
      context.handle(
        _analysisRequestIdMeta,
        analysisRequestId.isAcceptableOrUnknown(
          data['analysis_request_id']!,
          _analysisRequestIdMeta,
        ),
      );
    }
    if (data.containsKey('analysis_queue_position')) {
      context.handle(
        _analysisQueuePositionMeta,
        analysisQueuePosition.isAcceptableOrUnknown(
          data['analysis_queue_position']!,
          _analysisQueuePositionMeta,
        ),
      );
    }
    if (data.containsKey('analysis_queue_revision')) {
      context.handle(
        _analysisQueueRevisionMeta,
        analysisQueueRevision.isAcceptableOrUnknown(
          data['analysis_queue_revision']!,
          _analysisQueueRevisionMeta,
        ),
      );
    }
    if (data.containsKey('execution_id')) {
      context.handle(
        _executionIdMeta,
        executionId.isAcceptableOrUnknown(
          data['execution_id']!,
          _executionIdMeta,
        ),
      );
    }
    if (data.containsKey('execution_request_id')) {
      context.handle(
        _executionRequestIdMeta,
        executionRequestId.isAcceptableOrUnknown(
          data['execution_request_id']!,
          _executionRequestIdMeta,
        ),
      );
    }
    if (data.containsKey('execution_queue_position')) {
      context.handle(
        _executionQueuePositionMeta,
        executionQueuePosition.isAcceptableOrUnknown(
          data['execution_queue_position']!,
          _executionQueuePositionMeta,
        ),
      );
    }
    if (data.containsKey('execution_queue_revision')) {
      context.handle(
        _executionQueueRevisionMeta,
        executionQueueRevision.isAcceptableOrUnknown(
          data['execution_queue_revision']!,
          _executionQueueRevisionMeta,
        ),
      );
    }
    if (data.containsKey('execution_state')) {
      context.handle(
        _executionStateMeta,
        executionState.isAcceptableOrUnknown(
          data['execution_state']!,
          _executionStateMeta,
        ),
      );
    }
    if (data.containsKey('pause_reason')) {
      context.handle(
        _pauseReasonMeta,
        pauseReason.isAcceptableOrUnknown(
          data['pause_reason']!,
          _pauseReasonMeta,
        ),
      );
    }
    if (data.containsKey('preempted_by_execution_id')) {
      context.handle(
        _preemptedByExecutionIdMeta,
        preemptedByExecutionId.isAcceptableOrUnknown(
          data['preempted_by_execution_id']!,
          _preemptedByExecutionIdMeta,
        ),
      );
    }
    if (data.containsKey('resume_depth')) {
      context.handle(
        _resumeDepthMeta,
        resumeDepth.isAcceptableOrUnknown(
          data['resume_depth']!,
          _resumeDepthMeta,
        ),
      );
    }
    if (data.containsKey('media_time_us')) {
      context.handle(
        _mediaTimeUsMeta,
        mediaTimeUs.isAcceptableOrUnknown(
          data['media_time_us']!,
          _mediaTimeUsMeta,
        ),
      );
    }
    if (data.containsKey('processed_bytes')) {
      context.handle(
        _processedBytesMeta,
        processedBytes.isAcceptableOrUnknown(
          data['processed_bytes']!,
          _processedBytesMeta,
        ),
      );
    }
    if (data.containsKey('last_event_sequence')) {
      context.handle(
        _lastEventSequenceMeta,
        lastEventSequence.isAcceptableOrUnknown(
          data['last_event_sequence']!,
          _lastEventSequenceMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId};
  @override
  EngineAnalysisProjectionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EngineAnalysisProjectionRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      clientFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_file_id'],
      )!,
      engineSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_session_id'],
      )!,
      analysisId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_id'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      ),
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema_version'],
      ),
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      ),
      validityStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}validity_status'],
      ),
      analysisWorkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_work_id'],
      ),
      analysisRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis_request_id'],
      ),
      analysisQueuePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_queue_position'],
      ),
      analysisQueueRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}analysis_queue_revision'],
      ),
      executionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_id'],
      ),
      executionRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_request_id'],
      ),
      executionQueuePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}execution_queue_position'],
      ),
      executionQueueRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}execution_queue_revision'],
      ),
      executionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}execution_state'],
      ),
      pauseReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pause_reason'],
      ),
      preemptedByExecutionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preempted_by_execution_id'],
      ),
      resumeDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resume_depth'],
      ),
      mediaTimeUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_time_us'],
      ),
      processedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processed_bytes'],
      ),
      lastEventSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_event_sequence'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EngineAnalysisProjectionRowsTable createAlias(String alias) {
    return $EngineAnalysisProjectionRowsTable(attachedDatabase, alias);
  }
}

class EngineAnalysisProjectionRow extends DataClass
    implements Insertable<EngineAnalysisProjectionRow> {
  final String taskId;
  final String clientFileId;
  final String engineSessionId;
  final String? analysisId;
  final int? revision;
  final String? schemaVersion;
  final String? snapshotJson;
  final String? validityStatus;
  final String? analysisWorkId;
  final String? analysisRequestId;
  final int? analysisQueuePosition;
  final int? analysisQueueRevision;
  final String? executionId;
  final String? executionRequestId;
  final int? executionQueuePosition;
  final int? executionQueueRevision;
  final String? executionState;
  final String? pauseReason;
  final String? preemptedByExecutionId;
  final int? resumeDepth;
  final int? mediaTimeUs;
  final int? processedBytes;
  final int lastEventSequence;
  final int updatedAt;
  const EngineAnalysisProjectionRow({
    required this.taskId,
    required this.clientFileId,
    required this.engineSessionId,
    this.analysisId,
    this.revision,
    this.schemaVersion,
    this.snapshotJson,
    this.validityStatus,
    this.analysisWorkId,
    this.analysisRequestId,
    this.analysisQueuePosition,
    this.analysisQueueRevision,
    this.executionId,
    this.executionRequestId,
    this.executionQueuePosition,
    this.executionQueueRevision,
    this.executionState,
    this.pauseReason,
    this.preemptedByExecutionId,
    this.resumeDepth,
    this.mediaTimeUs,
    this.processedBytes,
    required this.lastEventSequence,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['client_file_id'] = Variable<String>(clientFileId);
    map['engine_session_id'] = Variable<String>(engineSessionId);
    if (!nullToAbsent || analysisId != null) {
      map['analysis_id'] = Variable<String>(analysisId);
    }
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<int>(revision);
    }
    if (!nullToAbsent || schemaVersion != null) {
      map['schema_version'] = Variable<String>(schemaVersion);
    }
    if (!nullToAbsent || snapshotJson != null) {
      map['snapshot_json'] = Variable<String>(snapshotJson);
    }
    if (!nullToAbsent || validityStatus != null) {
      map['validity_status'] = Variable<String>(validityStatus);
    }
    if (!nullToAbsent || analysisWorkId != null) {
      map['analysis_work_id'] = Variable<String>(analysisWorkId);
    }
    if (!nullToAbsent || analysisRequestId != null) {
      map['analysis_request_id'] = Variable<String>(analysisRequestId);
    }
    if (!nullToAbsent || analysisQueuePosition != null) {
      map['analysis_queue_position'] = Variable<int>(analysisQueuePosition);
    }
    if (!nullToAbsent || analysisQueueRevision != null) {
      map['analysis_queue_revision'] = Variable<int>(analysisQueueRevision);
    }
    if (!nullToAbsent || executionId != null) {
      map['execution_id'] = Variable<String>(executionId);
    }
    if (!nullToAbsent || executionRequestId != null) {
      map['execution_request_id'] = Variable<String>(executionRequestId);
    }
    if (!nullToAbsent || executionQueuePosition != null) {
      map['execution_queue_position'] = Variable<int>(executionQueuePosition);
    }
    if (!nullToAbsent || executionQueueRevision != null) {
      map['execution_queue_revision'] = Variable<int>(executionQueueRevision);
    }
    if (!nullToAbsent || executionState != null) {
      map['execution_state'] = Variable<String>(executionState);
    }
    if (!nullToAbsent || pauseReason != null) {
      map['pause_reason'] = Variable<String>(pauseReason);
    }
    if (!nullToAbsent || preemptedByExecutionId != null) {
      map['preempted_by_execution_id'] = Variable<String>(
        preemptedByExecutionId,
      );
    }
    if (!nullToAbsent || resumeDepth != null) {
      map['resume_depth'] = Variable<int>(resumeDepth);
    }
    if (!nullToAbsent || mediaTimeUs != null) {
      map['media_time_us'] = Variable<int>(mediaTimeUs);
    }
    if (!nullToAbsent || processedBytes != null) {
      map['processed_bytes'] = Variable<int>(processedBytes);
    }
    map['last_event_sequence'] = Variable<int>(lastEventSequence);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EngineAnalysisProjectionRowsCompanion toCompanion(bool nullToAbsent) {
    return EngineAnalysisProjectionRowsCompanion(
      taskId: Value(taskId),
      clientFileId: Value(clientFileId),
      engineSessionId: Value(engineSessionId),
      analysisId: analysisId == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisId),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      schemaVersion: schemaVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(schemaVersion),
      snapshotJson: snapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshotJson),
      validityStatus: validityStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(validityStatus),
      analysisWorkId: analysisWorkId == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisWorkId),
      analysisRequestId: analysisRequestId == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisRequestId),
      analysisQueuePosition: analysisQueuePosition == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisQueuePosition),
      analysisQueueRevision: analysisQueueRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(analysisQueueRevision),
      executionId: executionId == null && nullToAbsent
          ? const Value.absent()
          : Value(executionId),
      executionRequestId: executionRequestId == null && nullToAbsent
          ? const Value.absent()
          : Value(executionRequestId),
      executionQueuePosition: executionQueuePosition == null && nullToAbsent
          ? const Value.absent()
          : Value(executionQueuePosition),
      executionQueueRevision: executionQueueRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(executionQueueRevision),
      executionState: executionState == null && nullToAbsent
          ? const Value.absent()
          : Value(executionState),
      pauseReason: pauseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseReason),
      preemptedByExecutionId: preemptedByExecutionId == null && nullToAbsent
          ? const Value.absent()
          : Value(preemptedByExecutionId),
      resumeDepth: resumeDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeDepth),
      mediaTimeUs: mediaTimeUs == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaTimeUs),
      processedBytes: processedBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(processedBytes),
      lastEventSequence: Value(lastEventSequence),
      updatedAt: Value(updatedAt),
    );
  }

  factory EngineAnalysisProjectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EngineAnalysisProjectionRow(
      taskId: serializer.fromJson<String>(json['taskId']),
      clientFileId: serializer.fromJson<String>(json['clientFileId']),
      engineSessionId: serializer.fromJson<String>(json['engineSessionId']),
      analysisId: serializer.fromJson<String?>(json['analysisId']),
      revision: serializer.fromJson<int?>(json['revision']),
      schemaVersion: serializer.fromJson<String?>(json['schemaVersion']),
      snapshotJson: serializer.fromJson<String?>(json['snapshotJson']),
      validityStatus: serializer.fromJson<String?>(json['validityStatus']),
      analysisWorkId: serializer.fromJson<String?>(json['analysisWorkId']),
      analysisRequestId: serializer.fromJson<String?>(
        json['analysisRequestId'],
      ),
      analysisQueuePosition: serializer.fromJson<int?>(
        json['analysisQueuePosition'],
      ),
      analysisQueueRevision: serializer.fromJson<int?>(
        json['analysisQueueRevision'],
      ),
      executionId: serializer.fromJson<String?>(json['executionId']),
      executionRequestId: serializer.fromJson<String?>(
        json['executionRequestId'],
      ),
      executionQueuePosition: serializer.fromJson<int?>(
        json['executionQueuePosition'],
      ),
      executionQueueRevision: serializer.fromJson<int?>(
        json['executionQueueRevision'],
      ),
      executionState: serializer.fromJson<String?>(json['executionState']),
      pauseReason: serializer.fromJson<String?>(json['pauseReason']),
      preemptedByExecutionId: serializer.fromJson<String?>(
        json['preemptedByExecutionId'],
      ),
      resumeDepth: serializer.fromJson<int?>(json['resumeDepth']),
      mediaTimeUs: serializer.fromJson<int?>(json['mediaTimeUs']),
      processedBytes: serializer.fromJson<int?>(json['processedBytes']),
      lastEventSequence: serializer.fromJson<int>(json['lastEventSequence']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'clientFileId': serializer.toJson<String>(clientFileId),
      'engineSessionId': serializer.toJson<String>(engineSessionId),
      'analysisId': serializer.toJson<String?>(analysisId),
      'revision': serializer.toJson<int?>(revision),
      'schemaVersion': serializer.toJson<String?>(schemaVersion),
      'snapshotJson': serializer.toJson<String?>(snapshotJson),
      'validityStatus': serializer.toJson<String?>(validityStatus),
      'analysisWorkId': serializer.toJson<String?>(analysisWorkId),
      'analysisRequestId': serializer.toJson<String?>(analysisRequestId),
      'analysisQueuePosition': serializer.toJson<int?>(analysisQueuePosition),
      'analysisQueueRevision': serializer.toJson<int?>(analysisQueueRevision),
      'executionId': serializer.toJson<String?>(executionId),
      'executionRequestId': serializer.toJson<String?>(executionRequestId),
      'executionQueuePosition': serializer.toJson<int?>(executionQueuePosition),
      'executionQueueRevision': serializer.toJson<int?>(executionQueueRevision),
      'executionState': serializer.toJson<String?>(executionState),
      'pauseReason': serializer.toJson<String?>(pauseReason),
      'preemptedByExecutionId': serializer.toJson<String?>(
        preemptedByExecutionId,
      ),
      'resumeDepth': serializer.toJson<int?>(resumeDepth),
      'mediaTimeUs': serializer.toJson<int?>(mediaTimeUs),
      'processedBytes': serializer.toJson<int?>(processedBytes),
      'lastEventSequence': serializer.toJson<int>(lastEventSequence),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EngineAnalysisProjectionRow copyWith({
    String? taskId,
    String? clientFileId,
    String? engineSessionId,
    Value<String?> analysisId = const Value.absent(),
    Value<int?> revision = const Value.absent(),
    Value<String?> schemaVersion = const Value.absent(),
    Value<String?> snapshotJson = const Value.absent(),
    Value<String?> validityStatus = const Value.absent(),
    Value<String?> analysisWorkId = const Value.absent(),
    Value<String?> analysisRequestId = const Value.absent(),
    Value<int?> analysisQueuePosition = const Value.absent(),
    Value<int?> analysisQueueRevision = const Value.absent(),
    Value<String?> executionId = const Value.absent(),
    Value<String?> executionRequestId = const Value.absent(),
    Value<int?> executionQueuePosition = const Value.absent(),
    Value<int?> executionQueueRevision = const Value.absent(),
    Value<String?> executionState = const Value.absent(),
    Value<String?> pauseReason = const Value.absent(),
    Value<String?> preemptedByExecutionId = const Value.absent(),
    Value<int?> resumeDepth = const Value.absent(),
    Value<int?> mediaTimeUs = const Value.absent(),
    Value<int?> processedBytes = const Value.absent(),
    int? lastEventSequence,
    int? updatedAt,
  }) => EngineAnalysisProjectionRow(
    taskId: taskId ?? this.taskId,
    clientFileId: clientFileId ?? this.clientFileId,
    engineSessionId: engineSessionId ?? this.engineSessionId,
    analysisId: analysisId.present ? analysisId.value : this.analysisId,
    revision: revision.present ? revision.value : this.revision,
    schemaVersion: schemaVersion.present
        ? schemaVersion.value
        : this.schemaVersion,
    snapshotJson: snapshotJson.present ? snapshotJson.value : this.snapshotJson,
    validityStatus: validityStatus.present
        ? validityStatus.value
        : this.validityStatus,
    analysisWorkId: analysisWorkId.present
        ? analysisWorkId.value
        : this.analysisWorkId,
    analysisRequestId: analysisRequestId.present
        ? analysisRequestId.value
        : this.analysisRequestId,
    analysisQueuePosition: analysisQueuePosition.present
        ? analysisQueuePosition.value
        : this.analysisQueuePosition,
    analysisQueueRevision: analysisQueueRevision.present
        ? analysisQueueRevision.value
        : this.analysisQueueRevision,
    executionId: executionId.present ? executionId.value : this.executionId,
    executionRequestId: executionRequestId.present
        ? executionRequestId.value
        : this.executionRequestId,
    executionQueuePosition: executionQueuePosition.present
        ? executionQueuePosition.value
        : this.executionQueuePosition,
    executionQueueRevision: executionQueueRevision.present
        ? executionQueueRevision.value
        : this.executionQueueRevision,
    executionState: executionState.present
        ? executionState.value
        : this.executionState,
    pauseReason: pauseReason.present ? pauseReason.value : this.pauseReason,
    preemptedByExecutionId: preemptedByExecutionId.present
        ? preemptedByExecutionId.value
        : this.preemptedByExecutionId,
    resumeDepth: resumeDepth.present ? resumeDepth.value : this.resumeDepth,
    mediaTimeUs: mediaTimeUs.present ? mediaTimeUs.value : this.mediaTimeUs,
    processedBytes: processedBytes.present
        ? processedBytes.value
        : this.processedBytes,
    lastEventSequence: lastEventSequence ?? this.lastEventSequence,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EngineAnalysisProjectionRow copyWithCompanion(
    EngineAnalysisProjectionRowsCompanion data,
  ) {
    return EngineAnalysisProjectionRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      clientFileId: data.clientFileId.present
          ? data.clientFileId.value
          : this.clientFileId,
      engineSessionId: data.engineSessionId.present
          ? data.engineSessionId.value
          : this.engineSessionId,
      analysisId: data.analysisId.present
          ? data.analysisId.value
          : this.analysisId,
      revision: data.revision.present ? data.revision.value : this.revision,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      validityStatus: data.validityStatus.present
          ? data.validityStatus.value
          : this.validityStatus,
      analysisWorkId: data.analysisWorkId.present
          ? data.analysisWorkId.value
          : this.analysisWorkId,
      analysisRequestId: data.analysisRequestId.present
          ? data.analysisRequestId.value
          : this.analysisRequestId,
      analysisQueuePosition: data.analysisQueuePosition.present
          ? data.analysisQueuePosition.value
          : this.analysisQueuePosition,
      analysisQueueRevision: data.analysisQueueRevision.present
          ? data.analysisQueueRevision.value
          : this.analysisQueueRevision,
      executionId: data.executionId.present
          ? data.executionId.value
          : this.executionId,
      executionRequestId: data.executionRequestId.present
          ? data.executionRequestId.value
          : this.executionRequestId,
      executionQueuePosition: data.executionQueuePosition.present
          ? data.executionQueuePosition.value
          : this.executionQueuePosition,
      executionQueueRevision: data.executionQueueRevision.present
          ? data.executionQueueRevision.value
          : this.executionQueueRevision,
      executionState: data.executionState.present
          ? data.executionState.value
          : this.executionState,
      pauseReason: data.pauseReason.present
          ? data.pauseReason.value
          : this.pauseReason,
      preemptedByExecutionId: data.preemptedByExecutionId.present
          ? data.preemptedByExecutionId.value
          : this.preemptedByExecutionId,
      resumeDepth: data.resumeDepth.present
          ? data.resumeDepth.value
          : this.resumeDepth,
      mediaTimeUs: data.mediaTimeUs.present
          ? data.mediaTimeUs.value
          : this.mediaTimeUs,
      processedBytes: data.processedBytes.present
          ? data.processedBytes.value
          : this.processedBytes,
      lastEventSequence: data.lastEventSequence.present
          ? data.lastEventSequence.value
          : this.lastEventSequence,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EngineAnalysisProjectionRow(')
          ..write('taskId: $taskId, ')
          ..write('clientFileId: $clientFileId, ')
          ..write('engineSessionId: $engineSessionId, ')
          ..write('analysisId: $analysisId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('validityStatus: $validityStatus, ')
          ..write('analysisWorkId: $analysisWorkId, ')
          ..write('analysisRequestId: $analysisRequestId, ')
          ..write('analysisQueuePosition: $analysisQueuePosition, ')
          ..write('analysisQueueRevision: $analysisQueueRevision, ')
          ..write('executionId: $executionId, ')
          ..write('executionRequestId: $executionRequestId, ')
          ..write('executionQueuePosition: $executionQueuePosition, ')
          ..write('executionQueueRevision: $executionQueueRevision, ')
          ..write('executionState: $executionState, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('preemptedByExecutionId: $preemptedByExecutionId, ')
          ..write('resumeDepth: $resumeDepth, ')
          ..write('mediaTimeUs: $mediaTimeUs, ')
          ..write('processedBytes: $processedBytes, ')
          ..write('lastEventSequence: $lastEventSequence, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    taskId,
    clientFileId,
    engineSessionId,
    analysisId,
    revision,
    schemaVersion,
    snapshotJson,
    validityStatus,
    analysisWorkId,
    analysisRequestId,
    analysisQueuePosition,
    analysisQueueRevision,
    executionId,
    executionRequestId,
    executionQueuePosition,
    executionQueueRevision,
    executionState,
    pauseReason,
    preemptedByExecutionId,
    resumeDepth,
    mediaTimeUs,
    processedBytes,
    lastEventSequence,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EngineAnalysisProjectionRow &&
          other.taskId == this.taskId &&
          other.clientFileId == this.clientFileId &&
          other.engineSessionId == this.engineSessionId &&
          other.analysisId == this.analysisId &&
          other.revision == this.revision &&
          other.schemaVersion == this.schemaVersion &&
          other.snapshotJson == this.snapshotJson &&
          other.validityStatus == this.validityStatus &&
          other.analysisWorkId == this.analysisWorkId &&
          other.analysisRequestId == this.analysisRequestId &&
          other.analysisQueuePosition == this.analysisQueuePosition &&
          other.analysisQueueRevision == this.analysisQueueRevision &&
          other.executionId == this.executionId &&
          other.executionRequestId == this.executionRequestId &&
          other.executionQueuePosition == this.executionQueuePosition &&
          other.executionQueueRevision == this.executionQueueRevision &&
          other.executionState == this.executionState &&
          other.pauseReason == this.pauseReason &&
          other.preemptedByExecutionId == this.preemptedByExecutionId &&
          other.resumeDepth == this.resumeDepth &&
          other.mediaTimeUs == this.mediaTimeUs &&
          other.processedBytes == this.processedBytes &&
          other.lastEventSequence == this.lastEventSequence &&
          other.updatedAt == this.updatedAt);
}

class EngineAnalysisProjectionRowsCompanion
    extends UpdateCompanion<EngineAnalysisProjectionRow> {
  final Value<String> taskId;
  final Value<String> clientFileId;
  final Value<String> engineSessionId;
  final Value<String?> analysisId;
  final Value<int?> revision;
  final Value<String?> schemaVersion;
  final Value<String?> snapshotJson;
  final Value<String?> validityStatus;
  final Value<String?> analysisWorkId;
  final Value<String?> analysisRequestId;
  final Value<int?> analysisQueuePosition;
  final Value<int?> analysisQueueRevision;
  final Value<String?> executionId;
  final Value<String?> executionRequestId;
  final Value<int?> executionQueuePosition;
  final Value<int?> executionQueueRevision;
  final Value<String?> executionState;
  final Value<String?> pauseReason;
  final Value<String?> preemptedByExecutionId;
  final Value<int?> resumeDepth;
  final Value<int?> mediaTimeUs;
  final Value<int?> processedBytes;
  final Value<int> lastEventSequence;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EngineAnalysisProjectionRowsCompanion({
    this.taskId = const Value.absent(),
    this.clientFileId = const Value.absent(),
    this.engineSessionId = const Value.absent(),
    this.analysisId = const Value.absent(),
    this.revision = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.validityStatus = const Value.absent(),
    this.analysisWorkId = const Value.absent(),
    this.analysisRequestId = const Value.absent(),
    this.analysisQueuePosition = const Value.absent(),
    this.analysisQueueRevision = const Value.absent(),
    this.executionId = const Value.absent(),
    this.executionRequestId = const Value.absent(),
    this.executionQueuePosition = const Value.absent(),
    this.executionQueueRevision = const Value.absent(),
    this.executionState = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.preemptedByExecutionId = const Value.absent(),
    this.resumeDepth = const Value.absent(),
    this.mediaTimeUs = const Value.absent(),
    this.processedBytes = const Value.absent(),
    this.lastEventSequence = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EngineAnalysisProjectionRowsCompanion.insert({
    required String taskId,
    required String clientFileId,
    required String engineSessionId,
    this.analysisId = const Value.absent(),
    this.revision = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.validityStatus = const Value.absent(),
    this.analysisWorkId = const Value.absent(),
    this.analysisRequestId = const Value.absent(),
    this.analysisQueuePosition = const Value.absent(),
    this.analysisQueueRevision = const Value.absent(),
    this.executionId = const Value.absent(),
    this.executionRequestId = const Value.absent(),
    this.executionQueuePosition = const Value.absent(),
    this.executionQueueRevision = const Value.absent(),
    this.executionState = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.preemptedByExecutionId = const Value.absent(),
    this.resumeDepth = const Value.absent(),
    this.mediaTimeUs = const Value.absent(),
    this.processedBytes = const Value.absent(),
    this.lastEventSequence = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       clientFileId = Value(clientFileId),
       engineSessionId = Value(engineSessionId),
       updatedAt = Value(updatedAt);
  static Insertable<EngineAnalysisProjectionRow> custom({
    Expression<String>? taskId,
    Expression<String>? clientFileId,
    Expression<String>? engineSessionId,
    Expression<String>? analysisId,
    Expression<int>? revision,
    Expression<String>? schemaVersion,
    Expression<String>? snapshotJson,
    Expression<String>? validityStatus,
    Expression<String>? analysisWorkId,
    Expression<String>? analysisRequestId,
    Expression<int>? analysisQueuePosition,
    Expression<int>? analysisQueueRevision,
    Expression<String>? executionId,
    Expression<String>? executionRequestId,
    Expression<int>? executionQueuePosition,
    Expression<int>? executionQueueRevision,
    Expression<String>? executionState,
    Expression<String>? pauseReason,
    Expression<String>? preemptedByExecutionId,
    Expression<int>? resumeDepth,
    Expression<int>? mediaTimeUs,
    Expression<int>? processedBytes,
    Expression<int>? lastEventSequence,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (clientFileId != null) 'client_file_id': clientFileId,
      if (engineSessionId != null) 'engine_session_id': engineSessionId,
      if (analysisId != null) 'analysis_id': analysisId,
      if (revision != null) 'revision': revision,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (validityStatus != null) 'validity_status': validityStatus,
      if (analysisWorkId != null) 'analysis_work_id': analysisWorkId,
      if (analysisRequestId != null) 'analysis_request_id': analysisRequestId,
      if (analysisQueuePosition != null)
        'analysis_queue_position': analysisQueuePosition,
      if (analysisQueueRevision != null)
        'analysis_queue_revision': analysisQueueRevision,
      if (executionId != null) 'execution_id': executionId,
      if (executionRequestId != null)
        'execution_request_id': executionRequestId,
      if (executionQueuePosition != null)
        'execution_queue_position': executionQueuePosition,
      if (executionQueueRevision != null)
        'execution_queue_revision': executionQueueRevision,
      if (executionState != null) 'execution_state': executionState,
      if (pauseReason != null) 'pause_reason': pauseReason,
      if (preemptedByExecutionId != null)
        'preempted_by_execution_id': preemptedByExecutionId,
      if (resumeDepth != null) 'resume_depth': resumeDepth,
      if (mediaTimeUs != null) 'media_time_us': mediaTimeUs,
      if (processedBytes != null) 'processed_bytes': processedBytes,
      if (lastEventSequence != null) 'last_event_sequence': lastEventSequence,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EngineAnalysisProjectionRowsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? clientFileId,
    Value<String>? engineSessionId,
    Value<String?>? analysisId,
    Value<int?>? revision,
    Value<String?>? schemaVersion,
    Value<String?>? snapshotJson,
    Value<String?>? validityStatus,
    Value<String?>? analysisWorkId,
    Value<String?>? analysisRequestId,
    Value<int?>? analysisQueuePosition,
    Value<int?>? analysisQueueRevision,
    Value<String?>? executionId,
    Value<String?>? executionRequestId,
    Value<int?>? executionQueuePosition,
    Value<int?>? executionQueueRevision,
    Value<String?>? executionState,
    Value<String?>? pauseReason,
    Value<String?>? preemptedByExecutionId,
    Value<int?>? resumeDepth,
    Value<int?>? mediaTimeUs,
    Value<int?>? processedBytes,
    Value<int>? lastEventSequence,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EngineAnalysisProjectionRowsCompanion(
      taskId: taskId ?? this.taskId,
      clientFileId: clientFileId ?? this.clientFileId,
      engineSessionId: engineSessionId ?? this.engineSessionId,
      analysisId: analysisId ?? this.analysisId,
      revision: revision ?? this.revision,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      validityStatus: validityStatus ?? this.validityStatus,
      analysisWorkId: analysisWorkId ?? this.analysisWorkId,
      analysisRequestId: analysisRequestId ?? this.analysisRequestId,
      analysisQueuePosition:
          analysisQueuePosition ?? this.analysisQueuePosition,
      analysisQueueRevision:
          analysisQueueRevision ?? this.analysisQueueRevision,
      executionId: executionId ?? this.executionId,
      executionRequestId: executionRequestId ?? this.executionRequestId,
      executionQueuePosition:
          executionQueuePosition ?? this.executionQueuePosition,
      executionQueueRevision:
          executionQueueRevision ?? this.executionQueueRevision,
      executionState: executionState ?? this.executionState,
      pauseReason: pauseReason ?? this.pauseReason,
      preemptedByExecutionId:
          preemptedByExecutionId ?? this.preemptedByExecutionId,
      resumeDepth: resumeDepth ?? this.resumeDepth,
      mediaTimeUs: mediaTimeUs ?? this.mediaTimeUs,
      processedBytes: processedBytes ?? this.processedBytes,
      lastEventSequence: lastEventSequence ?? this.lastEventSequence,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (clientFileId.present) {
      map['client_file_id'] = Variable<String>(clientFileId.value);
    }
    if (engineSessionId.present) {
      map['engine_session_id'] = Variable<String>(engineSessionId.value);
    }
    if (analysisId.present) {
      map['analysis_id'] = Variable<String>(analysisId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<String>(schemaVersion.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (validityStatus.present) {
      map['validity_status'] = Variable<String>(validityStatus.value);
    }
    if (analysisWorkId.present) {
      map['analysis_work_id'] = Variable<String>(analysisWorkId.value);
    }
    if (analysisRequestId.present) {
      map['analysis_request_id'] = Variable<String>(analysisRequestId.value);
    }
    if (analysisQueuePosition.present) {
      map['analysis_queue_position'] = Variable<int>(
        analysisQueuePosition.value,
      );
    }
    if (analysisQueueRevision.present) {
      map['analysis_queue_revision'] = Variable<int>(
        analysisQueueRevision.value,
      );
    }
    if (executionId.present) {
      map['execution_id'] = Variable<String>(executionId.value);
    }
    if (executionRequestId.present) {
      map['execution_request_id'] = Variable<String>(executionRequestId.value);
    }
    if (executionQueuePosition.present) {
      map['execution_queue_position'] = Variable<int>(
        executionQueuePosition.value,
      );
    }
    if (executionQueueRevision.present) {
      map['execution_queue_revision'] = Variable<int>(
        executionQueueRevision.value,
      );
    }
    if (executionState.present) {
      map['execution_state'] = Variable<String>(executionState.value);
    }
    if (pauseReason.present) {
      map['pause_reason'] = Variable<String>(pauseReason.value);
    }
    if (preemptedByExecutionId.present) {
      map['preempted_by_execution_id'] = Variable<String>(
        preemptedByExecutionId.value,
      );
    }
    if (resumeDepth.present) {
      map['resume_depth'] = Variable<int>(resumeDepth.value);
    }
    if (mediaTimeUs.present) {
      map['media_time_us'] = Variable<int>(mediaTimeUs.value);
    }
    if (processedBytes.present) {
      map['processed_bytes'] = Variable<int>(processedBytes.value);
    }
    if (lastEventSequence.present) {
      map['last_event_sequence'] = Variable<int>(lastEventSequence.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EngineAnalysisProjectionRowsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('clientFileId: $clientFileId, ')
          ..write('engineSessionId: $engineSessionId, ')
          ..write('analysisId: $analysisId, ')
          ..write('revision: $revision, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('validityStatus: $validityStatus, ')
          ..write('analysisWorkId: $analysisWorkId, ')
          ..write('analysisRequestId: $analysisRequestId, ')
          ..write('analysisQueuePosition: $analysisQueuePosition, ')
          ..write('analysisQueueRevision: $analysisQueueRevision, ')
          ..write('executionId: $executionId, ')
          ..write('executionRequestId: $executionRequestId, ')
          ..write('executionQueuePosition: $executionQueuePosition, ')
          ..write('executionQueueRevision: $executionQueueRevision, ')
          ..write('executionState: $executionState, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('preemptedByExecutionId: $preemptedByExecutionId, ')
          ..write('resumeDepth: $resumeDepth, ')
          ..write('mediaTimeUs: $mediaTimeUs, ')
          ..write('processedBytes: $processedBytes, ')
          ..write('lastEventSequence: $lastEventSequence, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkbenchOrderStateRowsTable extends WorkbenchOrderStateRows
    with TableInfo<$WorkbenchOrderStateRowsTable, WorkbenchOrderStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkbenchOrderStateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _orderRevisionMeta = const VerificationMeta(
    'orderRevision',
  );
  @override
  late final GeneratedColumn<int> orderRevision = GeneratedColumn<int>(
    'order_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, orderRevision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workbench_order_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkbenchOrderStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('order_revision')) {
      context.handle(
        _orderRevisionMeta,
        orderRevision.isAcceptableOrUnknown(
          data['order_revision']!,
          _orderRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkbenchOrderStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkbenchOrderStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      orderRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_revision'],
      )!,
    );
  }

  @override
  $WorkbenchOrderStateRowsTable createAlias(String alias) {
    return $WorkbenchOrderStateRowsTable(attachedDatabase, alias);
  }
}

class WorkbenchOrderStateRow extends DataClass
    implements Insertable<WorkbenchOrderStateRow> {
  final int id;
  final int orderRevision;
  const WorkbenchOrderStateRow({required this.id, required this.orderRevision});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['order_revision'] = Variable<int>(orderRevision);
    return map;
  }

  WorkbenchOrderStateRowsCompanion toCompanion(bool nullToAbsent) {
    return WorkbenchOrderStateRowsCompanion(
      id: Value(id),
      orderRevision: Value(orderRevision),
    );
  }

  factory WorkbenchOrderStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkbenchOrderStateRow(
      id: serializer.fromJson<int>(json['id']),
      orderRevision: serializer.fromJson<int>(json['orderRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'orderRevision': serializer.toJson<int>(orderRevision),
    };
  }

  WorkbenchOrderStateRow copyWith({int? id, int? orderRevision}) =>
      WorkbenchOrderStateRow(
        id: id ?? this.id,
        orderRevision: orderRevision ?? this.orderRevision,
      );
  WorkbenchOrderStateRow copyWithCompanion(
    WorkbenchOrderStateRowsCompanion data,
  ) {
    return WorkbenchOrderStateRow(
      id: data.id.present ? data.id.value : this.id,
      orderRevision: data.orderRevision.present
          ? data.orderRevision.value
          : this.orderRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchOrderStateRow(')
          ..write('id: $id, ')
          ..write('orderRevision: $orderRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderRevision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkbenchOrderStateRow &&
          other.id == this.id &&
          other.orderRevision == this.orderRevision);
}

class WorkbenchOrderStateRowsCompanion
    extends UpdateCompanion<WorkbenchOrderStateRow> {
  final Value<int> id;
  final Value<int> orderRevision;
  const WorkbenchOrderStateRowsCompanion({
    this.id = const Value.absent(),
    this.orderRevision = const Value.absent(),
  });
  WorkbenchOrderStateRowsCompanion.insert({
    this.id = const Value.absent(),
    this.orderRevision = const Value.absent(),
  });
  static Insertable<WorkbenchOrderStateRow> custom({
    Expression<int>? id,
    Expression<int>? orderRevision,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderRevision != null) 'order_revision': orderRevision,
    });
  }

  WorkbenchOrderStateRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? orderRevision,
  }) {
    return WorkbenchOrderStateRowsCompanion(
      id: id ?? this.id,
      orderRevision: orderRevision ?? this.orderRevision,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (orderRevision.present) {
      map['order_revision'] = Variable<int>(orderRevision.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchOrderStateRowsCompanion(')
          ..write('id: $id, ')
          ..write('orderRevision: $orderRevision')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsRowsTable settingsRows = $SettingsRowsTable(this);
  late final $TaskRowsTable taskRows = $TaskRowsTable(this);
  late final $TaskFolderRowsTable taskFolderRows = $TaskFolderRowsTable(this);
  late final $AppNotificationRowsTable appNotificationRows =
      $AppNotificationRowsTable(this);
  late final $EngineAnalysisProjectionRowsTable engineAnalysisProjectionRows =
      $EngineAnalysisProjectionRowsTable(this);
  late final $WorkbenchOrderStateRowsTable workbenchOrderStateRows =
      $WorkbenchOrderStateRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settingsRows,
    taskRows,
    taskFolderRows,
    appNotificationRows,
    engineAnalysisProjectionRows,
    workbenchOrderStateRows,
  ];
}

typedef $$SettingsRowsTableCreateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<String?> defaultOutputDirectory,
      Value<String?> lastSelectedOutputDirectory,
      Value<bool> saveOutputToSourceDirectory,
      Value<bool> showRawLog,
      Value<bool> showAdvancedOptions,
      Value<String> defaultOutputVideoCodec,
      Value<String> defaultCompressionSmartPreset,
      Value<String> defaultOutputFileNameTemplate,
      Value<String?> defaultMediaConfigJson,
      Value<String> themeMode,
      Value<bool> hideNotificationBadge,
      Value<bool> showTaskCompletionDialog,
      Value<String> taskCompletionSound,
      Value<int> folderImportScanDepth,
      Value<String> notificationPoliciesJson,
      Value<String> shortcutBindingsJson,
      Value<String> closeBehavior,
      required int createdAt,
      required int updatedAt,
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<String?> defaultOutputDirectory,
      Value<String?> lastSelectedOutputDirectory,
      Value<bool> saveOutputToSourceDirectory,
      Value<bool> showRawLog,
      Value<bool> showAdvancedOptions,
      Value<String> defaultOutputVideoCodec,
      Value<String> defaultCompressionSmartPreset,
      Value<String> defaultOutputFileNameTemplate,
      Value<String?> defaultMediaConfigJson,
      Value<String> themeMode,
      Value<bool> hideNotificationBadge,
      Value<bool> showTaskCompletionDialog,
      Value<String> taskCompletionSound,
      Value<int> folderImportScanDepth,
      Value<String> notificationPoliciesJson,
      Value<String> shortcutBindingsJson,
      Value<String> closeBehavior,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$SettingsRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultOutputDirectory => $composableBuilder(
    column: $table.defaultOutputDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSelectedOutputDirectory => $composableBuilder(
    column: $table.lastSelectedOutputDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saveOutputToSourceDirectory => $composableBuilder(
    column: $table.saveOutputToSourceDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showRawLog => $composableBuilder(
    column: $table.showRawLog,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showAdvancedOptions => $composableBuilder(
    column: $table.showAdvancedOptions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultOutputVideoCodec => $composableBuilder(
    column: $table.defaultOutputVideoCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCompressionSmartPreset => $composableBuilder(
    column: $table.defaultCompressionSmartPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultOutputFileNameTemplate => $composableBuilder(
    column: $table.defaultOutputFileNameTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultMediaConfigJson => $composableBuilder(
    column: $table.defaultMediaConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hideNotificationBadge => $composableBuilder(
    column: $table.hideNotificationBadge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showTaskCompletionDialog => $composableBuilder(
    column: $table.showTaskCompletionDialog,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskCompletionSound => $composableBuilder(
    column: $table.taskCompletionSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderImportScanDepth => $composableBuilder(
    column: $table.folderImportScanDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationPoliciesJson => $composableBuilder(
    column: $table.notificationPoliciesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortcutBindingsJson => $composableBuilder(
    column: $table.shortcutBindingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closeBehavior => $composableBuilder(
    column: $table.closeBehavior,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultOutputDirectory => $composableBuilder(
    column: $table.defaultOutputDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSelectedOutputDirectory => $composableBuilder(
    column: $table.lastSelectedOutputDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saveOutputToSourceDirectory => $composableBuilder(
    column: $table.saveOutputToSourceDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showRawLog => $composableBuilder(
    column: $table.showRawLog,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showAdvancedOptions => $composableBuilder(
    column: $table.showAdvancedOptions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultOutputVideoCodec => $composableBuilder(
    column: $table.defaultOutputVideoCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCompressionSmartPreset =>
      $composableBuilder(
        column: $table.defaultCompressionSmartPreset,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get defaultOutputFileNameTemplate =>
      $composableBuilder(
        column: $table.defaultOutputFileNameTemplate,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get defaultMediaConfigJson => $composableBuilder(
    column: $table.defaultMediaConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hideNotificationBadge => $composableBuilder(
    column: $table.hideNotificationBadge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showTaskCompletionDialog => $composableBuilder(
    column: $table.showTaskCompletionDialog,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskCompletionSound => $composableBuilder(
    column: $table.taskCompletionSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderImportScanDepth => $composableBuilder(
    column: $table.folderImportScanDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationPoliciesJson => $composableBuilder(
    column: $table.notificationPoliciesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortcutBindingsJson => $composableBuilder(
    column: $table.shortcutBindingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closeBehavior => $composableBuilder(
    column: $table.closeBehavior,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get defaultOutputDirectory => $composableBuilder(
    column: $table.defaultOutputDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSelectedOutputDirectory => $composableBuilder(
    column: $table.lastSelectedOutputDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get saveOutputToSourceDirectory => $composableBuilder(
    column: $table.saveOutputToSourceDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showRawLog => $composableBuilder(
    column: $table.showRawLog,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showAdvancedOptions => $composableBuilder(
    column: $table.showAdvancedOptions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultOutputVideoCodec => $composableBuilder(
    column: $table.defaultOutputVideoCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultCompressionSmartPreset =>
      $composableBuilder(
        column: $table.defaultCompressionSmartPreset,
        builder: (column) => column,
      );

  GeneratedColumn<String> get defaultOutputFileNameTemplate =>
      $composableBuilder(
        column: $table.defaultOutputFileNameTemplate,
        builder: (column) => column,
      );

  GeneratedColumn<String> get defaultMediaConfigJson => $composableBuilder(
    column: $table.defaultMediaConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get hideNotificationBadge => $composableBuilder(
    column: $table.hideNotificationBadge,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showTaskCompletionDialog => $composableBuilder(
    column: $table.showTaskCompletionDialog,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskCompletionSound => $composableBuilder(
    column: $table.taskCompletionSound,
    builder: (column) => column,
  );

  GeneratedColumn<int> get folderImportScanDepth => $composableBuilder(
    column: $table.folderImportScanDepth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationPoliciesJson => $composableBuilder(
    column: $table.notificationPoliciesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shortcutBindingsJson => $composableBuilder(
    column: $table.shortcutBindingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closeBehavior => $composableBuilder(
    column: $table.closeBehavior,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsRowsTable,
          SettingsRow,
          $$SettingsRowsTableFilterComposer,
          $$SettingsRowsTableOrderingComposer,
          $$SettingsRowsTableAnnotationComposer,
          $$SettingsRowsTableCreateCompanionBuilder,
          $$SettingsRowsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$AppDatabase, $SettingsRowsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsRowsTableTableManager(_$AppDatabase db, $SettingsRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> defaultOutputDirectory = const Value.absent(),
                Value<String?> lastSelectedOutputDirectory =
                    const Value.absent(),
                Value<bool> saveOutputToSourceDirectory = const Value.absent(),
                Value<bool> showRawLog = const Value.absent(),
                Value<bool> showAdvancedOptions = const Value.absent(),
                Value<String> defaultOutputVideoCodec = const Value.absent(),
                Value<String> defaultCompressionSmartPreset =
                    const Value.absent(),
                Value<String> defaultOutputFileNameTemplate =
                    const Value.absent(),
                Value<String?> defaultMediaConfigJson = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> hideNotificationBadge = const Value.absent(),
                Value<bool> showTaskCompletionDialog = const Value.absent(),
                Value<String> taskCompletionSound = const Value.absent(),
                Value<int> folderImportScanDepth = const Value.absent(),
                Value<String> notificationPoliciesJson = const Value.absent(),
                Value<String> shortcutBindingsJson = const Value.absent(),
                Value<String> closeBehavior = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => SettingsRowsCompanion(
                id: id,
                defaultOutputDirectory: defaultOutputDirectory,
                lastSelectedOutputDirectory: lastSelectedOutputDirectory,
                saveOutputToSourceDirectory: saveOutputToSourceDirectory,
                showRawLog: showRawLog,
                showAdvancedOptions: showAdvancedOptions,
                defaultOutputVideoCodec: defaultOutputVideoCodec,
                defaultCompressionSmartPreset: defaultCompressionSmartPreset,
                defaultOutputFileNameTemplate: defaultOutputFileNameTemplate,
                defaultMediaConfigJson: defaultMediaConfigJson,
                themeMode: themeMode,
                hideNotificationBadge: hideNotificationBadge,
                showTaskCompletionDialog: showTaskCompletionDialog,
                taskCompletionSound: taskCompletionSound,
                folderImportScanDepth: folderImportScanDepth,
                notificationPoliciesJson: notificationPoliciesJson,
                shortcutBindingsJson: shortcutBindingsJson,
                closeBehavior: closeBehavior,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> defaultOutputDirectory = const Value.absent(),
                Value<String?> lastSelectedOutputDirectory =
                    const Value.absent(),
                Value<bool> saveOutputToSourceDirectory = const Value.absent(),
                Value<bool> showRawLog = const Value.absent(),
                Value<bool> showAdvancedOptions = const Value.absent(),
                Value<String> defaultOutputVideoCodec = const Value.absent(),
                Value<String> defaultCompressionSmartPreset =
                    const Value.absent(),
                Value<String> defaultOutputFileNameTemplate =
                    const Value.absent(),
                Value<String?> defaultMediaConfigJson = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> hideNotificationBadge = const Value.absent(),
                Value<bool> showTaskCompletionDialog = const Value.absent(),
                Value<String> taskCompletionSound = const Value.absent(),
                Value<int> folderImportScanDepth = const Value.absent(),
                Value<String> notificationPoliciesJson = const Value.absent(),
                Value<String> shortcutBindingsJson = const Value.absent(),
                Value<String> closeBehavior = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => SettingsRowsCompanion.insert(
                id: id,
                defaultOutputDirectory: defaultOutputDirectory,
                lastSelectedOutputDirectory: lastSelectedOutputDirectory,
                saveOutputToSourceDirectory: saveOutputToSourceDirectory,
                showRawLog: showRawLog,
                showAdvancedOptions: showAdvancedOptions,
                defaultOutputVideoCodec: defaultOutputVideoCodec,
                defaultCompressionSmartPreset: defaultCompressionSmartPreset,
                defaultOutputFileNameTemplate: defaultOutputFileNameTemplate,
                defaultMediaConfigJson: defaultMediaConfigJson,
                themeMode: themeMode,
                hideNotificationBadge: hideNotificationBadge,
                showTaskCompletionDialog: showTaskCompletionDialog,
                taskCompletionSound: taskCompletionSound,
                folderImportScanDepth: folderImportScanDepth,
                notificationPoliciesJson: notificationPoliciesJson,
                shortcutBindingsJson: shortcutBindingsJson,
                closeBehavior: closeBehavior,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsRowsTable,
      SettingsRow,
      $$SettingsRowsTableFilterComposer,
      $$SettingsRowsTableOrderingComposer,
      $$SettingsRowsTableAnnotationComposer,
      $$SettingsRowsTableCreateCompanionBuilder,
      $$SettingsRowsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$AppDatabase, $SettingsRowsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$TaskRowsTableCreateCompanionBuilder =
    TaskRowsCompanion Function({
      required String id,
      required String inputPath,
      required String fileName,
      Value<String> mediaKind,
      required String purpose,
      required String status,
      Value<double> progress,
      required int sortOrder,
      Value<String?> folderId,
      Value<int?> folderSortOrder,
      Value<String?> outputPath,
      Value<int?> outputFileSize,
      Value<String?> errorMessage,
      Value<String?> failureJson,
      Value<String?> policyTagsJson,
      Value<int?> sourceFileSize,
      Value<int?> sourceLastModifiedAt,
      Value<int?> analysisDurationMs,
      Value<int?> analysisVideoWidth,
      Value<int?> analysisVideoHeight,
      Value<String?> analysisVideoCodec,
      Value<String?> analysisAudioCodec,
      Value<String?> analysisVideoPixelFormat,
      Value<int?> analysisVideoBitDepth,
      Value<String?> analysisColorRange,
      Value<String?> analysisColorSpace,
      Value<String?> analysisColorTransfer,
      Value<String?> analysisColorPrimaries,
      Value<String?> analysisChromaLocation,
      Value<String?> analysisMasteringDisplayMetadata,
      Value<double?> analysisMasteringDisplayMaxLuminance,
      Value<int?> analysisMaxContentLightLevel,
      Value<int?> analysisMaxFrameAverageLightLevel,
      Value<int?> analysisDolbyVisionProfile,
      Value<int?> analysisDolbyVisionCompatibilityId,
      Value<String?> analysisAverageFrameRate,
      Value<String?> analysisRealFrameRate,
      Value<String?> analysisSampleAspectRatio,
      Value<String?> analysisDisplayAspectRatio,
      Value<int?> analysisVideoRotationDegrees,
      Value<String?> analysisFieldOrder,
      Value<int?> analysisVideoBitrate,
      Value<int?> analysisAudioBitrate,
      Value<int?> analysisContainerBitrate,
      Value<int?> analysisEstimatedBitrate,
      Value<String?> analysisContainerFormat,
      Value<int?> analysisAudioChannels,
      Value<int?> analysisAudioSampleRate,
      Value<String?> analysisAudioChannelLayout,
      Value<int?> analysisAudioStreamIndex,
      Value<String?> analysisAudioStreamsJson,
      Value<String?> mediaConfigJson,
      Value<int?> analysisImageWidth,
      Value<int?> analysisImageHeight,
      Value<String?> analysisImageCodec,
      Value<String?> analysisImagePixelFormat,
      Value<int?> analysisImageBitDepth,
      Value<int?> analysisUpdatedAt,
      Value<String?> analysisErrorMessage,
      required String outputFormat,
      required String videoCodec,
      required String encoderBackend,
      required String resolutionPreset,
      required String outputDirectory,
      Value<int> compressionCrf,
      Value<String> compressionMode,
      Value<String?> smartPreset,
      Value<int?> targetSizeBytes,
      Value<double?> targetSizeRatio,
      Value<String> outputFileName,
      required int createdAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<int?> failedAt,
      Value<int> rowid,
    });
typedef $$TaskRowsTableUpdateCompanionBuilder =
    TaskRowsCompanion Function({
      Value<String> id,
      Value<String> inputPath,
      Value<String> fileName,
      Value<String> mediaKind,
      Value<String> purpose,
      Value<String> status,
      Value<double> progress,
      Value<int> sortOrder,
      Value<String?> folderId,
      Value<int?> folderSortOrder,
      Value<String?> outputPath,
      Value<int?> outputFileSize,
      Value<String?> errorMessage,
      Value<String?> failureJson,
      Value<String?> policyTagsJson,
      Value<int?> sourceFileSize,
      Value<int?> sourceLastModifiedAt,
      Value<int?> analysisDurationMs,
      Value<int?> analysisVideoWidth,
      Value<int?> analysisVideoHeight,
      Value<String?> analysisVideoCodec,
      Value<String?> analysisAudioCodec,
      Value<String?> analysisVideoPixelFormat,
      Value<int?> analysisVideoBitDepth,
      Value<String?> analysisColorRange,
      Value<String?> analysisColorSpace,
      Value<String?> analysisColorTransfer,
      Value<String?> analysisColorPrimaries,
      Value<String?> analysisChromaLocation,
      Value<String?> analysisMasteringDisplayMetadata,
      Value<double?> analysisMasteringDisplayMaxLuminance,
      Value<int?> analysisMaxContentLightLevel,
      Value<int?> analysisMaxFrameAverageLightLevel,
      Value<int?> analysisDolbyVisionProfile,
      Value<int?> analysisDolbyVisionCompatibilityId,
      Value<String?> analysisAverageFrameRate,
      Value<String?> analysisRealFrameRate,
      Value<String?> analysisSampleAspectRatio,
      Value<String?> analysisDisplayAspectRatio,
      Value<int?> analysisVideoRotationDegrees,
      Value<String?> analysisFieldOrder,
      Value<int?> analysisVideoBitrate,
      Value<int?> analysisAudioBitrate,
      Value<int?> analysisContainerBitrate,
      Value<int?> analysisEstimatedBitrate,
      Value<String?> analysisContainerFormat,
      Value<int?> analysisAudioChannels,
      Value<int?> analysisAudioSampleRate,
      Value<String?> analysisAudioChannelLayout,
      Value<int?> analysisAudioStreamIndex,
      Value<String?> analysisAudioStreamsJson,
      Value<String?> mediaConfigJson,
      Value<int?> analysisImageWidth,
      Value<int?> analysisImageHeight,
      Value<String?> analysisImageCodec,
      Value<String?> analysisImagePixelFormat,
      Value<int?> analysisImageBitDepth,
      Value<int?> analysisUpdatedAt,
      Value<String?> analysisErrorMessage,
      Value<String> outputFormat,
      Value<String> videoCodec,
      Value<String> encoderBackend,
      Value<String> resolutionPreset,
      Value<String> outputDirectory,
      Value<int> compressionCrf,
      Value<String> compressionMode,
      Value<String?> smartPreset,
      Value<int?> targetSizeBytes,
      Value<double?> targetSizeRatio,
      Value<String> outputFileName,
      Value<int> createdAt,
      Value<int?> startedAt,
      Value<int?> completedAt,
      Value<int?> failedAt,
      Value<int> rowid,
    });

class $$TaskRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderSortOrder => $composableBuilder(
    column: $table.folderSortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputFileSize => $composableBuilder(
    column: $table.outputFileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyTagsJson => $composableBuilder(
    column: $table.policyTagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceLastModifiedAt => $composableBuilder(
    column: $table.sourceLastModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisDurationMs => $composableBuilder(
    column: $table.analysisDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisVideoWidth => $composableBuilder(
    column: $table.analysisVideoWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisVideoHeight => $composableBuilder(
    column: $table.analysisVideoHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisVideoCodec => $composableBuilder(
    column: $table.analysisVideoCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisAudioCodec => $composableBuilder(
    column: $table.analysisAudioCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisVideoPixelFormat => $composableBuilder(
    column: $table.analysisVideoPixelFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisVideoBitDepth => $composableBuilder(
    column: $table.analysisVideoBitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisColorRange => $composableBuilder(
    column: $table.analysisColorRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisColorSpace => $composableBuilder(
    column: $table.analysisColorSpace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisColorTransfer => $composableBuilder(
    column: $table.analysisColorTransfer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisColorPrimaries => $composableBuilder(
    column: $table.analysisColorPrimaries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisChromaLocation => $composableBuilder(
    column: $table.analysisChromaLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisMasteringDisplayMetadata =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMetadata,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<double> get analysisMasteringDisplayMaxLuminance =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMaxLuminance,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get analysisMaxContentLightLevel => $composableBuilder(
    column: $table.analysisMaxContentLightLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisMaxFrameAverageLightLevel =>
      $composableBuilder(
        column: $table.analysisMaxFrameAverageLightLevel,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<int> get analysisDolbyVisionProfile => $composableBuilder(
    column: $table.analysisDolbyVisionProfile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisDolbyVisionCompatibilityId =>
      $composableBuilder(
        column: $table.analysisDolbyVisionCompatibilityId,
        builder: (column) => ColumnFilters(column),
      );

  ColumnFilters<String> get analysisAverageFrameRate => $composableBuilder(
    column: $table.analysisAverageFrameRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisRealFrameRate => $composableBuilder(
    column: $table.analysisRealFrameRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisSampleAspectRatio => $composableBuilder(
    column: $table.analysisSampleAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisDisplayAspectRatio => $composableBuilder(
    column: $table.analysisDisplayAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisVideoRotationDegrees => $composableBuilder(
    column: $table.analysisVideoRotationDegrees,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisFieldOrder => $composableBuilder(
    column: $table.analysisFieldOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisVideoBitrate => $composableBuilder(
    column: $table.analysisVideoBitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisAudioBitrate => $composableBuilder(
    column: $table.analysisAudioBitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisContainerBitrate => $composableBuilder(
    column: $table.analysisContainerBitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisEstimatedBitrate => $composableBuilder(
    column: $table.analysisEstimatedBitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisContainerFormat => $composableBuilder(
    column: $table.analysisContainerFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisAudioChannels => $composableBuilder(
    column: $table.analysisAudioChannels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisAudioSampleRate => $composableBuilder(
    column: $table.analysisAudioSampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisAudioChannelLayout => $composableBuilder(
    column: $table.analysisAudioChannelLayout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisAudioStreamIndex => $composableBuilder(
    column: $table.analysisAudioStreamIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisAudioStreamsJson => $composableBuilder(
    column: $table.analysisAudioStreamsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaConfigJson => $composableBuilder(
    column: $table.mediaConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisImageWidth => $composableBuilder(
    column: $table.analysisImageWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisImageHeight => $composableBuilder(
    column: $table.analysisImageHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisImageCodec => $composableBuilder(
    column: $table.analysisImageCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisImagePixelFormat => $composableBuilder(
    column: $table.analysisImagePixelFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisImageBitDepth => $composableBuilder(
    column: $table.analysisImageBitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisUpdatedAt => $composableBuilder(
    column: $table.analysisUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisErrorMessage => $composableBuilder(
    column: $table.analysisErrorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encoderBackend => $composableBuilder(
    column: $table.encoderBackend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolutionPreset => $composableBuilder(
    column: $table.resolutionPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputDirectory => $composableBuilder(
    column: $table.outputDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get compressionCrf => $composableBuilder(
    column: $table.compressionCrf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compressionMode => $composableBuilder(
    column: $table.compressionMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smartPreset => $composableBuilder(
    column: $table.smartPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSizeBytes => $composableBuilder(
    column: $table.targetSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetSizeRatio => $composableBuilder(
    column: $table.targetSizeRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputFileName => $composableBuilder(
    column: $table.outputFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderSortOrder => $composableBuilder(
    column: $table.folderSortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputFileSize => $composableBuilder(
    column: $table.outputFileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyTagsJson => $composableBuilder(
    column: $table.policyTagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceLastModifiedAt => $composableBuilder(
    column: $table.sourceLastModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisDurationMs => $composableBuilder(
    column: $table.analysisDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisVideoWidth => $composableBuilder(
    column: $table.analysisVideoWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisVideoHeight => $composableBuilder(
    column: $table.analysisVideoHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisVideoCodec => $composableBuilder(
    column: $table.analysisVideoCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisAudioCodec => $composableBuilder(
    column: $table.analysisAudioCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisVideoPixelFormat => $composableBuilder(
    column: $table.analysisVideoPixelFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisVideoBitDepth => $composableBuilder(
    column: $table.analysisVideoBitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisColorRange => $composableBuilder(
    column: $table.analysisColorRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisColorSpace => $composableBuilder(
    column: $table.analysisColorSpace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisColorTransfer => $composableBuilder(
    column: $table.analysisColorTransfer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisColorPrimaries => $composableBuilder(
    column: $table.analysisColorPrimaries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisChromaLocation => $composableBuilder(
    column: $table.analysisChromaLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisMasteringDisplayMetadata =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMetadata,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<double> get analysisMasteringDisplayMaxLuminance =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMaxLuminance,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get analysisMaxContentLightLevel => $composableBuilder(
    column: $table.analysisMaxContentLightLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisMaxFrameAverageLightLevel =>
      $composableBuilder(
        column: $table.analysisMaxFrameAverageLightLevel,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get analysisDolbyVisionProfile => $composableBuilder(
    column: $table.analysisDolbyVisionProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisDolbyVisionCompatibilityId =>
      $composableBuilder(
        column: $table.analysisDolbyVisionCompatibilityId,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get analysisAverageFrameRate => $composableBuilder(
    column: $table.analysisAverageFrameRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisRealFrameRate => $composableBuilder(
    column: $table.analysisRealFrameRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisSampleAspectRatio => $composableBuilder(
    column: $table.analysisSampleAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisDisplayAspectRatio => $composableBuilder(
    column: $table.analysisDisplayAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisVideoRotationDegrees => $composableBuilder(
    column: $table.analysisVideoRotationDegrees,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisFieldOrder => $composableBuilder(
    column: $table.analysisFieldOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisVideoBitrate => $composableBuilder(
    column: $table.analysisVideoBitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisAudioBitrate => $composableBuilder(
    column: $table.analysisAudioBitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisContainerBitrate => $composableBuilder(
    column: $table.analysisContainerBitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisEstimatedBitrate => $composableBuilder(
    column: $table.analysisEstimatedBitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisContainerFormat => $composableBuilder(
    column: $table.analysisContainerFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisAudioChannels => $composableBuilder(
    column: $table.analysisAudioChannels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisAudioSampleRate => $composableBuilder(
    column: $table.analysisAudioSampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisAudioChannelLayout => $composableBuilder(
    column: $table.analysisAudioChannelLayout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisAudioStreamIndex => $composableBuilder(
    column: $table.analysisAudioStreamIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisAudioStreamsJson => $composableBuilder(
    column: $table.analysisAudioStreamsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaConfigJson => $composableBuilder(
    column: $table.mediaConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisImageWidth => $composableBuilder(
    column: $table.analysisImageWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisImageHeight => $composableBuilder(
    column: $table.analysisImageHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisImageCodec => $composableBuilder(
    column: $table.analysisImageCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisImagePixelFormat => $composableBuilder(
    column: $table.analysisImagePixelFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisImageBitDepth => $composableBuilder(
    column: $table.analysisImageBitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisUpdatedAt => $composableBuilder(
    column: $table.analysisUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisErrorMessage => $composableBuilder(
    column: $table.analysisErrorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encoderBackend => $composableBuilder(
    column: $table.encoderBackend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolutionPreset => $composableBuilder(
    column: $table.resolutionPreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputDirectory => $composableBuilder(
    column: $table.outputDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get compressionCrf => $composableBuilder(
    column: $table.compressionCrf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compressionMode => $composableBuilder(
    column: $table.compressionMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smartPreset => $composableBuilder(
    column: $table.smartPreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSizeBytes => $composableBuilder(
    column: $table.targetSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetSizeRatio => $composableBuilder(
    column: $table.targetSizeRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputFileName => $composableBuilder(
    column: $table.outputFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskRowsTable> {
  $$TaskRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get inputPath =>
      $composableBuilder(column: $table.inputPath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get folderSortOrder => $composableBuilder(
    column: $table.folderSortOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputFileSize => $composableBuilder(
    column: $table.outputFileSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureJson => $composableBuilder(
    column: $table.failureJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyTagsJson => $composableBuilder(
    column: $table.policyTagsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceLastModifiedAt => $composableBuilder(
    column: $table.sourceLastModifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisDurationMs => $composableBuilder(
    column: $table.analysisDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisVideoWidth => $composableBuilder(
    column: $table.analysisVideoWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisVideoHeight => $composableBuilder(
    column: $table.analysisVideoHeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisVideoCodec => $composableBuilder(
    column: $table.analysisVideoCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisAudioCodec => $composableBuilder(
    column: $table.analysisAudioCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisVideoPixelFormat => $composableBuilder(
    column: $table.analysisVideoPixelFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisVideoBitDepth => $composableBuilder(
    column: $table.analysisVideoBitDepth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisColorRange => $composableBuilder(
    column: $table.analysisColorRange,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisColorSpace => $composableBuilder(
    column: $table.analysisColorSpace,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisColorTransfer => $composableBuilder(
    column: $table.analysisColorTransfer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisColorPrimaries => $composableBuilder(
    column: $table.analysisColorPrimaries,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisChromaLocation => $composableBuilder(
    column: $table.analysisChromaLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisMasteringDisplayMetadata =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMetadata,
        builder: (column) => column,
      );

  GeneratedColumn<double> get analysisMasteringDisplayMaxLuminance =>
      $composableBuilder(
        column: $table.analysisMasteringDisplayMaxLuminance,
        builder: (column) => column,
      );

  GeneratedColumn<int> get analysisMaxContentLightLevel => $composableBuilder(
    column: $table.analysisMaxContentLightLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisMaxFrameAverageLightLevel =>
      $composableBuilder(
        column: $table.analysisMaxFrameAverageLightLevel,
        builder: (column) => column,
      );

  GeneratedColumn<int> get analysisDolbyVisionProfile => $composableBuilder(
    column: $table.analysisDolbyVisionProfile,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisDolbyVisionCompatibilityId =>
      $composableBuilder(
        column: $table.analysisDolbyVisionCompatibilityId,
        builder: (column) => column,
      );

  GeneratedColumn<String> get analysisAverageFrameRate => $composableBuilder(
    column: $table.analysisAverageFrameRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisRealFrameRate => $composableBuilder(
    column: $table.analysisRealFrameRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisSampleAspectRatio => $composableBuilder(
    column: $table.analysisSampleAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisDisplayAspectRatio => $composableBuilder(
    column: $table.analysisDisplayAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisVideoRotationDegrees => $composableBuilder(
    column: $table.analysisVideoRotationDegrees,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisFieldOrder => $composableBuilder(
    column: $table.analysisFieldOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisVideoBitrate => $composableBuilder(
    column: $table.analysisVideoBitrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisAudioBitrate => $composableBuilder(
    column: $table.analysisAudioBitrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisContainerBitrate => $composableBuilder(
    column: $table.analysisContainerBitrate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisEstimatedBitrate => $composableBuilder(
    column: $table.analysisEstimatedBitrate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisContainerFormat => $composableBuilder(
    column: $table.analysisContainerFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisAudioChannels => $composableBuilder(
    column: $table.analysisAudioChannels,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisAudioSampleRate => $composableBuilder(
    column: $table.analysisAudioSampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisAudioChannelLayout => $composableBuilder(
    column: $table.analysisAudioChannelLayout,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisAudioStreamIndex => $composableBuilder(
    column: $table.analysisAudioStreamIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisAudioStreamsJson => $composableBuilder(
    column: $table.analysisAudioStreamsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaConfigJson => $composableBuilder(
    column: $table.mediaConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisImageWidth => $composableBuilder(
    column: $table.analysisImageWidth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisImageHeight => $composableBuilder(
    column: $table.analysisImageHeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisImageCodec => $composableBuilder(
    column: $table.analysisImageCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisImagePixelFormat => $composableBuilder(
    column: $table.analysisImagePixelFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisImageBitDepth => $composableBuilder(
    column: $table.analysisImageBitDepth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisUpdatedAt => $composableBuilder(
    column: $table.analysisUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisErrorMessage => $composableBuilder(
    column: $table.analysisErrorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoCodec => $composableBuilder(
    column: $table.videoCodec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encoderBackend => $composableBuilder(
    column: $table.encoderBackend,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolutionPreset => $composableBuilder(
    column: $table.resolutionPreset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputDirectory => $composableBuilder(
    column: $table.outputDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get compressionCrf => $composableBuilder(
    column: $table.compressionCrf,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compressionMode => $composableBuilder(
    column: $table.compressionMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smartPreset => $composableBuilder(
    column: $table.smartPreset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetSizeBytes => $composableBuilder(
    column: $table.targetSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetSizeRatio => $composableBuilder(
    column: $table.targetSizeRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outputFileName => $composableBuilder(
    column: $table.outputFileName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedAt =>
      $composableBuilder(column: $table.failedAt, builder: (column) => column);
}

class $$TaskRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskRowsTable,
          TaskRow,
          $$TaskRowsTableFilterComposer,
          $$TaskRowsTableOrderingComposer,
          $$TaskRowsTableAnnotationComposer,
          $$TaskRowsTableCreateCompanionBuilder,
          $$TaskRowsTableUpdateCompanionBuilder,
          (TaskRow, BaseReferences<_$AppDatabase, $TaskRowsTable, TaskRow>),
          TaskRow,
          PrefetchHooks Function()
        > {
  $$TaskRowsTableTableManager(_$AppDatabase db, $TaskRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> inputPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> purpose = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int?> folderSortOrder = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<int?> outputFileSize = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> failureJson = const Value.absent(),
                Value<String?> policyTagsJson = const Value.absent(),
                Value<int?> sourceFileSize = const Value.absent(),
                Value<int?> sourceLastModifiedAt = const Value.absent(),
                Value<int?> analysisDurationMs = const Value.absent(),
                Value<int?> analysisVideoWidth = const Value.absent(),
                Value<int?> analysisVideoHeight = const Value.absent(),
                Value<String?> analysisVideoCodec = const Value.absent(),
                Value<String?> analysisAudioCodec = const Value.absent(),
                Value<String?> analysisVideoPixelFormat = const Value.absent(),
                Value<int?> analysisVideoBitDepth = const Value.absent(),
                Value<String?> analysisColorRange = const Value.absent(),
                Value<String?> analysisColorSpace = const Value.absent(),
                Value<String?> analysisColorTransfer = const Value.absent(),
                Value<String?> analysisColorPrimaries = const Value.absent(),
                Value<String?> analysisChromaLocation = const Value.absent(),
                Value<String?> analysisMasteringDisplayMetadata =
                    const Value.absent(),
                Value<double?> analysisMasteringDisplayMaxLuminance =
                    const Value.absent(),
                Value<int?> analysisMaxContentLightLevel = const Value.absent(),
                Value<int?> analysisMaxFrameAverageLightLevel =
                    const Value.absent(),
                Value<int?> analysisDolbyVisionProfile = const Value.absent(),
                Value<int?> analysisDolbyVisionCompatibilityId =
                    const Value.absent(),
                Value<String?> analysisAverageFrameRate = const Value.absent(),
                Value<String?> analysisRealFrameRate = const Value.absent(),
                Value<String?> analysisSampleAspectRatio = const Value.absent(),
                Value<String?> analysisDisplayAspectRatio =
                    const Value.absent(),
                Value<int?> analysisVideoRotationDegrees = const Value.absent(),
                Value<String?> analysisFieldOrder = const Value.absent(),
                Value<int?> analysisVideoBitrate = const Value.absent(),
                Value<int?> analysisAudioBitrate = const Value.absent(),
                Value<int?> analysisContainerBitrate = const Value.absent(),
                Value<int?> analysisEstimatedBitrate = const Value.absent(),
                Value<String?> analysisContainerFormat = const Value.absent(),
                Value<int?> analysisAudioChannels = const Value.absent(),
                Value<int?> analysisAudioSampleRate = const Value.absent(),
                Value<String?> analysisAudioChannelLayout =
                    const Value.absent(),
                Value<int?> analysisAudioStreamIndex = const Value.absent(),
                Value<String?> analysisAudioStreamsJson = const Value.absent(),
                Value<String?> mediaConfigJson = const Value.absent(),
                Value<int?> analysisImageWidth = const Value.absent(),
                Value<int?> analysisImageHeight = const Value.absent(),
                Value<String?> analysisImageCodec = const Value.absent(),
                Value<String?> analysisImagePixelFormat = const Value.absent(),
                Value<int?> analysisImageBitDepth = const Value.absent(),
                Value<int?> analysisUpdatedAt = const Value.absent(),
                Value<String?> analysisErrorMessage = const Value.absent(),
                Value<String> outputFormat = const Value.absent(),
                Value<String> videoCodec = const Value.absent(),
                Value<String> encoderBackend = const Value.absent(),
                Value<String> resolutionPreset = const Value.absent(),
                Value<String> outputDirectory = const Value.absent(),
                Value<int> compressionCrf = const Value.absent(),
                Value<String> compressionMode = const Value.absent(),
                Value<String?> smartPreset = const Value.absent(),
                Value<int?> targetSizeBytes = const Value.absent(),
                Value<double?> targetSizeRatio = const Value.absent(),
                Value<String> outputFileName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> failedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRowsCompanion(
                id: id,
                inputPath: inputPath,
                fileName: fileName,
                mediaKind: mediaKind,
                purpose: purpose,
                status: status,
                progress: progress,
                sortOrder: sortOrder,
                folderId: folderId,
                folderSortOrder: folderSortOrder,
                outputPath: outputPath,
                outputFileSize: outputFileSize,
                errorMessage: errorMessage,
                failureJson: failureJson,
                policyTagsJson: policyTagsJson,
                sourceFileSize: sourceFileSize,
                sourceLastModifiedAt: sourceLastModifiedAt,
                analysisDurationMs: analysisDurationMs,
                analysisVideoWidth: analysisVideoWidth,
                analysisVideoHeight: analysisVideoHeight,
                analysisVideoCodec: analysisVideoCodec,
                analysisAudioCodec: analysisAudioCodec,
                analysisVideoPixelFormat: analysisVideoPixelFormat,
                analysisVideoBitDepth: analysisVideoBitDepth,
                analysisColorRange: analysisColorRange,
                analysisColorSpace: analysisColorSpace,
                analysisColorTransfer: analysisColorTransfer,
                analysisColorPrimaries: analysisColorPrimaries,
                analysisChromaLocation: analysisChromaLocation,
                analysisMasteringDisplayMetadata:
                    analysisMasteringDisplayMetadata,
                analysisMasteringDisplayMaxLuminance:
                    analysisMasteringDisplayMaxLuminance,
                analysisMaxContentLightLevel: analysisMaxContentLightLevel,
                analysisMaxFrameAverageLightLevel:
                    analysisMaxFrameAverageLightLevel,
                analysisDolbyVisionProfile: analysisDolbyVisionProfile,
                analysisDolbyVisionCompatibilityId:
                    analysisDolbyVisionCompatibilityId,
                analysisAverageFrameRate: analysisAverageFrameRate,
                analysisRealFrameRate: analysisRealFrameRate,
                analysisSampleAspectRatio: analysisSampleAspectRatio,
                analysisDisplayAspectRatio: analysisDisplayAspectRatio,
                analysisVideoRotationDegrees: analysisVideoRotationDegrees,
                analysisFieldOrder: analysisFieldOrder,
                analysisVideoBitrate: analysisVideoBitrate,
                analysisAudioBitrate: analysisAudioBitrate,
                analysisContainerBitrate: analysisContainerBitrate,
                analysisEstimatedBitrate: analysisEstimatedBitrate,
                analysisContainerFormat: analysisContainerFormat,
                analysisAudioChannels: analysisAudioChannels,
                analysisAudioSampleRate: analysisAudioSampleRate,
                analysisAudioChannelLayout: analysisAudioChannelLayout,
                analysisAudioStreamIndex: analysisAudioStreamIndex,
                analysisAudioStreamsJson: analysisAudioStreamsJson,
                mediaConfigJson: mediaConfigJson,
                analysisImageWidth: analysisImageWidth,
                analysisImageHeight: analysisImageHeight,
                analysisImageCodec: analysisImageCodec,
                analysisImagePixelFormat: analysisImagePixelFormat,
                analysisImageBitDepth: analysisImageBitDepth,
                analysisUpdatedAt: analysisUpdatedAt,
                analysisErrorMessage: analysisErrorMessage,
                outputFormat: outputFormat,
                videoCodec: videoCodec,
                encoderBackend: encoderBackend,
                resolutionPreset: resolutionPreset,
                outputDirectory: outputDirectory,
                compressionCrf: compressionCrf,
                compressionMode: compressionMode,
                smartPreset: smartPreset,
                targetSizeBytes: targetSizeBytes,
                targetSizeRatio: targetSizeRatio,
                outputFileName: outputFileName,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                failedAt: failedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String inputPath,
                required String fileName,
                Value<String> mediaKind = const Value.absent(),
                required String purpose,
                required String status,
                Value<double> progress = const Value.absent(),
                required int sortOrder,
                Value<String?> folderId = const Value.absent(),
                Value<int?> folderSortOrder = const Value.absent(),
                Value<String?> outputPath = const Value.absent(),
                Value<int?> outputFileSize = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> failureJson = const Value.absent(),
                Value<String?> policyTagsJson = const Value.absent(),
                Value<int?> sourceFileSize = const Value.absent(),
                Value<int?> sourceLastModifiedAt = const Value.absent(),
                Value<int?> analysisDurationMs = const Value.absent(),
                Value<int?> analysisVideoWidth = const Value.absent(),
                Value<int?> analysisVideoHeight = const Value.absent(),
                Value<String?> analysisVideoCodec = const Value.absent(),
                Value<String?> analysisAudioCodec = const Value.absent(),
                Value<String?> analysisVideoPixelFormat = const Value.absent(),
                Value<int?> analysisVideoBitDepth = const Value.absent(),
                Value<String?> analysisColorRange = const Value.absent(),
                Value<String?> analysisColorSpace = const Value.absent(),
                Value<String?> analysisColorTransfer = const Value.absent(),
                Value<String?> analysisColorPrimaries = const Value.absent(),
                Value<String?> analysisChromaLocation = const Value.absent(),
                Value<String?> analysisMasteringDisplayMetadata =
                    const Value.absent(),
                Value<double?> analysisMasteringDisplayMaxLuminance =
                    const Value.absent(),
                Value<int?> analysisMaxContentLightLevel = const Value.absent(),
                Value<int?> analysisMaxFrameAverageLightLevel =
                    const Value.absent(),
                Value<int?> analysisDolbyVisionProfile = const Value.absent(),
                Value<int?> analysisDolbyVisionCompatibilityId =
                    const Value.absent(),
                Value<String?> analysisAverageFrameRate = const Value.absent(),
                Value<String?> analysisRealFrameRate = const Value.absent(),
                Value<String?> analysisSampleAspectRatio = const Value.absent(),
                Value<String?> analysisDisplayAspectRatio =
                    const Value.absent(),
                Value<int?> analysisVideoRotationDegrees = const Value.absent(),
                Value<String?> analysisFieldOrder = const Value.absent(),
                Value<int?> analysisVideoBitrate = const Value.absent(),
                Value<int?> analysisAudioBitrate = const Value.absent(),
                Value<int?> analysisContainerBitrate = const Value.absent(),
                Value<int?> analysisEstimatedBitrate = const Value.absent(),
                Value<String?> analysisContainerFormat = const Value.absent(),
                Value<int?> analysisAudioChannels = const Value.absent(),
                Value<int?> analysisAudioSampleRate = const Value.absent(),
                Value<String?> analysisAudioChannelLayout =
                    const Value.absent(),
                Value<int?> analysisAudioStreamIndex = const Value.absent(),
                Value<String?> analysisAudioStreamsJson = const Value.absent(),
                Value<String?> mediaConfigJson = const Value.absent(),
                Value<int?> analysisImageWidth = const Value.absent(),
                Value<int?> analysisImageHeight = const Value.absent(),
                Value<String?> analysisImageCodec = const Value.absent(),
                Value<String?> analysisImagePixelFormat = const Value.absent(),
                Value<int?> analysisImageBitDepth = const Value.absent(),
                Value<int?> analysisUpdatedAt = const Value.absent(),
                Value<String?> analysisErrorMessage = const Value.absent(),
                required String outputFormat,
                required String videoCodec,
                required String encoderBackend,
                required String resolutionPreset,
                required String outputDirectory,
                Value<int> compressionCrf = const Value.absent(),
                Value<String> compressionMode = const Value.absent(),
                Value<String?> smartPreset = const Value.absent(),
                Value<int?> targetSizeBytes = const Value.absent(),
                Value<double?> targetSizeRatio = const Value.absent(),
                Value<String> outputFileName = const Value.absent(),
                required int createdAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> failedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskRowsCompanion.insert(
                id: id,
                inputPath: inputPath,
                fileName: fileName,
                mediaKind: mediaKind,
                purpose: purpose,
                status: status,
                progress: progress,
                sortOrder: sortOrder,
                folderId: folderId,
                folderSortOrder: folderSortOrder,
                outputPath: outputPath,
                outputFileSize: outputFileSize,
                errorMessage: errorMessage,
                failureJson: failureJson,
                policyTagsJson: policyTagsJson,
                sourceFileSize: sourceFileSize,
                sourceLastModifiedAt: sourceLastModifiedAt,
                analysisDurationMs: analysisDurationMs,
                analysisVideoWidth: analysisVideoWidth,
                analysisVideoHeight: analysisVideoHeight,
                analysisVideoCodec: analysisVideoCodec,
                analysisAudioCodec: analysisAudioCodec,
                analysisVideoPixelFormat: analysisVideoPixelFormat,
                analysisVideoBitDepth: analysisVideoBitDepth,
                analysisColorRange: analysisColorRange,
                analysisColorSpace: analysisColorSpace,
                analysisColorTransfer: analysisColorTransfer,
                analysisColorPrimaries: analysisColorPrimaries,
                analysisChromaLocation: analysisChromaLocation,
                analysisMasteringDisplayMetadata:
                    analysisMasteringDisplayMetadata,
                analysisMasteringDisplayMaxLuminance:
                    analysisMasteringDisplayMaxLuminance,
                analysisMaxContentLightLevel: analysisMaxContentLightLevel,
                analysisMaxFrameAverageLightLevel:
                    analysisMaxFrameAverageLightLevel,
                analysisDolbyVisionProfile: analysisDolbyVisionProfile,
                analysisDolbyVisionCompatibilityId:
                    analysisDolbyVisionCompatibilityId,
                analysisAverageFrameRate: analysisAverageFrameRate,
                analysisRealFrameRate: analysisRealFrameRate,
                analysisSampleAspectRatio: analysisSampleAspectRatio,
                analysisDisplayAspectRatio: analysisDisplayAspectRatio,
                analysisVideoRotationDegrees: analysisVideoRotationDegrees,
                analysisFieldOrder: analysisFieldOrder,
                analysisVideoBitrate: analysisVideoBitrate,
                analysisAudioBitrate: analysisAudioBitrate,
                analysisContainerBitrate: analysisContainerBitrate,
                analysisEstimatedBitrate: analysisEstimatedBitrate,
                analysisContainerFormat: analysisContainerFormat,
                analysisAudioChannels: analysisAudioChannels,
                analysisAudioSampleRate: analysisAudioSampleRate,
                analysisAudioChannelLayout: analysisAudioChannelLayout,
                analysisAudioStreamIndex: analysisAudioStreamIndex,
                analysisAudioStreamsJson: analysisAudioStreamsJson,
                mediaConfigJson: mediaConfigJson,
                analysisImageWidth: analysisImageWidth,
                analysisImageHeight: analysisImageHeight,
                analysisImageCodec: analysisImageCodec,
                analysisImagePixelFormat: analysisImagePixelFormat,
                analysisImageBitDepth: analysisImageBitDepth,
                analysisUpdatedAt: analysisUpdatedAt,
                analysisErrorMessage: analysisErrorMessage,
                outputFormat: outputFormat,
                videoCodec: videoCodec,
                encoderBackend: encoderBackend,
                resolutionPreset: resolutionPreset,
                outputDirectory: outputDirectory,
                compressionCrf: compressionCrf,
                compressionMode: compressionMode,
                smartPreset: smartPreset,
                targetSizeBytes: targetSizeBytes,
                targetSizeRatio: targetSizeRatio,
                outputFileName: outputFileName,
                createdAt: createdAt,
                startedAt: startedAt,
                completedAt: completedAt,
                failedAt: failedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskRowsTable,
      TaskRow,
      $$TaskRowsTableFilterComposer,
      $$TaskRowsTableOrderingComposer,
      $$TaskRowsTableAnnotationComposer,
      $$TaskRowsTableCreateCompanionBuilder,
      $$TaskRowsTableUpdateCompanionBuilder,
      (TaskRow, BaseReferences<_$AppDatabase, $TaskRowsTable, TaskRow>),
      TaskRow,
      PrefetchHooks Function()
    >;
typedef $$TaskFolderRowsTableCreateCompanionBuilder =
    TaskFolderRowsCompanion Function({
      required String id,
      required String name,
      required String mediaKind,
      Value<String> origin,
      Value<String?> compatibilityClass,
      required int sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TaskFolderRowsTableUpdateCompanionBuilder =
    TaskFolderRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> mediaKind,
      Value<String> origin,
      Value<String?> compatibilityClass,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TaskFolderRowsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskFolderRowsTable> {
  $$TaskFolderRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compatibilityClass => $composableBuilder(
    column: $table.compatibilityClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskFolderRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskFolderRowsTable> {
  $$TaskFolderRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compatibilityClass => $composableBuilder(
    column: $table.compatibilityClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskFolderRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskFolderRowsTable> {
  $$TaskFolderRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get compatibilityClass => $composableBuilder(
    column: $table.compatibilityClass,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TaskFolderRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskFolderRowsTable,
          TaskFolderRow,
          $$TaskFolderRowsTableFilterComposer,
          $$TaskFolderRowsTableOrderingComposer,
          $$TaskFolderRowsTableAnnotationComposer,
          $$TaskFolderRowsTableCreateCompanionBuilder,
          $$TaskFolderRowsTableUpdateCompanionBuilder,
          (
            TaskFolderRow,
            BaseReferences<_$AppDatabase, $TaskFolderRowsTable, TaskFolderRow>,
          ),
          TaskFolderRow,
          PrefetchHooks Function()
        > {
  $$TaskFolderRowsTableTableManager(
    _$AppDatabase db,
    $TaskFolderRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskFolderRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskFolderRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskFolderRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String?> compatibilityClass = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskFolderRowsCompanion(
                id: id,
                name: name,
                mediaKind: mediaKind,
                origin: origin,
                compatibilityClass: compatibilityClass,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String mediaKind,
                Value<String> origin = const Value.absent(),
                Value<String?> compatibilityClass = const Value.absent(),
                required int sortOrder,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskFolderRowsCompanion.insert(
                id: id,
                name: name,
                mediaKind: mediaKind,
                origin: origin,
                compatibilityClass: compatibilityClass,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskFolderRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskFolderRowsTable,
      TaskFolderRow,
      $$TaskFolderRowsTableFilterComposer,
      $$TaskFolderRowsTableOrderingComposer,
      $$TaskFolderRowsTableAnnotationComposer,
      $$TaskFolderRowsTableCreateCompanionBuilder,
      $$TaskFolderRowsTableUpdateCompanionBuilder,
      (
        TaskFolderRow,
        BaseReferences<_$AppDatabase, $TaskFolderRowsTable, TaskFolderRow>,
      ),
      TaskFolderRow,
      PrefetchHooks Function()
    >;
typedef $$AppNotificationRowsTableCreateCompanionBuilder =
    AppNotificationRowsCompanion Function({
      required String id,
      Value<String> kind,
      required String level,
      required String title,
      Value<String> message,
      required String source,
      Value<String?> dedupeKey,
      required int createdAt,
      Value<int?> readAt,
      Value<int?> dismissedAt,
      Value<String?> payloadJson,
      Value<int> rowid,
    });
typedef $$AppNotificationRowsTableUpdateCompanionBuilder =
    AppNotificationRowsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> level,
      Value<String> title,
      Value<String> message,
      Value<String> source,
      Value<String?> dedupeKey,
      Value<int> createdAt,
      Value<int?> readAt,
      Value<int?> dismissedAt,
      Value<String?> payloadJson,
      Value<int> rowid,
    });

class $$AppNotificationRowsTableFilterComposer
    extends Composer<_$AppDatabase, $AppNotificationRowsTable> {
  $$AppNotificationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppNotificationRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppNotificationRowsTable> {
  $$AppNotificationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppNotificationRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppNotificationRowsTable> {
  $$AppNotificationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$AppNotificationRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppNotificationRowsTable,
          AppNotificationRow,
          $$AppNotificationRowsTableFilterComposer,
          $$AppNotificationRowsTableOrderingComposer,
          $$AppNotificationRowsTableAnnotationComposer,
          $$AppNotificationRowsTableCreateCompanionBuilder,
          $$AppNotificationRowsTableUpdateCompanionBuilder,
          (
            AppNotificationRow,
            BaseReferences<
              _$AppDatabase,
              $AppNotificationRowsTable,
              AppNotificationRow
            >,
          ),
          AppNotificationRow,
          PrefetchHooks Function()
        > {
  $$AppNotificationRowsTableTableManager(
    _$AppDatabase db,
    $AppNotificationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppNotificationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppNotificationRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AppNotificationRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> readAt = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppNotificationRowsCompanion(
                id: id,
                kind: kind,
                level: level,
                title: title,
                message: message,
                source: source,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
                readAt: readAt,
                dismissedAt: dismissedAt,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> kind = const Value.absent(),
                required String level,
                required String title,
                Value<String> message = const Value.absent(),
                required String source,
                Value<String?> dedupeKey = const Value.absent(),
                required int createdAt,
                Value<int?> readAt = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppNotificationRowsCompanion.insert(
                id: id,
                kind: kind,
                level: level,
                title: title,
                message: message,
                source: source,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
                readAt: readAt,
                dismissedAt: dismissedAt,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppNotificationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppNotificationRowsTable,
      AppNotificationRow,
      $$AppNotificationRowsTableFilterComposer,
      $$AppNotificationRowsTableOrderingComposer,
      $$AppNotificationRowsTableAnnotationComposer,
      $$AppNotificationRowsTableCreateCompanionBuilder,
      $$AppNotificationRowsTableUpdateCompanionBuilder,
      (
        AppNotificationRow,
        BaseReferences<
          _$AppDatabase,
          $AppNotificationRowsTable,
          AppNotificationRow
        >,
      ),
      AppNotificationRow,
      PrefetchHooks Function()
    >;
typedef $$EngineAnalysisProjectionRowsTableCreateCompanionBuilder =
    EngineAnalysisProjectionRowsCompanion Function({
      required String taskId,
      required String clientFileId,
      required String engineSessionId,
      Value<String?> analysisId,
      Value<int?> revision,
      Value<String?> schemaVersion,
      Value<String?> snapshotJson,
      Value<String?> validityStatus,
      Value<String?> analysisWorkId,
      Value<String?> analysisRequestId,
      Value<int?> analysisQueuePosition,
      Value<int?> analysisQueueRevision,
      Value<String?> executionId,
      Value<String?> executionRequestId,
      Value<int?> executionQueuePosition,
      Value<int?> executionQueueRevision,
      Value<String?> executionState,
      Value<String?> pauseReason,
      Value<String?> preemptedByExecutionId,
      Value<int?> resumeDepth,
      Value<int?> mediaTimeUs,
      Value<int?> processedBytes,
      Value<int> lastEventSequence,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EngineAnalysisProjectionRowsTableUpdateCompanionBuilder =
    EngineAnalysisProjectionRowsCompanion Function({
      Value<String> taskId,
      Value<String> clientFileId,
      Value<String> engineSessionId,
      Value<String?> analysisId,
      Value<int?> revision,
      Value<String?> schemaVersion,
      Value<String?> snapshotJson,
      Value<String?> validityStatus,
      Value<String?> analysisWorkId,
      Value<String?> analysisRequestId,
      Value<int?> analysisQueuePosition,
      Value<int?> analysisQueueRevision,
      Value<String?> executionId,
      Value<String?> executionRequestId,
      Value<int?> executionQueuePosition,
      Value<int?> executionQueueRevision,
      Value<String?> executionState,
      Value<String?> pauseReason,
      Value<String?> preemptedByExecutionId,
      Value<int?> resumeDepth,
      Value<int?> mediaTimeUs,
      Value<int?> processedBytes,
      Value<int> lastEventSequence,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EngineAnalysisProjectionRowsTableFilterComposer
    extends Composer<_$AppDatabase, $EngineAnalysisProjectionRowsTable> {
  $$EngineAnalysisProjectionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientFileId => $composableBuilder(
    column: $table.clientFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineSessionId => $composableBuilder(
    column: $table.engineSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisId => $composableBuilder(
    column: $table.analysisId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validityStatus => $composableBuilder(
    column: $table.validityStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisWorkId => $composableBuilder(
    column: $table.analysisWorkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysisRequestId => $composableBuilder(
    column: $table.analysisRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisQueuePosition => $composableBuilder(
    column: $table.analysisQueuePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get analysisQueueRevision => $composableBuilder(
    column: $table.analysisQueueRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionRequestId => $composableBuilder(
    column: $table.executionRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get executionQueuePosition => $composableBuilder(
    column: $table.executionQueuePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get executionQueueRevision => $composableBuilder(
    column: $table.executionQueueRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get executionState => $composableBuilder(
    column: $table.executionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preemptedByExecutionId => $composableBuilder(
    column: $table.preemptedByExecutionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resumeDepth => $composableBuilder(
    column: $table.resumeDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaTimeUs => $composableBuilder(
    column: $table.mediaTimeUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processedBytes => $composableBuilder(
    column: $table.processedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastEventSequence => $composableBuilder(
    column: $table.lastEventSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EngineAnalysisProjectionRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $EngineAnalysisProjectionRowsTable> {
  $$EngineAnalysisProjectionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientFileId => $composableBuilder(
    column: $table.clientFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineSessionId => $composableBuilder(
    column: $table.engineSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisId => $composableBuilder(
    column: $table.analysisId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validityStatus => $composableBuilder(
    column: $table.validityStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisWorkId => $composableBuilder(
    column: $table.analysisWorkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysisRequestId => $composableBuilder(
    column: $table.analysisRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisQueuePosition => $composableBuilder(
    column: $table.analysisQueuePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get analysisQueueRevision => $composableBuilder(
    column: $table.analysisQueueRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionRequestId => $composableBuilder(
    column: $table.executionRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get executionQueuePosition => $composableBuilder(
    column: $table.executionQueuePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get executionQueueRevision => $composableBuilder(
    column: $table.executionQueueRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get executionState => $composableBuilder(
    column: $table.executionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preemptedByExecutionId => $composableBuilder(
    column: $table.preemptedByExecutionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resumeDepth => $composableBuilder(
    column: $table.resumeDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaTimeUs => $composableBuilder(
    column: $table.mediaTimeUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processedBytes => $composableBuilder(
    column: $table.processedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastEventSequence => $composableBuilder(
    column: $table.lastEventSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EngineAnalysisProjectionRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EngineAnalysisProjectionRowsTable> {
  $$EngineAnalysisProjectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get clientFileId => $composableBuilder(
    column: $table.clientFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engineSessionId => $composableBuilder(
    column: $table.engineSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisId => $composableBuilder(
    column: $table.analysisId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get validityStatus => $composableBuilder(
    column: $table.validityStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisWorkId => $composableBuilder(
    column: $table.analysisWorkId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get analysisRequestId => $composableBuilder(
    column: $table.analysisRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisQueuePosition => $composableBuilder(
    column: $table.analysisQueuePosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get analysisQueueRevision => $composableBuilder(
    column: $table.analysisQueueRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get executionId => $composableBuilder(
    column: $table.executionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get executionRequestId => $composableBuilder(
    column: $table.executionRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get executionQueuePosition => $composableBuilder(
    column: $table.executionQueuePosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get executionQueueRevision => $composableBuilder(
    column: $table.executionQueueRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get executionState => $composableBuilder(
    column: $table.executionState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preemptedByExecutionId => $composableBuilder(
    column: $table.preemptedByExecutionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resumeDepth => $composableBuilder(
    column: $table.resumeDepth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaTimeUs => $composableBuilder(
    column: $table.mediaTimeUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processedBytes => $composableBuilder(
    column: $table.processedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastEventSequence => $composableBuilder(
    column: $table.lastEventSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EngineAnalysisProjectionRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EngineAnalysisProjectionRowsTable,
          EngineAnalysisProjectionRow,
          $$EngineAnalysisProjectionRowsTableFilterComposer,
          $$EngineAnalysisProjectionRowsTableOrderingComposer,
          $$EngineAnalysisProjectionRowsTableAnnotationComposer,
          $$EngineAnalysisProjectionRowsTableCreateCompanionBuilder,
          $$EngineAnalysisProjectionRowsTableUpdateCompanionBuilder,
          (
            EngineAnalysisProjectionRow,
            BaseReferences<
              _$AppDatabase,
              $EngineAnalysisProjectionRowsTable,
              EngineAnalysisProjectionRow
            >,
          ),
          EngineAnalysisProjectionRow,
          PrefetchHooks Function()
        > {
  $$EngineAnalysisProjectionRowsTableTableManager(
    _$AppDatabase db,
    $EngineAnalysisProjectionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EngineAnalysisProjectionRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EngineAnalysisProjectionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EngineAnalysisProjectionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> clientFileId = const Value.absent(),
                Value<String> engineSessionId = const Value.absent(),
                Value<String?> analysisId = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<String?> schemaVersion = const Value.absent(),
                Value<String?> snapshotJson = const Value.absent(),
                Value<String?> validityStatus = const Value.absent(),
                Value<String?> analysisWorkId = const Value.absent(),
                Value<String?> analysisRequestId = const Value.absent(),
                Value<int?> analysisQueuePosition = const Value.absent(),
                Value<int?> analysisQueueRevision = const Value.absent(),
                Value<String?> executionId = const Value.absent(),
                Value<String?> executionRequestId = const Value.absent(),
                Value<int?> executionQueuePosition = const Value.absent(),
                Value<int?> executionQueueRevision = const Value.absent(),
                Value<String?> executionState = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<String?> preemptedByExecutionId = const Value.absent(),
                Value<int?> resumeDepth = const Value.absent(),
                Value<int?> mediaTimeUs = const Value.absent(),
                Value<int?> processedBytes = const Value.absent(),
                Value<int> lastEventSequence = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EngineAnalysisProjectionRowsCompanion(
                taskId: taskId,
                clientFileId: clientFileId,
                engineSessionId: engineSessionId,
                analysisId: analysisId,
                revision: revision,
                schemaVersion: schemaVersion,
                snapshotJson: snapshotJson,
                validityStatus: validityStatus,
                analysisWorkId: analysisWorkId,
                analysisRequestId: analysisRequestId,
                analysisQueuePosition: analysisQueuePosition,
                analysisQueueRevision: analysisQueueRevision,
                executionId: executionId,
                executionRequestId: executionRequestId,
                executionQueuePosition: executionQueuePosition,
                executionQueueRevision: executionQueueRevision,
                executionState: executionState,
                pauseReason: pauseReason,
                preemptedByExecutionId: preemptedByExecutionId,
                resumeDepth: resumeDepth,
                mediaTimeUs: mediaTimeUs,
                processedBytes: processedBytes,
                lastEventSequence: lastEventSequence,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String taskId,
                required String clientFileId,
                required String engineSessionId,
                Value<String?> analysisId = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<String?> schemaVersion = const Value.absent(),
                Value<String?> snapshotJson = const Value.absent(),
                Value<String?> validityStatus = const Value.absent(),
                Value<String?> analysisWorkId = const Value.absent(),
                Value<String?> analysisRequestId = const Value.absent(),
                Value<int?> analysisQueuePosition = const Value.absent(),
                Value<int?> analysisQueueRevision = const Value.absent(),
                Value<String?> executionId = const Value.absent(),
                Value<String?> executionRequestId = const Value.absent(),
                Value<int?> executionQueuePosition = const Value.absent(),
                Value<int?> executionQueueRevision = const Value.absent(),
                Value<String?> executionState = const Value.absent(),
                Value<String?> pauseReason = const Value.absent(),
                Value<String?> preemptedByExecutionId = const Value.absent(),
                Value<int?> resumeDepth = const Value.absent(),
                Value<int?> mediaTimeUs = const Value.absent(),
                Value<int?> processedBytes = const Value.absent(),
                Value<int> lastEventSequence = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EngineAnalysisProjectionRowsCompanion.insert(
                taskId: taskId,
                clientFileId: clientFileId,
                engineSessionId: engineSessionId,
                analysisId: analysisId,
                revision: revision,
                schemaVersion: schemaVersion,
                snapshotJson: snapshotJson,
                validityStatus: validityStatus,
                analysisWorkId: analysisWorkId,
                analysisRequestId: analysisRequestId,
                analysisQueuePosition: analysisQueuePosition,
                analysisQueueRevision: analysisQueueRevision,
                executionId: executionId,
                executionRequestId: executionRequestId,
                executionQueuePosition: executionQueuePosition,
                executionQueueRevision: executionQueueRevision,
                executionState: executionState,
                pauseReason: pauseReason,
                preemptedByExecutionId: preemptedByExecutionId,
                resumeDepth: resumeDepth,
                mediaTimeUs: mediaTimeUs,
                processedBytes: processedBytes,
                lastEventSequence: lastEventSequence,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EngineAnalysisProjectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EngineAnalysisProjectionRowsTable,
      EngineAnalysisProjectionRow,
      $$EngineAnalysisProjectionRowsTableFilterComposer,
      $$EngineAnalysisProjectionRowsTableOrderingComposer,
      $$EngineAnalysisProjectionRowsTableAnnotationComposer,
      $$EngineAnalysisProjectionRowsTableCreateCompanionBuilder,
      $$EngineAnalysisProjectionRowsTableUpdateCompanionBuilder,
      (
        EngineAnalysisProjectionRow,
        BaseReferences<
          _$AppDatabase,
          $EngineAnalysisProjectionRowsTable,
          EngineAnalysisProjectionRow
        >,
      ),
      EngineAnalysisProjectionRow,
      PrefetchHooks Function()
    >;
typedef $$WorkbenchOrderStateRowsTableCreateCompanionBuilder =
    WorkbenchOrderStateRowsCompanion Function({
      Value<int> id,
      Value<int> orderRevision,
    });
typedef $$WorkbenchOrderStateRowsTableUpdateCompanionBuilder =
    WorkbenchOrderStateRowsCompanion Function({
      Value<int> id,
      Value<int> orderRevision,
    });

class $$WorkbenchOrderStateRowsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkbenchOrderStateRowsTable> {
  $$WorkbenchOrderStateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderRevision => $composableBuilder(
    column: $table.orderRevision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkbenchOrderStateRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkbenchOrderStateRowsTable> {
  $$WorkbenchOrderStateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderRevision => $composableBuilder(
    column: $table.orderRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkbenchOrderStateRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkbenchOrderStateRowsTable> {
  $$WorkbenchOrderStateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderRevision => $composableBuilder(
    column: $table.orderRevision,
    builder: (column) => column,
  );
}

class $$WorkbenchOrderStateRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkbenchOrderStateRowsTable,
          WorkbenchOrderStateRow,
          $$WorkbenchOrderStateRowsTableFilterComposer,
          $$WorkbenchOrderStateRowsTableOrderingComposer,
          $$WorkbenchOrderStateRowsTableAnnotationComposer,
          $$WorkbenchOrderStateRowsTableCreateCompanionBuilder,
          $$WorkbenchOrderStateRowsTableUpdateCompanionBuilder,
          (
            WorkbenchOrderStateRow,
            BaseReferences<
              _$AppDatabase,
              $WorkbenchOrderStateRowsTable,
              WorkbenchOrderStateRow
            >,
          ),
          WorkbenchOrderStateRow,
          PrefetchHooks Function()
        > {
  $$WorkbenchOrderStateRowsTableTableManager(
    _$AppDatabase db,
    $WorkbenchOrderStateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkbenchOrderStateRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkbenchOrderStateRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkbenchOrderStateRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> orderRevision = const Value.absent(),
              }) => WorkbenchOrderStateRowsCompanion(
                id: id,
                orderRevision: orderRevision,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> orderRevision = const Value.absent(),
              }) => WorkbenchOrderStateRowsCompanion.insert(
                id: id,
                orderRevision: orderRevision,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkbenchOrderStateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkbenchOrderStateRowsTable,
      WorkbenchOrderStateRow,
      $$WorkbenchOrderStateRowsTableFilterComposer,
      $$WorkbenchOrderStateRowsTableOrderingComposer,
      $$WorkbenchOrderStateRowsTableAnnotationComposer,
      $$WorkbenchOrderStateRowsTableCreateCompanionBuilder,
      $$WorkbenchOrderStateRowsTableUpdateCompanionBuilder,
      (
        WorkbenchOrderStateRow,
        BaseReferences<
          _$AppDatabase,
          $WorkbenchOrderStateRowsTable,
          WorkbenchOrderStateRow
        >,
      ),
      WorkbenchOrderStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsRowsTableTableManager get settingsRows =>
      $$SettingsRowsTableTableManager(_db, _db.settingsRows);
  $$TaskRowsTableTableManager get taskRows =>
      $$TaskRowsTableTableManager(_db, _db.taskRows);
  $$TaskFolderRowsTableTableManager get taskFolderRows =>
      $$TaskFolderRowsTableTableManager(_db, _db.taskFolderRows);
  $$AppNotificationRowsTableTableManager get appNotificationRows =>
      $$AppNotificationRowsTableTableManager(_db, _db.appNotificationRows);
  $$EngineAnalysisProjectionRowsTableTableManager
  get engineAnalysisProjectionRows =>
      $$EngineAnalysisProjectionRowsTableTableManager(
        _db,
        _db.engineAnalysisProjectionRows,
      );
  $$WorkbenchOrderStateRowsTableTableManager get workbenchOrderStateRows =>
      $$WorkbenchOrderStateRowsTableTableManager(
        _db,
        _db.workbenchOrderStateRows,
      );
}
