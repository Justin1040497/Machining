import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/execution/output_failure.dart';

void main() {
  group('mapWindowsOsErrorCode', () {
    test('maps error code 5 to outputDirectoryNotWritable', () {
      expect(
        mapWindowsOsErrorCode(5),
        OutputErrorCode.outputDirectoryNotWritable,
      );
    });

    test('maps error code 32 to outputFileInUse', () {
      expect(
        mapWindowsOsErrorCode(32),
        OutputErrorCode.outputFileInUse,
      );
    });

    test('maps error code 112 to insufficientDiskSpace', () {
      expect(
        mapWindowsOsErrorCode(112),
        OutputErrorCode.insufficientDiskSpace,
      );
    });

    test('maps error code 123 to invalidOutputPath', () {
      expect(
        mapWindowsOsErrorCode(123),
        OutputErrorCode.invalidOutputPath,
      );
    });

    test('maps error code 2 to invalidOutputPath', () {
      expect(
        mapWindowsOsErrorCode(2),
        OutputErrorCode.invalidOutputPath,
      );
    });

    test('maps error code 3 to invalidOutputPath', () {
      expect(
        mapWindowsOsErrorCode(3),
        OutputErrorCode.invalidOutputPath,
      );
    });

    test('maps error code 80 to outputFileAlreadyExists', () {
      expect(
        mapWindowsOsErrorCode(80),
        OutputErrorCode.outputFileAlreadyExists,
      );
    });

    test('maps error code 183 to outputFileAlreadyExists', () {
      expect(
        mapWindowsOsErrorCode(183),
        OutputErrorCode.outputFileAlreadyExists,
      );
    });

    test('maps error code 206 to invalidOutputPath', () {
      expect(
        mapWindowsOsErrorCode(206),
        OutputErrorCode.invalidOutputPath,
      );
    });

    test('maps unknown error code to unknownFileSystemError', () {
      expect(
        mapWindowsOsErrorCode(999),
        OutputErrorCode.unknownFileSystemError,
      );
    });
  });

  group('isPermissionDeniedText', () {
    test('matches "Permission denied" (English)', () {
      expect(isPermissionDeniedText('Permission denied'), isTrue);
    });

    test('matches "Access is denied" (English)', () {
      expect(isPermissionDeniedText('Access is denied'), isTrue);
    });

    test('matches "Operation not permitted" (English)', () {
      expect(isPermissionDeniedText('Operation not permitted'), isTrue);
    });

    test('matches "无法访问" (Chinese)', () {
      expect(isPermissionDeniedText('无法访问'), isTrue);
    });

    test('matches "拒绝访问" (Chinese)', () {
      expect(isPermissionDeniedText('拒绝访问'), isTrue);
    });

    test('does not match unrelated text', () {
      expect(isPermissionDeniedText('File not found'), isFalse);
    });

    test('case-insensitive match for English', () {
      expect(isPermissionDeniedText('PERMISSION DENIED'), isTrue);
    });
  });

  group('isSecuritySoftwareBlockText', () {
    test(
        'matches permission denied mentioning ffmpeg (security software block)',
        () {
      expect(
        isSecuritySoftwareBlockText('Permission denied: ffmpeg.exe'),
        isTrue,
      );
    });

    test(
        'matches permission denied mentioning ffmpeg in message',
        () {
      expect(
        isSecuritySoftwareBlockText(
            'ffmpeg error: Error opening output: Permission denied'),
        isTrue,
      );
    });

    test('does not match permission denied without ffmpeg reference', () {
      expect(
        isSecuritySoftwareBlockText(
            'Permission denied: output directory (check permissions)'),
        isFalse,
      );
    });

    test('does not match unrelated text', () {
      expect(isSecuritySoftwareBlockText('Unknown error'), isFalse);
    });
  });

  group('OutputFailure', () {
    test('toString returns technicalMessage', () {
      const failure = OutputFailure(
        code: OutputErrorCode.outputDirectoryNotWritable,
        stage: OutputFailureStage.createProbeFile,
        userMessage: '目录不可写',
        technicalMessage: 'Permission denied: /tmp/test',
        path: '/tmp/test',
        osErrorCode: 5,
      );
      expect(failure.toString(), 'Permission denied: /tmp/test');
    });
  });
}
