class AppUpdatePackageInfo {
  const AppUpdatePackageInfo({
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    this.ed25519Signature,
  });

  final String fileName;
  final int sizeBytes;
  final String sha256;
  final String? ed25519Signature;

  bool get hasDownloadMetadata =>
      fileName.trim().isNotEmpty && sizeBytes > 0 && sha256.trim().isNotEmpty;
}
