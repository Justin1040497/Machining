import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_external_link_opener.dart';

void main() {
  group('WorkbenchExternalLinkOpener', () {
    test('builds macOS open command', () {
      final command = WorkbenchExternalLinkOpener.buildOpenCommand(
        'https://github.com/zhouycheng/FrameLean',
        operatingSystem: 'macos',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'open');
      expect(command.arguments, ['https://github.com/zhouycheng/FrameLean']);
    });

    test('builds Windows URL command', () {
      final command = WorkbenchExternalLinkOpener.buildOpenCommand(
        'https://github.com/zhouycheng/FrameLean',
        operatingSystem: 'windows',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'rundll32');
      expect(command.arguments, [
        'url.dll,FileProtocolHandler',
        'https://github.com/zhouycheng/FrameLean',
      ]);
    });

    test('builds Linux xdg-open command', () {
      final command = WorkbenchExternalLinkOpener.buildOpenCommand(
        'https://github.com/zhouycheng/FrameLean',
        operatingSystem: 'linux',
      );

      expect(command, isNotNull);
      expect(command!.executable, 'xdg-open');
      expect(command.arguments, ['https://github.com/zhouycheng/FrameLean']);
    });
  });
}
