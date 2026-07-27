import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/task_folder_compatibility_class.dart';
import 'package:framelean/domain/enums/task_folder_origin.dart';
import 'package:uuid/uuid.dart';

class TaskFolder {
  final String id;
  final String name;
  final MediaKind mediaKind;
  final TaskFolderOrigin origin;
  final TaskFolderCompatibilityClass? compatibilityClass;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;

  static String generateId() => const Uuid().v4();

  TaskFolder({
    required this.id,
    required this.name,
    required this.mediaKind,
    this.origin = TaskFolderOrigin.manual,
    this.compatibilityClass,
    required this.sortOrder,
    int? createdAt,
    int? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory TaskFolder.create({
    required String name,
    required MediaKind mediaKind,
    TaskFolderOrigin origin = TaskFolderOrigin.manual,
    TaskFolderCompatibilityClass? compatibilityClass,
    required int sortOrder,
  }) {
    return TaskFolder(
      id: generateId(),
      name: name,
      mediaKind: mediaKind,
      origin: origin,
      compatibilityClass: compatibilityClass,
      sortOrder: sortOrder,
    );
  }

  TaskFolder copyWith({
    String? id,
    String? name,
    MediaKind? mediaKind,
    TaskFolderOrigin? origin,
    TaskFolderCompatibilityClass? compatibilityClass,
    bool clearCompatibilityClass = false,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) {
    final resolvedKind = mediaKind ?? this.mediaKind;
    return TaskFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      mediaKind: resolvedKind,
      origin: origin ?? this.origin,
      compatibilityClass: clearCompatibilityClass
          ? null
          : compatibilityClass ?? this.compatibilityClass,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
