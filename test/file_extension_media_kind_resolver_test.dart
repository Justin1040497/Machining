import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';

void main() {
  group('FileExtensionMediaKindResolver', () {
    test('resolves uppercase MOV extension as video', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/videos/clip.MOV'), MediaKind.video);
    });
  });
}
