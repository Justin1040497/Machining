import 'package:flutter/material.dart';
import 'package:framelean/domain/enums/media_kind.dart';

extension WorkbenchMediaKindIcon on MediaKind {
  IconData get placeholderIcon {
    return switch (this) {
      MediaKind.video => Icons.movie_creation_outlined,
      MediaKind.image => Icons.image_outlined,
      MediaKind.audio => Icons.audiotrack_rounded,
    };
  }
}
