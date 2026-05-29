import 'dart:io';

class WorkbenchExternalLinkOpenResult {
  const WorkbenchExternalLinkOpenResult._({required this.message});

  const WorkbenchExternalLinkOpenResult.success() : this._(message: null);

  const WorkbenchExternalLinkOpenResult.failure(String message)
    : this._(message: message);

  final String? message;

  bool get succeeded => message == null;
}

class WorkbenchExternalLinkCommand {
  const WorkbenchExternalLinkCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

abstract final class WorkbenchExternalLinkOpener {
  static Future<WorkbenchExternalLinkOpenResult> open(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return const WorkbenchExternalLinkOpenResult.failure('链接地址为空');
    }

    try {
      final command = buildOpenCommand(trimmedUrl);
      if (command == null) {
        return const WorkbenchExternalLinkOpenResult.failure('当前系统暂不支持打开链接');
      }

      await Process.start(
        command.executable,
        command.arguments,
        mode: ProcessStartMode.detached,
      );
    } on Object catch (error) {
      return WorkbenchExternalLinkOpenResult.failure('打开链接失败: $error');
    }

    return const WorkbenchExternalLinkOpenResult.success();
  }

  static WorkbenchExternalLinkCommand? buildOpenCommand(
    String url, {
    String? operatingSystem,
  }) {
    final currentOperatingSystem = operatingSystem ?? Platform.operatingSystem;

    if (currentOperatingSystem == 'macos') {
      return WorkbenchExternalLinkCommand(executable: 'open', arguments: [url]);
    }

    if (currentOperatingSystem == 'windows') {
      return WorkbenchExternalLinkCommand(
        executable: 'rundll32',
        arguments: ['url.dll,FileProtocolHandler', url],
      );
    }

    if (currentOperatingSystem == 'linux') {
      return WorkbenchExternalLinkCommand(
        executable: 'xdg-open',
        arguments: [url],
      );
    }

    return null;
  }
}
