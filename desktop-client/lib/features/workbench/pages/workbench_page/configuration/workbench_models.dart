import 'package:flutter/foundation.dart';

@immutable
class DroppedImportFailure {
  const DroppedImportFailure({required this.path, required this.reason});

  final String path;
  final String reason;
}

enum TaskContextMenuAction {
  revealInFileManager,
  relinkSource,
  rename,
  showLog,
  moveToFolder,
  delete,
}

@immutable
class QualityOption {
  const QualityOption({
    required this.label,
    required this.crf,
    required this.targetRatio,
  });

  final String label;
  final int crf;
  final double targetRatio;

  bool get isLowestVolume => label == '最低体积';
}
