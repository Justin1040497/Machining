import 'dart:convert';

class TaskNotificationPayload {
  const TaskNotificationPayload({
    required this.taskId,
    required this.fileName,
    this.outputPath,
  });

  final String taskId;
  final String fileName;
  final String? outputPath;

  String toJson() {
    return jsonEncode({
      'taskId': taskId,
      'fileName': fileName,
      if (outputPath != null) 'outputPath': outputPath,
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
      if (taskId is! String ||
          taskId.trim().isEmpty ||
          fileName is! String ||
          fileName.trim().isEmpty ||
          (outputPath != null && outputPath is! String)) {
        return null;
      }

      return TaskNotificationPayload(
        taskId: taskId,
        fileName: fileName,
        outputPath: outputPath as String?,
      );
    } on Object {
      return null;
    }
  }
}
