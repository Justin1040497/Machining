import 'package:framelean/application/services/platform/file_revealer.dart';
import 'package:framelean/domain/entities/media_task.dart';

class WorkbenchResultHandler {
  const WorkbenchResultHandler({
    required this.fileRevealer,
    required this.showMessage,
  });

  final FileRevealer fileRevealer;
  final void Function(String message) showMessage;

  Future<void> revealTask(MediaTask task) {
    final targetPath = task.outputPath?.trim().isNotEmpty == true
        ? task.outputPath!.trim()
        : task.inputPath;
    return revealPath(targetPath);
  }

  Future<void> revealOutput(MediaTask task) async {
    final outputPath = task.outputPath?.trim();
    if (outputPath == null || outputPath.isEmpty) {
      showMessage('任务还没有完成文件');
      return;
    }
    await revealPath(outputPath);
  }

  Future<void> revealPath(String targetPath) async {
    final result = await fileRevealer.revealPath(targetPath);
    if (!result.succeeded) {
      showMessage(result.message!);
    }
  }
}
