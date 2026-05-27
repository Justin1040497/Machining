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
  static const VerificationMeta _customFfmpegPathMeta = const VerificationMeta(
    'customFfmpegPath',
  );
  @override
  late final GeneratedColumn<String> customFfmpegPath = GeneratedColumn<String>(
    'custom_ffmpeg_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customFfprobePathMeta = const VerificationMeta(
    'customFfprobePath',
  );
  @override
  late final GeneratedColumn<String> customFfprobePath =
      GeneratedColumn<String>(
        'custom_ffprobe_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
        defaultValue: const Constant('balanced'),
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
        defaultValue: const Constant('datetimeOriginalCodec'),
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
    customFfmpegPath,
    customFfprobePath,
    showRawLog,
    showAdvancedOptions,
    defaultOutputVideoCodec,
    defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate,
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
    if (data.containsKey('custom_ffmpeg_path')) {
      context.handle(
        _customFfmpegPathMeta,
        customFfmpegPath.isAcceptableOrUnknown(
          data['custom_ffmpeg_path']!,
          _customFfmpegPathMeta,
        ),
      );
    }
    if (data.containsKey('custom_ffprobe_path')) {
      context.handle(
        _customFfprobePathMeta,
        customFfprobePath.isAcceptableOrUnknown(
          data['custom_ffprobe_path']!,
          _customFfprobePathMeta,
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
      customFfmpegPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_ffmpeg_path'],
      ),
      customFfprobePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_ffprobe_path'],
      ),
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
  final String? customFfmpegPath;
  final String? customFfprobePath;
  final bool showRawLog;
  final bool showAdvancedOptions;
  final String defaultOutputVideoCodec;
  final String defaultCompressionSmartPreset;
  final String defaultOutputFileNameTemplate;
  final int createdAt;
  final int updatedAt;
  const SettingsRow({
    required this.id,
    this.defaultOutputDirectory,
    this.lastSelectedOutputDirectory,
    required this.saveOutputToSourceDirectory,
    this.customFfmpegPath,
    this.customFfprobePath,
    required this.showRawLog,
    required this.showAdvancedOptions,
    required this.defaultOutputVideoCodec,
    required this.defaultCompressionSmartPreset,
    required this.defaultOutputFileNameTemplate,
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
    if (!nullToAbsent || customFfmpegPath != null) {
      map['custom_ffmpeg_path'] = Variable<String>(customFfmpegPath);
    }
    if (!nullToAbsent || customFfprobePath != null) {
      map['custom_ffprobe_path'] = Variable<String>(customFfprobePath);
    }
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
      customFfmpegPath: customFfmpegPath == null && nullToAbsent
          ? const Value.absent()
          : Value(customFfmpegPath),
      customFfprobePath: customFfprobePath == null && nullToAbsent
          ? const Value.absent()
          : Value(customFfprobePath),
      showRawLog: Value(showRawLog),
      showAdvancedOptions: Value(showAdvancedOptions),
      defaultOutputVideoCodec: Value(defaultOutputVideoCodec),
      defaultCompressionSmartPreset: Value(defaultCompressionSmartPreset),
      defaultOutputFileNameTemplate: Value(defaultOutputFileNameTemplate),
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
      customFfmpegPath: serializer.fromJson<String?>(json['customFfmpegPath']),
      customFfprobePath: serializer.fromJson<String?>(
        json['customFfprobePath'],
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
      'customFfmpegPath': serializer.toJson<String?>(customFfmpegPath),
      'customFfprobePath': serializer.toJson<String?>(customFfprobePath),
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
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SettingsRow copyWith({
    int? id,
    Value<String?> defaultOutputDirectory = const Value.absent(),
    Value<String?> lastSelectedOutputDirectory = const Value.absent(),
    bool? saveOutputToSourceDirectory,
    Value<String?> customFfmpegPath = const Value.absent(),
    Value<String?> customFfprobePath = const Value.absent(),
    bool? showRawLog,
    bool? showAdvancedOptions,
    String? defaultOutputVideoCodec,
    String? defaultCompressionSmartPreset,
    String? defaultOutputFileNameTemplate,
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
    customFfmpegPath: customFfmpegPath.present
        ? customFfmpegPath.value
        : this.customFfmpegPath,
    customFfprobePath: customFfprobePath.present
        ? customFfprobePath.value
        : this.customFfprobePath,
    showRawLog: showRawLog ?? this.showRawLog,
    showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
    defaultOutputVideoCodec:
        defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
    defaultCompressionSmartPreset:
        defaultCompressionSmartPreset ?? this.defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate:
        defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
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
      customFfmpegPath: data.customFfmpegPath.present
          ? data.customFfmpegPath.value
          : this.customFfmpegPath,
      customFfprobePath: data.customFfprobePath.present
          ? data.customFfprobePath.value
          : this.customFfprobePath,
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
          ..write('customFfmpegPath: $customFfmpegPath, ')
          ..write('customFfprobePath: $customFfprobePath, ')
          ..write('showRawLog: $showRawLog, ')
          ..write('showAdvancedOptions: $showAdvancedOptions, ')
          ..write('defaultOutputVideoCodec: $defaultOutputVideoCodec, ')
          ..write(
            'defaultCompressionSmartPreset: $defaultCompressionSmartPreset, ',
          )
          ..write(
            'defaultOutputFileNameTemplate: $defaultOutputFileNameTemplate, ',
          )
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
    customFfmpegPath,
    customFfprobePath,
    showRawLog,
    showAdvancedOptions,
    defaultOutputVideoCodec,
    defaultCompressionSmartPreset,
    defaultOutputFileNameTemplate,
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
          other.customFfmpegPath == this.customFfmpegPath &&
          other.customFfprobePath == this.customFfprobePath &&
          other.showRawLog == this.showRawLog &&
          other.showAdvancedOptions == this.showAdvancedOptions &&
          other.defaultOutputVideoCodec == this.defaultOutputVideoCodec &&
          other.defaultCompressionSmartPreset ==
              this.defaultCompressionSmartPreset &&
          other.defaultOutputFileNameTemplate ==
              this.defaultOutputFileNameTemplate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<String?> defaultOutputDirectory;
  final Value<String?> lastSelectedOutputDirectory;
  final Value<bool> saveOutputToSourceDirectory;
  final Value<String?> customFfmpegPath;
  final Value<String?> customFfprobePath;
  final Value<bool> showRawLog;
  final Value<bool> showAdvancedOptions;
  final Value<String> defaultOutputVideoCodec;
  final Value<String> defaultCompressionSmartPreset;
  final Value<String> defaultOutputFileNameTemplate;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const SettingsRowsCompanion({
    this.id = const Value.absent(),
    this.defaultOutputDirectory = const Value.absent(),
    this.lastSelectedOutputDirectory = const Value.absent(),
    this.saveOutputToSourceDirectory = const Value.absent(),
    this.customFfmpegPath = const Value.absent(),
    this.customFfprobePath = const Value.absent(),
    this.showRawLog = const Value.absent(),
    this.showAdvancedOptions = const Value.absent(),
    this.defaultOutputVideoCodec = const Value.absent(),
    this.defaultCompressionSmartPreset = const Value.absent(),
    this.defaultOutputFileNameTemplate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    this.id = const Value.absent(),
    this.defaultOutputDirectory = const Value.absent(),
    this.lastSelectedOutputDirectory = const Value.absent(),
    this.saveOutputToSourceDirectory = const Value.absent(),
    this.customFfmpegPath = const Value.absent(),
    this.customFfprobePath = const Value.absent(),
    this.showRawLog = const Value.absent(),
    this.showAdvancedOptions = const Value.absent(),
    this.defaultOutputVideoCodec = const Value.absent(),
    this.defaultCompressionSmartPreset = const Value.absent(),
    this.defaultOutputFileNameTemplate = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<String>? defaultOutputDirectory,
    Expression<String>? lastSelectedOutputDirectory,
    Expression<bool>? saveOutputToSourceDirectory,
    Expression<String>? customFfmpegPath,
    Expression<String>? customFfprobePath,
    Expression<bool>? showRawLog,
    Expression<bool>? showAdvancedOptions,
    Expression<String>? defaultOutputVideoCodec,
    Expression<String>? defaultCompressionSmartPreset,
    Expression<String>? defaultOutputFileNameTemplate,
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
      if (customFfmpegPath != null) 'custom_ffmpeg_path': customFfmpegPath,
      if (customFfprobePath != null) 'custom_ffprobe_path': customFfprobePath,
      if (showRawLog != null) 'show_raw_log': showRawLog,
      if (showAdvancedOptions != null)
        'show_advanced_options': showAdvancedOptions,
      if (defaultOutputVideoCodec != null)
        'default_output_video_codec': defaultOutputVideoCodec,
      if (defaultCompressionSmartPreset != null)
        'default_compression_smart_preset': defaultCompressionSmartPreset,
      if (defaultOutputFileNameTemplate != null)
        'default_output_file_name_template': defaultOutputFileNameTemplate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<int>? id,
    Value<String?>? defaultOutputDirectory,
    Value<String?>? lastSelectedOutputDirectory,
    Value<bool>? saveOutputToSourceDirectory,
    Value<String?>? customFfmpegPath,
    Value<String?>? customFfprobePath,
    Value<bool>? showRawLog,
    Value<bool>? showAdvancedOptions,
    Value<String>? defaultOutputVideoCodec,
    Value<String>? defaultCompressionSmartPreset,
    Value<String>? defaultOutputFileNameTemplate,
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
      customFfmpegPath: customFfmpegPath ?? this.customFfmpegPath,
      customFfprobePath: customFfprobePath ?? this.customFfprobePath,
      showRawLog: showRawLog ?? this.showRawLog,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
      defaultOutputVideoCodec:
          defaultOutputVideoCodec ?? this.defaultOutputVideoCodec,
      defaultCompressionSmartPreset:
          defaultCompressionSmartPreset ?? this.defaultCompressionSmartPreset,
      defaultOutputFileNameTemplate:
          defaultOutputFileNameTemplate ?? this.defaultOutputFileNameTemplate,
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
    if (customFfmpegPath.present) {
      map['custom_ffmpeg_path'] = Variable<String>(customFfmpegPath.value);
    }
    if (customFfprobePath.present) {
      map['custom_ffprobe_path'] = Variable<String>(customFfprobePath.value);
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
          ..write('customFfmpegPath: $customFfmpegPath, ')
          ..write('customFfprobePath: $customFfprobePath, ')
          ..write('showRawLog: $showRawLog, ')
          ..write('showAdvancedOptions: $showAdvancedOptions, ')
          ..write('defaultOutputVideoCodec: $defaultOutputVideoCodec, ')
          ..write(
            'defaultCompressionSmartPreset: $defaultCompressionSmartPreset, ',
          )
          ..write(
            'defaultOutputFileNameTemplate: $defaultOutputFileNameTemplate, ',
          )
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
    outputPath,
    errorMessage,
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
    if (data.containsKey('output_path')) {
      context.handle(
        _outputPathMeta,
        outputPath.isAcceptableOrUnknown(data['output_path']!, _outputPathMeta),
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
      outputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_path'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
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
  final String? outputPath;
  final String? errorMessage;
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
    this.outputPath,
    this.errorMessage,
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
    if (!nullToAbsent || outputPath != null) {
      map['output_path'] = Variable<String>(outputPath);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
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
      outputPath: outputPath == null && nullToAbsent
          ? const Value.absent()
          : Value(outputPath),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
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
      outputPath: serializer.fromJson<String?>(json['outputPath']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
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
      'outputPath': serializer.toJson<String?>(outputPath),
      'errorMessage': serializer.toJson<String?>(errorMessage),
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
    Value<String?> outputPath = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
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
    outputPath: outputPath.present ? outputPath.value : this.outputPath,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
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
      outputPath: data.outputPath.present
          ? data.outputPath.value
          : this.outputPath,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
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
          ..write('outputPath: $outputPath, ')
          ..write('errorMessage: $errorMessage, ')
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
    outputPath,
    errorMessage,
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
          other.outputPath == this.outputPath &&
          other.errorMessage == this.errorMessage &&
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
  final Value<String?> outputPath;
  final Value<String?> errorMessage;
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
    this.outputPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
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
    this.outputPath = const Value.absent(),
    this.errorMessage = const Value.absent(),
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
    Expression<String>? outputPath,
    Expression<String>? errorMessage,
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
      if (outputPath != null) 'output_path': outputPath,
      if (errorMessage != null) 'error_message': errorMessage,
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
    Value<String?>? outputPath,
    Value<String?>? errorMessage,
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
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
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
    if (outputPath.present) {
      map['output_path'] = Variable<String>(outputPath.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
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
          ..write('outputPath: $outputPath, ')
          ..write('errorMessage: $errorMessage, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsRowsTable settingsRows = $SettingsRowsTable(this);
  late final $TaskRowsTable taskRows = $TaskRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [settingsRows, taskRows];
}

typedef $$SettingsRowsTableCreateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<String?> defaultOutputDirectory,
      Value<String?> lastSelectedOutputDirectory,
      Value<bool> saveOutputToSourceDirectory,
      Value<String?> customFfmpegPath,
      Value<String?> customFfprobePath,
      Value<bool> showRawLog,
      Value<bool> showAdvancedOptions,
      Value<String> defaultOutputVideoCodec,
      Value<String> defaultCompressionSmartPreset,
      Value<String> defaultOutputFileNameTemplate,
      required int createdAt,
      required int updatedAt,
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<String?> defaultOutputDirectory,
      Value<String?> lastSelectedOutputDirectory,
      Value<bool> saveOutputToSourceDirectory,
      Value<String?> customFfmpegPath,
      Value<String?> customFfprobePath,
      Value<bool> showRawLog,
      Value<bool> showAdvancedOptions,
      Value<String> defaultOutputVideoCodec,
      Value<String> defaultCompressionSmartPreset,
      Value<String> defaultOutputFileNameTemplate,
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

  ColumnFilters<String> get customFfmpegPath => $composableBuilder(
    column: $table.customFfmpegPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customFfprobePath => $composableBuilder(
    column: $table.customFfprobePath,
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

  ColumnOrderings<String> get customFfmpegPath => $composableBuilder(
    column: $table.customFfmpegPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customFfprobePath => $composableBuilder(
    column: $table.customFfprobePath,
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

  GeneratedColumn<String> get customFfmpegPath => $composableBuilder(
    column: $table.customFfmpegPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customFfprobePath => $composableBuilder(
    column: $table.customFfprobePath,
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
                Value<String?> customFfmpegPath = const Value.absent(),
                Value<String?> customFfprobePath = const Value.absent(),
                Value<bool> showRawLog = const Value.absent(),
                Value<bool> showAdvancedOptions = const Value.absent(),
                Value<String> defaultOutputVideoCodec = const Value.absent(),
                Value<String> defaultCompressionSmartPreset =
                    const Value.absent(),
                Value<String> defaultOutputFileNameTemplate =
                    const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => SettingsRowsCompanion(
                id: id,
                defaultOutputDirectory: defaultOutputDirectory,
                lastSelectedOutputDirectory: lastSelectedOutputDirectory,
                saveOutputToSourceDirectory: saveOutputToSourceDirectory,
                customFfmpegPath: customFfmpegPath,
                customFfprobePath: customFfprobePath,
                showRawLog: showRawLog,
                showAdvancedOptions: showAdvancedOptions,
                defaultOutputVideoCodec: defaultOutputVideoCodec,
                defaultCompressionSmartPreset: defaultCompressionSmartPreset,
                defaultOutputFileNameTemplate: defaultOutputFileNameTemplate,
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
                Value<String?> customFfmpegPath = const Value.absent(),
                Value<String?> customFfprobePath = const Value.absent(),
                Value<bool> showRawLog = const Value.absent(),
                Value<bool> showAdvancedOptions = const Value.absent(),
                Value<String> defaultOutputVideoCodec = const Value.absent(),
                Value<String> defaultCompressionSmartPreset =
                    const Value.absent(),
                Value<String> defaultOutputFileNameTemplate =
                    const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => SettingsRowsCompanion.insert(
                id: id,
                defaultOutputDirectory: defaultOutputDirectory,
                lastSelectedOutputDirectory: lastSelectedOutputDirectory,
                saveOutputToSourceDirectory: saveOutputToSourceDirectory,
                customFfmpegPath: customFfmpegPath,
                customFfprobePath: customFfprobePath,
                showRawLog: showRawLog,
                showAdvancedOptions: showAdvancedOptions,
                defaultOutputVideoCodec: defaultOutputVideoCodec,
                defaultCompressionSmartPreset: defaultCompressionSmartPreset,
                defaultOutputFileNameTemplate: defaultOutputFileNameTemplate,
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
      Value<String?> outputPath,
      Value<String?> errorMessage,
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
      Value<String?> outputPath,
      Value<String?> errorMessage,
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

  ColumnFilters<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
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

  ColumnOrderings<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
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

  GeneratedColumn<String> get outputPath => $composableBuilder(
    column: $table.outputPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
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
                Value<String?> outputPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
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
                outputPath: outputPath,
                errorMessage: errorMessage,
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
                Value<String?> outputPath = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
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
                outputPath: outputPath,
                errorMessage: errorMessage,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsRowsTableTableManager get settingsRows =>
      $$SettingsRowsTableTableManager(_db, _db.settingsRows);
  $$TaskRowsTableTableManager get taskRows =>
      $$TaskRowsTableTableManager(_db, _db.taskRows);
}
