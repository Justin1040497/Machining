class AppReleaseNotes {
  const AppReleaseNotes({
    required this.version,
    required this.buildNumber,
    required this.channel,
    required this.publishedAt,
    required this.markdown,
    required this.summary,
  });

  final String version;
  final int buildNumber;
  final String channel;
  final DateTime? publishedAt;
  final String markdown;
  final String summary;
}
