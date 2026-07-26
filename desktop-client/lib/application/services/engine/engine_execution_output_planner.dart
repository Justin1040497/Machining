import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:path/path.dart' as path;

/// Builds the output path requested by the product layer.
///
/// The Client owns the user's directory and filename intent. FLL owns
/// collision handling, source protection, temporary files, and publication.
class EngineExecutionOutputPlanner {
  const EngineExecutionOutputPlanner();

  String buildRequestedPath({
    required MediaTask task,
    required AppSettings settings,
    required String outputContainer,
  }) {
    final outputDirectory = _resolveOutputDirectory(task, settings);
    final extension = _extensionForContainer(outputContainer);
    final fileName = _resolveFileName(task, extension);
    return path.join(outputDirectory, fileName);
  }

  String _resolveOutputDirectory(MediaTask task, AppSettings settings) {
    final sourceDirectory = path.dirname(task.inputPath);
    final configured = switch (task.config.outputLocationMode) {
      OutputLocationMode.source => sourceDirectory,
      OutputLocationMode.custom => task.config.outputDirectory.trim(),
      OutputLocationMode.system =>
        settings.saveOutputToSourceDirectory
            ? sourceDirectory
            : settings.defaultOutputDirectory?.trim() ?? '',
    };
    if (configured.isEmpty) {
      return sourceDirectory;
    }
    if (!path.isAbsolute(configured)) {
      throw const EngineExecutionOutputPlanException('输出目录必须是绝对路径');
    }
    return path.normalize(configured);
  }

  String _resolveFileName(MediaTask task, String extension) {
    final configured = path.basename(task.config.outputFileName.trim());
    final stem = configured.isEmpty
        ? path.basenameWithoutExtension(task.inputPath)
        : _removeKnownMediaExtension(configured);
    final safeStem = stem.trim().isEmpty
        ? path.basenameWithoutExtension(task.inputPath)
        : stem.trim();
    final suffix = task.purpose.name == 'conversion'
        ? 'converted'
        : 'compressed';
    final effectiveStem = configured.isEmpty
        ? '${safeStem.isEmpty ? 'framelean' : safeStem}_$suffix'
        : (safeStem.isEmpty ? 'framelean-$suffix' : safeStem);
    return '$effectiveStem$extension';
  }

  String _removeKnownMediaExtension(String value) {
    final extension = path.extension(value).toLowerCase();
    if (extension.isEmpty || !_knownMediaExtensions.contains(extension)) {
      return value;
    }
    return path.basenameWithoutExtension(value);
  }

  String _extensionForContainer(String value) {
    final normalized = value.trim().toLowerCase().replaceFirst('.', '');
    if (normalized.isEmpty ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,15}$').hasMatch(normalized)) {
      throw const EngineExecutionOutputPlanException('FLL 没有返回有效的输出容器');
    }
    return '.${switch (normalized) {
      'matroska' => 'mkv',
      'quicktime' => 'mov',
      'jpeg' => 'jpg',
      'tif' => 'tiff',
      'ogg_opus' => 'ogg',
      _ => normalized,
    }}';
  }
}

class EngineExecutionOutputPlanException implements Exception {
  const EngineExecutionOutputPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _knownMediaExtensions = <String>{
  '.mp4',
  '.mov',
  '.mkv',
  '.webm',
  '.avi',
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.tiff',
  '.tif',
  '.gif',
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.flac',
  '.aiff',
  '.wma',
  '.opus',
  '.ogg',
};
