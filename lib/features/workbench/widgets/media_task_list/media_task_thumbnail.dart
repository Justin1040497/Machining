import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class MediaTaskThumbnail extends StatelessWidget {
  const MediaTaskThumbnail({
    super.key,
    required this.mediaKind,
    this.thumbnail,
  });

  final MediaKind mediaKind;
  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: colors.primarySoft,
        image: thumbnail == null
            ? null
            : DecorationImage(image: thumbnail!, fit: BoxFit.cover),
      ),
      child: thumbnail == null
          ? Icon(mediaKind.placeholderIcon, size: 18, color: colors.iconMuted)
          : null,
    );
  }
}
