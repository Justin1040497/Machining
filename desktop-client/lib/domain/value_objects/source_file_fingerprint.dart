/// 源文件快速指纹
class SourceFileFingerprint {
  /// 文件大小，单位是字节
  final int fileSize;

  /// 文件最后修改时间
  final int lastModifiedAt;

  const SourceFileFingerprint({
    required this.fileSize,
    required this.lastModifiedAt,
  });

  bool isSameAs(SourceFileFingerprint? other) {
    if (other == null) {
      return false;
    }

    return fileSize == other.fileSize && lastModifiedAt == other.lastModifiedAt;
  }
}
