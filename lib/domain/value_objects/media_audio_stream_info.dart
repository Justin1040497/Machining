class MediaAudioStreamInfo {
  const MediaAudioStreamInfo({
    required this.index,
    this.codec,
    this.channels,
    this.sampleRate,
    this.channelLayout,
    this.language,
    this.title,
  });

  final int index;
  final String? codec;
  final int? channels;
  final int? sampleRate;
  final String? channelLayout;
  final String? language;
  final String? title;

  String get displayLabel {
    final parts = <String>['音轨 $index'];
    if (language != null && language!.trim().isNotEmpty) {
      parts.add(language!.trim());
    }
    if (title != null && title!.trim().isNotEmpty) {
      parts.add(title!.trim());
    }
    if (codec != null && codec!.trim().isNotEmpty) {
      parts.add(codec!.trim().toUpperCase());
    }
    if (channels != null && channels! > 0) {
      parts.add('${channels!} 声道');
    }
    return parts.join(' · ');
  }
}
