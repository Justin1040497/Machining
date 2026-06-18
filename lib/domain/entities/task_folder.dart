import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:uuid/uuid.dart';

class TaskFolder {
  final String id;
  final String name;
  final MediaKind mediaKind;
  final int sortOrder;
  final MediaTaskConfig defaultConfig;
  final int createdAt;
  final int updatedAt;

  static String generateId() => const Uuid().v4();

  TaskFolder({
    required this.id,
    required this.name,
    required this.mediaKind,
    required this.sortOrder,
    required Object defaultConfig,
    int? createdAt,
    int? updatedAt,
  }) : defaultConfig = MediaTaskConfig.normalize(defaultConfig, mediaKind),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch {
    if (!this.defaultConfig.isValidFor(mediaKind)) {
      throw StateError('任务夹默认配置与媒体类型不匹配: ${mediaKind.name}');
    }
  }

  factory TaskFolder.create({
    required String name,
    required MediaKind mediaKind,
    required int sortOrder,
    required Object defaultConfig,
  }) {
    return TaskFolder(
      id: generateId(),
      name: name,
      mediaKind: mediaKind,
      sortOrder: sortOrder,
      defaultConfig: defaultConfig,
    );
  }

  TaskFolder copyWith({
    String? id,
    String? name,
    MediaKind? mediaKind,
    int? sortOrder,
    Object? defaultConfig,
    int? createdAt,
    int? updatedAt,
  }) {
    final resolvedKind = mediaKind ?? this.mediaKind;
    return TaskFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      mediaKind: resolvedKind,
      sortOrder: sortOrder ?? this.sortOrder,
      defaultConfig: defaultConfig ?? this.defaultConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
