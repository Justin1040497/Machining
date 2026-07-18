import 'dart:convert';

class TaskNotificationPayload {
  const TaskNotificationPayload({
    required this.taskId,
    required this.fileName,
    this.outputPath,
    this.sourceFileSize,
    this.outputFileSize,
    this.durationMs,
    this.failureReason,
    this.failureSuggestion,
  });

  final String taskId;
  final String fileName;
  final String? outputPath;
  final int? sourceFileSize;
  final int? outputFileSize;
  final int? durationMs;
  final String? failureReason;
  final String? failureSuggestion;

  String toJson() {
    return jsonEncode({
      'taskId': taskId,
      'fileName': fileName,
      if (outputPath != null) 'outputPath': outputPath,
      if (sourceFileSize != null) 'sourceFileSize': sourceFileSize,
      if (outputFileSize != null) 'outputFileSize': outputFileSize,
      if (durationMs != null) 'durationMs': durationMs,
      if (failureReason != null) 'failureReason': failureReason,
      if (failureSuggestion != null) 'failureSuggestion': failureSuggestion,
    });
  }

  static TaskNotificationPayload? tryParse(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final taskId = decoded['taskId'];
      final fileName = decoded['fileName'];
      final outputPath = decoded['outputPath'];
      final sourceFileSize = decoded['sourceFileSize'];
      final outputFileSize = decoded['outputFileSize'];
      final durationMs = decoded['durationMs'];
      final failureReason = decoded['failureReason'];
      final failureSuggestion = decoded['failureSuggestion'];
      if (taskId is! String ||
          taskId.trim().isEmpty ||
          fileName is! String ||
          fileName.trim().isEmpty ||
          (outputPath != null && outputPath is! String) ||
          (sourceFileSize != null && sourceFileSize is! int) ||
          (outputFileSize != null && outputFileSize is! int) ||
          (durationMs != null && durationMs is! int) ||
          (failureReason != null && failureReason is! String) ||
          (failureSuggestion != null && failureSuggestion is! String)) {
        return null;
      }

      return TaskNotificationPayload(
        taskId: taskId,
        fileName: fileName,
        outputPath: outputPath as String?,
        sourceFileSize: sourceFileSize as int?,
        outputFileSize: outputFileSize as int?,
        durationMs: durationMs as int?,
        failureReason: failureReason as String?,
        failureSuggestion: failureSuggestion as String?,
      );
    } on Object {
      return null;
    }
  }
}
