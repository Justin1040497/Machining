import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';

void main() {
  group('FileExtensionMediaKindResolver', () {
    test('resolves uppercase MOV extension as video', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/videos/clip.MOV'), MediaKind.video);
    });

    test('resolves uppercase image and audio extensions', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/images/photo.WEBP'), MediaKind.image);
      expect(resolver.resolve('/audio/voice.MP3'), MediaKind.audio);
    });

    test('resolves proprietary audio extensions as audio inputs', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/audio/song.NCM'), MediaKind.audio);
      expect(resolver.resolve('/audio/song.mgg'), MediaKind.audio);
      expect(resolver.resolve('/audio/song.mflac'), MediaKind.audio);
      expect(resolver.resolve('/audio/song.qmcflac'), MediaKind.audio);
    });
  });
}
