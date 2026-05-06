/// 任务处理类型
enum TaskPurpose {
  compression,
  conversion;

  String get label {
    switch (this) {
      case TaskPurpose.compression:
        return "文件压缩";
      case TaskPurpose.conversion:
        return "格式转换";
    }
  }
}
