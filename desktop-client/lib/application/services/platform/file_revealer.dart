class FileRevealResult {
  const FileRevealResult._({required this.message});

  const FileRevealResult.success() : this._(message: null);

  const FileRevealResult.failure(String message) : this._(message: message);

  final String? message;

  bool get succeeded => message == null;
}

abstract interface class FileRevealer {
  Future<FileRevealResult> revealPath(String targetPath);
}
