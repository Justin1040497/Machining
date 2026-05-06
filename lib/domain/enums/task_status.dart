/// 任务状态
enum TaskStatus {
  pending,
  analyzing,
  running,
  paused,
  completed,
  failed,
  cancelled,
  missingSource;

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return "等待中";
      case TaskStatus.analyzing:
        return "分析中";
      case TaskStatus.running:
        return "处理中";
      case TaskStatus.paused:
        return "已暂停";
      case TaskStatus.completed:
        return "已完成";
      case TaskStatus.failed:
        return "失败";
      case TaskStatus.cancelled:
        return "已取消";
      case TaskStatus.missingSource:
        return "源文件丢失";
    }
  }
}
