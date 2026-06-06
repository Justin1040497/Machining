import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_media_kind_resolver.dart';

void main() {
  group('FileExtensionMediaKindResolver', () {
    test('resolves uppercase MOV extension as video', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/videos/clip.MOV'), MediaKind.video);
      expect(resolver.resolve('/videos/clip.flv'), MediaKind.video);
      expect(resolver.resolve('/videos/clip.wmv'), MediaKind.video);
      expect(resolver.resolve('/videos/clip.m2ts'), MediaKind.video);
      expect(resolver.resolve('/videos/clip.3gp'), MediaKind.video);
      expect(resolver.resolve('/videos/clip.vob'), MediaKind.video);
    });

    test('resolves uppercase image and audio extensions', () {
      final resolver = FileExtensionMediaKindResolver();

      expect(resolver.resolve('/images/photo.WEBP'), MediaKind.image);
      expect(resolver.resolve('/images/photo.TIFF'), MediaKind.image);
      expect(resolver.resolve('/images/photo.heic'), MediaKind.image);
      expect(resolver.resolve('/images/photo.avif'), MediaKind.image);
      expect(resolver.resolve('/audio/voice.MP3'), MediaKind.audio);
      expect(resolver.resolve('/audio/voice.aiff'), MediaKind.audio);
      expect(resolver.resolve('/audio/voice.wma'), MediaKind.audio);
      expect(resolver.resolve('/audio/voice.opus'), MediaKind.audio);
      expect(resolver.resolve('/audio/voice.caf'), MediaKind.audio);
    });

    test(
      'resolves proprietary audio inputs as audio without ordinary mixing',
      () {
        final resolver = FileExtensionMediaKindResolver();

        expect(
          FileExtensionMediaKindResolver.audioExtensions,
          isNot(contains('.ncm')),
        );
        expect(resolver.resolve('/audio/song.NCM'), MediaKind.audio);
        expect(resolver.resolve('/audio/song.mgg'), MediaKind.audio);
        expect(resolver.resolve('/audio/song.mflac'), MediaKind.audio);
        expect(resolver.resolve('/audio/song.qmcflac'), MediaKind.audio);
      },
    );
  });
}
