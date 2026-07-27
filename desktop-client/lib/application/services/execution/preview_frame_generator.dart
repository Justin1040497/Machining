class PreviewFrameArtifact {
  final int index;
  final double ratio;
  final double timestampSeconds;
  final String framePath;

  const PreviewFrameArtifact({
    required this.index,
    required this.ratio,
    required this.timestampSeconds,
    required this.framePath,
  });
}

class PreviewFrameResult {
  final String taskId;
  final String directoryPath;
  final List<PreviewFrameArtifact> frames;

  const PreviewFrameResult({
    required this.taskId,
    required this.directoryPath,
    required this.frames,
  });
}
