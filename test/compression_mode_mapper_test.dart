import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/infrastructure/repositories/mappers/compression_mode_mapper.dart';

void main() {
  group('CompressionModeMapper', () {
    test('maps legacy storage values to the current preset mode', () {
      expect(
        CompressionModeMapper.fromStorage('smart'),
        CompressionMode.preset,
      );
      expect(
        CompressionModeMapper.fromStorage('quality'),
        CompressionMode.preset,
      );
    });

    test('writes only current storage values', () {
      expect(CompressionModeMapper.toStorage(CompressionMode.preset), 'preset');
      expect(
        CompressionModeMapper.toStorage(CompressionMode.targetSize),
        'targetSize',
      );
    });
  });
}
