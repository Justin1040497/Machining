/// 专有音频适配器把输入文件还原为标准音频后的结果。
class ProprietaryAudioDecodeResult {
  final String decodedPath;
  final String decodedExtension;
  final String adapterName;
  final String adapterVersion;
  final bool temporary;
  final List<String> cleanupPaths;

  const ProprietaryAudioDecodeResult({
    required this.decodedPath,
    required this.decodedExtension,
    required this.adapterName,
    required this.adapterVersion,
    this.temporary = true,
    this.cleanupPaths = const [],
  });
}
