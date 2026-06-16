import 'package:framelean/domain/enums/app_update_status.dart';
import 'package:framelean/domain/value_objects/app_release_info.dart';

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    this.release,
    this.progress = 0,
    this.downloadedFilePath,
    this.errorMessage,
    this.checkedAt,
  });

  factory AppUpdateState.initial() {
    return const AppUpdateState(status: AppUpdateStatus.idle);
  }

  final AppUpdateStatus status;
  final AppReleaseInfo? release;
  final double progress;
  final String? downloadedFilePath;
  final String? errorMessage;
  final DateTime? checkedAt;

  bool get hasUpdate => release != null;

  bool get isActive =>
      status == AppUpdateStatus.available ||
      status == AppUpdateStatus.downloading ||
      status == AppUpdateStatus.paused ||
      status == AppUpdateStatus.downloaded ||
      status == AppUpdateStatus.installing;

  bool get canCheck => status != AppUpdateStatus.checking;

  bool get canStartDownload =>
      release != null &&
      (status == AppUpdateStatus.available ||
          status == AppUpdateStatus.paused ||
          status == AppUpdateStatus.failed);

  bool get canPause => status == AppUpdateStatus.downloading;

  bool get canInstall =>
      release != null &&
      downloadedFilePath != null &&
      status == AppUpdateStatus.downloaded;

  int get progressPercent => (progress.clamp(0, 1) * 100).round();

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppReleaseInfo? release,
    double? progress,
    String? downloadedFilePath,
    Object? errorMessage = _notProvided,
    DateTime? checkedAt,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: release ?? this.release,
      progress: progress ?? this.progress,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

const Object _notProvided = Object();
