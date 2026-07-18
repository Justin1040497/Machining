import 'dart:io';

import 'package:framelean/application/library.dart';

class ExternalLinkCommand {
  const ExternalLinkCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

class LocalExternalLinkOpener implements ExternalLinkOpener {
  const LocalExternalLinkOpener();

  @override
  Future<ExternalLinkOpenResult> open(String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return const ExternalLinkOpenResult.failure('链接地址为空');
    }

    try {
      final command = buildOpenCommand(trimmedUrl);
      if (command == null) {
        return const ExternalLinkOpenResult.failure('当前系统暂不支持打开链接');
      }

      await Process.start(
        command.executable,
        command.arguments,
        mode: ProcessStartMode.detached,
      );
    } on Object catch (error) {
      return ExternalLinkOpenResult.failure('打开链接失败: $error');
    }

    return const ExternalLinkOpenResult.success();
  }

  static ExternalLinkCommand? buildOpenCommand(
    String url, {
    String? operatingSystem,
  }) {
    final currentOperatingSystem = operatingSystem ?? Platform.operatingSystem;

    if (currentOperatingSystem == 'macos') {
      return ExternalLinkCommand(executable: 'open', arguments: [url]);
    }

    if (currentOperatingSystem == 'windows') {
      return ExternalLinkCommand(
        executable: 'rundll32',
        arguments: ['url.dll,FileProtocolHandler', url],
      );
    }

    if (currentOperatingSystem == 'linux') {
      return ExternalLinkCommand(executable: 'xdg-open', arguments: [url]);
    }

    return null;
  }
}
