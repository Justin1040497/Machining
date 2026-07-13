import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/execution/output_failure.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('mapWindowsOsErrorCode', () {
    const expectations = <int, TaskFailureCode>{
      2: TaskFailureCode.invalidOutputPath,
      3: TaskFailureCode.invalidOutputPath,
      5: TaskFailureCode.outputDirectoryNotWritable,
      32: TaskFailureCode.outputFileInUse,
      80: TaskFailureCode.outputFileInUse,
      112: TaskFailureCode.insufficientDiskSpace,
      123: TaskFailureCode.invalidOutputPath,
      183: TaskFailureCode.outputFileInUse,
      206: TaskFailureCode.invalidOutputPath,
      999: TaskFailureCode.unknown,
    };

    for (final entry in expectations.entries) {
      test('maps ${entry.key} to ${entry.value.name}', () {
        expect(mapWindowsOsErrorCode(entry.key), entry.value);
      });
    }
  });

  group('failure text classification', () {
    test('recognizes permission and security software failures', () {
      expect(isPermissionDeniedText('PERMISSION DENIED'), isTrue);
      expect(
        isSecuritySoftwareBlockText('Permission denied: ffmpeg.exe'),
        isTrue,
      );
      expect(
        isSecuritySoftwareBlockText('Permission denied: output directory'),
        isFalse,
      );
    });

    test('maps hardware stderr without exposing it as user message', () {
      final failure = taskFailureFromError(
        stage: TaskFailureStage.processing,
        technicalSummary:
            'h264_videotoolbox: Generic error in an external library',
        occurredAt: 42,
      );

      expect(failure.code, TaskFailureCode.hardwareSessionLost);
      expect(failure.userMessage, isNot(contains('videotoolbox')));
      expect(failure.technicalSummary, contains('videotoolbox'));
      expect(failure.recoveryAction, TaskRecoveryAction.retryExecution);
    });

    test('maps output publication failure to output recovery', () {
      final failure = taskFailureFromError(
        stage: TaskFailureStage.outputPublication,
        technicalSummary: '输出文件发布失败: access denied',
        occurredAt: 42,
      );

      expect(failure.code, TaskFailureCode.outputPublishFailed);
      expect(failure.recoveryAction, TaskRecoveryAction.chooseOutputDirectory);
    });

    test('ineffective compression is not retryable', () {
      final failure = taskFailureFromError(
        stage: TaskFailureStage.outputValidation,
        technicalSummary: '输出文件大小不小于源文件',
        occurredAt: 42,
        mediaKind: MediaKind.image,
      );

      expect(failure.code, TaskFailureCode.ineffectiveCompression);
      expect(failure.retryable, isFalse);
      expect(failure.recoveryAction, TaskRecoveryAction.editConfiguration);
    });
  });
}
