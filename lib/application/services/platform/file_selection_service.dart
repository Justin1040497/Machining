abstract interface class FileSelectionService {
  Future<List<String>> pickMediaFiles();

  Future<String?> pickMediaFile();

  Future<String?> pickOutputDirectory();

  Future<String?> pickExecutablePath();

  String get defaultExportPath;
}
