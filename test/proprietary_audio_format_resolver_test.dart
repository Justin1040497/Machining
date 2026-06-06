import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/infrastructure/services/input_runtime/file_extension_proprietary_audio_format_resolver.dart';

void main() {
  group('FileExtensionProprietaryAudioFormatResolver', () {
    test('resolves ncm and qmc audio variants by extension', () {
      const resolver = FileExtensionProprietaryAudioFormatResolver();

      expect(resolver.resolve('/music/song.NCM'), ProprietaryAudioFormat.ncm);
      expect(
        resolver.resolve('/music/song.mgg'),
        ProprietaryAudioFormat.qmcMgg,
      );
      expect(
        resolver.resolve('/music/song.MGG1'),
        ProprietaryAudioFormat.qmcMgg,
      );
      expect(
        resolver.resolve('/music/song.mflac'),
        ProprietaryAudioFormat.qmcMflac,
      );
      expect(
        resolver.resolve('/music/song.qmcflac'),
        ProprietaryAudioFormat.qmcMflac,
      );
    });

    test('returns null for ordinary audio', () {
      const resolver = FileExtensionProprietaryAudioFormatResolver();

      expect(resolver.resolve('/music/song.mp3'), isNull);
    });
  });
}
