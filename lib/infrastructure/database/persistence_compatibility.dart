/// Centralizes persisted values that are kept only for backward compatibility.
///
/// Domain and application code should use current enum names. Legacy strings
/// stay here so old SQLite rows do not leak into business logic.
abstract final class PersistenceCompatibility {
  static const compressionModePreset = 'preset';
  static const compressionModeTargetSize = 'targetSize';

  static const legacyCompressionModeSmart = 'smart';
  static const legacyCompressionModeQuality = 'quality';
}
