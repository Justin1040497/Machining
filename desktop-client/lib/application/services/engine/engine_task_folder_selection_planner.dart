import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/services/engine/engine_configuration_editor_model.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';

final class EngineTaskFolderSelectionException implements Exception {
  const EngineTaskFolderSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Translates one folder-level choice into a snapshot-bound selection per task.
///
/// Preset IDs are stable product choices, while candidate IDs belong to each
/// analysis snapshot. Manual and target-size selections are accepted only when
/// the exact candidate and parameters are valid for every snapshot.
final class EngineTaskFolderSelectionPlanner {
  EngineTaskFolderSelectionPlanner(
    Map<String, EngineAnalysisSnapshotDocument> snapshots,
  ) : snapshots = Map.unmodifiable(snapshots) {
    if (snapshots.isEmpty || snapshots.keys.any((taskId) => taskId.isEmpty)) {
      throw const EngineTaskFolderSelectionException('任务夹没有可配置的分析结果。');
    }
  }

  final Map<String, EngineAnalysisSnapshotDocument> snapshots;

  EngineTaskFolderConfigurationAvailability get availability {
    final models = snapshots.values
        .map((snapshot) => EngineConfigurationEditorModel(snapshot: snapshot))
        .toList(growable: false);
    final commonPresetIds = _intersect(
      models.map(
        (model) => model.availablePresets.map((preset) => preset.id).toSet(),
      ),
    );
    final commonCandidateIds = _intersect(
      models.map((model) => model.candidateIds.toSet()),
    );
    return EngineTaskFolderConfigurationAvailability(
      presetIds: commonPresetIds,
      candidateIds: commonCandidateIds,
    );
  }

  Map<String, EngineConfigurationSelection> resolve(
    EngineConfigurationSelection selection,
  ) {
    final currentAvailability = availability;
    final supported = switch (selection) {
      EnginePresetSelection() => currentAvailability.presetIds.contains(
        selection.presetId,
      ),
      EngineManualConfigurationSelection() =>
        currentAvailability.candidateIds.contains(selection.candidateId),
      EngineTargetSizeSelection() => currentAvailability.candidateIds.contains(
        selection.candidateId,
      ),
    };
    if (!supported) {
      throw const EngineTaskFolderSelectionException('所选配置不属于任务夹全部成员的共同可用项。');
    }
    final resolved = <String, EngineConfigurationSelection>{};
    for (final entry in snapshots.entries) {
      final taskSelection = _resolveForSnapshot(entry.value, selection);
      if (taskSelection == null) {
        throw EngineTaskFolderSelectionException(
          '所选配置不适用于任务夹中的全部任务，请选择共同可用的预设或参数。',
        );
      }
      resolved[entry.key] = taskSelection;
    }
    return Map.unmodifiable(resolved);
  }

  EngineConfigurationSelection? _resolveForSnapshot(
    EngineAnalysisSnapshotDocument snapshot,
    EngineConfigurationSelection selection,
  ) {
    final model = EngineConfigurationEditorModel(snapshot: snapshot);
    return switch (selection) {
      EnginePresetSelection() =>
        model
            .selectPreset(selection.presetId, overrides: selection.overrides)
            .selection,
      EngineManualConfigurationSelection() =>
        model
            .selectManual(
              candidateId: selection.candidateId,
              overrides: selection.overrides,
            )
            .selection,
      EngineTargetSizeSelection() =>
        model
            .selectTargetSize(
              candidateId: selection.candidateId,
              targetBytes: selection.targetBytes,
              allowResolutionChange: selection.allowResolutionChange,
              allowFrameRateChange: selection.allowFrameRateChange,
            )
            .selection,
    };
  }
}

final class EngineTaskFolderConfigurationAvailability {
  EngineTaskFolderConfigurationAvailability({
    required Set<String> presetIds,
    required Set<String> candidateIds,
  }) : presetIds = Set.unmodifiable(presetIds),
       candidateIds = Set.unmodifiable(candidateIds);

  final Set<String> presetIds;
  final Set<String> candidateIds;

  bool get isEmpty => presetIds.isEmpty && candidateIds.isEmpty;
}

Set<String> _intersect(Iterable<Set<String>> values) {
  final iterator = values.iterator;
  if (!iterator.moveNext()) {
    return const <String>{};
  }
  final common = {...iterator.current};
  while (iterator.moveNext()) {
    common.removeWhere((value) => !iterator.current.contains(value));
  }
  return common;
}
