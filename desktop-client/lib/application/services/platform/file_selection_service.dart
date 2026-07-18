abstract interface class FileSelectionService {
  Future<List<String>> pickImportPaths();

  Future<List<String>> pickMediaFiles();

  Future<List<String>> pickMediaDirectories();

  Future<String?> pickMediaFile();

  Future<String?> pickMediaDirectory();

  Future<String?> pickOutputDirectory();

  Future<String?> pickExecutablePath();

  String get defaultExportPath;
}
