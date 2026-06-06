/// 需要先通过本地适配器还原为标准音频的专有音频输入格式。
enum ProprietaryAudioFormat {
  ncm(adapterId: 'ncm', displayName: 'NCM', extensions: ['.ncm']),
  qmcMgg(
    adapterId: 'qmc',
    displayName: 'QMC MGG',
    extensions: ['.mgg', '.mgg0', '.mgg1', '.mggl'],
  ),
  qmcMflac(
    adapterId: 'qmc',
    displayName: 'QMC FLAC',
    extensions: ['.mflac', '.mflac0', '.qmcflac'],
  );

  final String adapterId;
  final String displayName;
  final List<String> extensions;

  const ProprietaryAudioFormat({
    required this.adapterId,
    required this.displayName,
    required this.extensions,
  });

  static ProprietaryAudioFormat? fromPath(String inputPath) {
    final lastSeparator = inputPath.lastIndexOf(RegExp(r'[\\/]'));
    final fileName = inputPath.substring(lastSeparator + 1);
    final dotIndex = fileName.lastIndexOf('.');
    final extension = dotIndex == -1
        ? ''
        : fileName.substring(dotIndex).toLowerCase();
    for (final format in values) {
      if (format.extensions.contains(extension)) {
        return format;
      }
    }

    return null;
  }
}
