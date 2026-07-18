import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/platform/file_revealer.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_result_handler.dart';

void main() {
  test('reveals the completed output path', () async {
    final revealer = _FakeFileRevealer();
    final messages = <String>[];
    final handler = WorkbenchResultHandler(
      fileRevealer: revealer,
      showMessage: messages.add,
    );
    final task = MediaTask.draft(
      inputPath: '/source/input.mp4',
      fileName: 'input.mp4',
      mediaKind: MediaKind.video,
      sortOrder: 0,
    ).copyWith(outputPath: '/output/result.mp4');

    await handler.revealOutput(task);

    expect(revealer.paths, ['/output/result.mp4']);
    expect(messages, isEmpty);
  });

  test('reports a missing completed output path', () async {
    final revealer = _FakeFileRevealer();
    final messages = <String>[];
    final handler = WorkbenchResultHandler(
      fileRevealer: revealer,
      showMessage: messages.add,
    );
    final task = MediaTask.draft(
      inputPath: '/source/input.mp4',
      fileName: 'input.mp4',
      mediaKind: MediaKind.video,
      sortOrder: 0,
    );

    await handler.revealOutput(task);

    expect(revealer.paths, isEmpty);
    expect(messages, ['任务还没有完成文件']);
  });
}

class _FakeFileRevealer implements FileRevealer {
  final List<String> paths = [];

  @override
  Future<FileRevealResult> revealPath(String targetPath) async {
    paths.add(targetPath);
    return const FileRevealResult.success();
  }
}
