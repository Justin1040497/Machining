enum AppSettingsSaveTarget {
  application('应用设置'),
  videoTask('视频任务设置'),
  imageTask('图片任务设置'),
  audioTask('音频任务设置'),
  output('输出配置'),
  encoder('编码器配置');

  const AppSettingsSaveTarget(this.notificationSubject);

  final String notificationSubject;

  String get successTitle => '$notificationSubject已保存';

  String get failureTitle => '$notificationSubject保存失败';
}
