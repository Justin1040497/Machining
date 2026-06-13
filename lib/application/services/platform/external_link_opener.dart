class ExternalLinkOpenResult {
  const ExternalLinkOpenResult._({required this.message});

  const ExternalLinkOpenResult.success() : this._(message: null);

  const ExternalLinkOpenResult.failure(String message)
    : this._(message: message);

  final String? message;

  bool get succeeded => message == null;
}

abstract interface class ExternalLinkOpener {
  Future<ExternalLinkOpenResult> open(String url);
}
