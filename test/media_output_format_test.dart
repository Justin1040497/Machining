import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';

void main() {
  group('MediaOutputFormat', () {
    test('returns only video output formats for video tasks', () {
      expect(MediaOutputFormat.formatsFor(MediaKind.video), [
        MediaOutputFormat.mp4,
        MediaOutputFormat.mov,
        MediaOutputFormat.mkv,
      ]);
    });

    test('returns only image output formats for image tasks', () {
      expect(MediaOutputFormat.formatsFor(MediaKind.image), [
        MediaOutputFormat.jpg,
        MediaOutputFormat.png,
        MediaOutputFormat.webp,
        MediaOutputFormat.bmp,
        MediaOutputFormat.tiff,
        MediaOutputFormat.gif,
      ]);
    });

    test('returns only audio output formats for audio tasks', () {
      expect(MediaOutputFormat.formatsFor(MediaKind.audio), [
        MediaOutputFormat.mp3,
        MediaOutputFormat.m4a,
        MediaOutputFormat.aac,
        MediaOutputFormat.wav,
        MediaOutputFormat.flac,
        MediaOutputFormat.aiff,
        MediaOutputFormat.wma,
        MediaOutputFormat.opus,
        MediaOutputFormat.oggOpus,
      ]);
    });
  });
}
