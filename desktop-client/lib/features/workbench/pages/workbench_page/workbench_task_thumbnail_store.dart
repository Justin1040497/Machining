import 'dart:io';

import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';

class WorkbenchTaskThumbnailStore {
  ImageProvider? imageForTask(MediaTask task) {
    if (task.mediaKind == MediaKind.image &&
        File(task.inputPath).existsSync()) {
      return FileImage(File(task.inputPath));
    }
    // Video thumbnails belong to FLL media services after the migration.
    // Returning null deliberately renders the standard media placeholder.
    return null;
  }
}
