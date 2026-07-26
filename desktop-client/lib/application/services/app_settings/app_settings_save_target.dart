enum AppSettingsSaveTarget {
  application('应用设置', successMessage: '已即时生效'),
  notifications('通知设置', successMessage: '已即时生效'),
  shortcuts('快捷键设置', successMessage: '已即时生效'),
  videoTask('视频任务配置', successMessage: '在下次导入任务时应用'),
  imageTask('图片任务配置', successMessage: '在下次导入任务时应用'),
  audioTask('音频任务配置', successMessage: '在下次导入任务时应用'),
  output('输出配置', successMessage: '非运行状态的任务已更新；正在处理的任务将在下次处理时使用新配置');

  const AppSettingsSaveTarget(
    this.notificationSubject, {
    this.successMessage = '',
  });

  final String notificationSubject;
  final String successMessage;

  String get successTitle => '$notificationSubject已保存';

  String get failureTitle => '$notificationSubject保存失败';

  bool get refreshesExistingTasks => this == AppSettingsSaveTarget.output;
}
