import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/infrastructure/repositories/mappers/media_task_config_json_mapper.dart';

void main() {
  test('engine configuration reference survives config JSON round trip', () {
    final config = MediaTaskConfig.initialVideo().copyWith(
      engineConfiguration: const EngineConfigurationReference(
        analysisId: 'analysis-1',
        analysisRevision: 7,
        candidateId: 'candidate-hevc',
        selectionMode: 'preset',
        selectionJson:
            '{"mode":"preset","selection":{"preset_id":"balanced","candidate_id":"candidate-hevc"}}',
      ),
    );

    final encoded = mediaTaskConfigToJson(config);
    final decoded = mediaTaskConfigFromJson(
      (jsonDecode(jsonEncode(encoded)) as Map).cast<String, dynamic>(),
    );

    expect(encoded['configVersion'], 3);
    expect(decoded.engineConfiguration?.analysisId, 'analysis-1');
    expect(decoded.engineConfiguration?.analysisRevision, 7);
    expect(decoded.engineConfiguration?.candidateId, 'candidate-hevc');
    expect(decoded.engineConfiguration?.selectionMode, 'preset');
    expect(
      decoded.engineConfiguration?.selectionJson,
      '{"mode":"preset","selection":{"preset_id":"balanced","candidate_id":"candidate-hevc"}}',
    );
  });

  test(
    'invalid engine configuration reference is ignored for compatibility',
    () {
      final json = mediaTaskConfigToJson(MediaTaskConfig.initialVideo())
        ..['engineConfiguration'] = <String, Object?>{
          'analysisId': 'analysis-1',
          'analysisRevision': -1,
          'candidateId': 'candidate-hevc',
          'selectionMode': 'preset',
          'selectionJson': '{}',
        };

      final decoded = mediaTaskConfigFromJson(json.cast<String, dynamic>());

      expect(decoded.engineConfiguration, isNull);
      expect(decoded.video, isNotNull);
    },
  );
}
