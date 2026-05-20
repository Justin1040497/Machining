/// 应用级默认导出文件名模板。
enum DefaultOutputFileNameTemplate {
  datetimeOriginalCodec;

  String get label {
    switch (this) {
      case DefaultOutputFileNameTemplate.datetimeOriginalCodec:
        return '日期时间_原文件名_编码名称';
    }
  }
}
