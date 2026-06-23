import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/database/persistence_compatibility.dart';

/// Maps persisted compression-mode strings to the current domain vocabulary.
abstract final class CompressionModeMapper {
  static CompressionMode fromStorage(String value) {
    switch (value) {
      case PersistenceCompatibility.compressionModePreset:
      case PersistenceCompatibility.legacyCompressionModeSmart:
      case PersistenceCompatibility.legacyCompressionModeQuality:
        return CompressionMode.preset;
      case PersistenceCompatibility.compressionModeTargetSize:
        return CompressionMode.targetSize;
      default:
        throw StateError('未知的压缩模式: $value');
    }
  }

  static String toStorage(CompressionMode value) {
    return switch (value) {
      CompressionMode.preset => PersistenceCompatibility.compressionModePreset,
      CompressionMode.targetSize =>
        PersistenceCompatibility.compressionModeTargetSize,
    };
  }
}
