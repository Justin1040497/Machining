import 'dart:convert';

import 'package:framelean/domain/library.dart';

const int taskFailureJsonVersion = 1;

String? encodeTaskFailure(TaskFailure? failure) {
  if (failure == null) {
    return null;
  }
  return jsonEncode({
    'version': taskFailureJsonVersion,
    'stage': failure.stage.name,
    'code': failure.code.name,
    'userMessage': failure.userMessage,
    'technicalSummary': failure.technicalSummary,
    'occurredAt': failure.occurredAt,
    'retryable': failure.retryable,
  });
}

TaskFailure? decodeTaskFailure(
  String? value, {
  required TaskStatus status,
  required String? legacyErrorMessage,
  required String? legacyAnalysisErrorMessage,
  required int? failedAt,
}) {
  if (status != TaskStatus.analysisFailed &&
      status != TaskStatus.executionFailed) {
    return null;
  }

  final decoded = _decodeJsonFailure(value);
  if (decoded != null) {
    return decoded;
  }

  final analysisMessage = legacyAnalysisErrorMessage?.trim();
  final technicalMessage = legacyErrorMessage?.trim();
  final isAnalysisFailure = analysisMessage?.isNotEmpty == true;
  final fallbackMessage = isAnalysisFailure
      ? analysisMessage!
      : technicalMessage?.isNotEmpty == true
      ? technicalMessage!
      : '媒体处理未能完成';
  return TaskFailure(
    stage: isAnalysisFailure
        ? TaskFailureStage.analysis
        : TaskFailureStage.unknown,
    code: TaskFailureCode.unknown,
    userMessage: fallbackMessage,
    technicalSummary: technicalMessage?.isNotEmpty == true
        ? technicalMessage!
        : fallbackMessage,
    occurredAt: failedAt ?? 0,
    retryable: true,
  );
}

TaskFailure? _decodeJsonFailure(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic> ||
        json['version'] != taskFailureJsonVersion) {
      return _unknownFailureFromJson(json);
    }
    return TaskFailure(
      stage: _enumByName(
        TaskFailureStage.values,
        json['stage'],
        TaskFailureStage.unknown,
      ),
      code: _enumByName(
        TaskFailureCode.values,
        json['code'],
        TaskFailureCode.unknown,
      ),
      userMessage: _nonEmptyString(json['userMessage']) ?? '媒体处理未能完成',
      technicalSummary:
          _nonEmptyString(json['technicalSummary']) ?? '没有可用的技术摘要',
      occurredAt: json['occurredAt'] is int ? json['occurredAt'] as int : 0,
      retryable: json['retryable'] is bool ? json['retryable'] as bool : false,
    );
  } on Object {
    return null;
  }
}

TaskFailure _unknownFailureFromJson(Object? json) {
  final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
  return TaskFailure(
    stage: TaskFailureStage.unknown,
    code: TaskFailureCode.unknown,
    userMessage: _nonEmptyString(map['userMessage']) ?? '媒体处理未能完成',
    technicalSummary: _nonEmptyString(map['technicalSummary']) ?? '无法解析结构化失败信息',
    occurredAt: map['occurredAt'] is int ? map['occurredAt'] as int : 0,
    retryable: false,
  );
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  return values.cast<T?>().firstWhere(
        (value) => value?.name == name,
        orElse: () => null,
      ) ??
      fallback;
}

String? _nonEmptyString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}
