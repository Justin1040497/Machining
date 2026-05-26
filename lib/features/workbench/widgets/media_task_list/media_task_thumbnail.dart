import 'package:flutter/material.dart';

class MediaTaskThumbnail extends StatelessWidget {
  const MediaTaskThumbnail({super.key, this.thumbnail});

  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFFE7EEF5),
        image: thumbnail == null
            ? null
            : DecorationImage(image: thumbnail!, fit: BoxFit.cover),
      ),
      child: thumbnail == null
          ? const Icon(
              Icons.movie_creation_outlined,
              size: 18,
              color: Color(0xFF7D8B95),
            )
          : null,
    );
  }
}
