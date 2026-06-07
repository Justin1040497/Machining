import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/theme/workbench_theme_context.dart';

class MediaTaskThumbnail extends StatelessWidget {
  const MediaTaskThumbnail({super.key, this.thumbnail});

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
          ? Icon(
              Icons.movie_creation_outlined,
              size: 18,
              color: colors.iconMuted,
            )
          : null,
    );
  }
}
