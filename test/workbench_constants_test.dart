import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/services/platform/desktop_file_selection_service.dart';

void main() {
  group('DesktopFileSelectionService', () {
    test('audio picker accepts proprietary audio input extensions', () {
      expect(
        DesktopFileSelectionService.audioTypeGroup.extensions,
        containsAll(['ncm', 'mgg', 'mflac', 'qmcflac']),
      );
    });
  });
}
