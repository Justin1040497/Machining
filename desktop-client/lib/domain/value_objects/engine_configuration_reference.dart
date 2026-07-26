/// A persisted reference to a user-selected engine configuration.
///
/// The selection payload is intentionally opaque to the domain layer. FLL
/// owns its schema and resolves it against the immutable analysis snapshot.
class EngineConfigurationReference {
  const EngineConfigurationReference({
    required this.analysisId,
    required this.analysisRevision,
    required this.candidateId,
    required this.selectionMode,
    required this.selectionJson,
  }) : assert(analysisId != ''),
       assert(analysisRevision >= 0),
       assert(candidateId != ''),
       assert(selectionMode != ''),
       assert(selectionJson != '');

  final String analysisId;
  final int analysisRevision;
  final String candidateId;
  final String selectionMode;
  final String selectionJson;
}
