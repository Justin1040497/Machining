import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';

void main() {
  group('WorkbenchConstants', () {
    test('audio picker accepts proprietary audio input extensions', () {
      expect(
        WorkbenchConstants.audioTypeGroup.extensions,
        containsAll(['ncm', 'mgg', 'mflac', 'qmcflac']),
      );
    });
  });
}
