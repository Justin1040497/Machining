import 'package:framelean/domain/enums/media_output_format.dart';

/// 图片分辨率处理预设。
enum ImageResizePreset {
  original,
  longEdge3840,
  longEdge2560,
  longEdge1920,
  longEdge1280,
  longEdge720,
}

/// 图片任务的分类型处理配置。
class ImageProcessingConfig {
  final MediaOutputFormat outputFormat;
  final bool keepOriginalOutputFormat;
  final bool losslessCompression;
  final int imageQuality;
  final ImageResizePreset resizePreset;
  final bool preserveMetadata;

  const ImageProcessingConfig({
    required this.outputFormat,
    required this.keepOriginalOutputFormat,
    required this.losslessCompression,
    required this.imageQuality,
    required this.resizePreset,
    required this.preserveMetadata,
  }) : assert(imageQuality >= 1 && imageQuality <= 100);

  factory ImageProcessingConfig.initial() {
    return const ImageProcessingConfig(
      outputFormat: MediaOutputFormat.jpg,
      keepOriginalOutputFormat: true,
      losslessCompression: false,
      imageQuality: 80,
      resizePreset: ImageResizePreset.original,
      preserveMetadata: true,
    );
  }

  ImageProcessingConfig copyWith({
    MediaOutputFormat? outputFormat,
    bool? keepOriginalOutputFormat,
    bool? losslessCompression,
    int? imageQuality,
    ImageResizePreset? resizePreset,
    bool? preserveMetadata,
  }) {
    return ImageProcessingConfig(
      outputFormat: outputFormat ?? this.outputFormat,
      keepOriginalOutputFormat:
          keepOriginalOutputFormat ?? this.keepOriginalOutputFormat,
      losslessCompression: losslessCompression ?? this.losslessCompression,
      imageQuality: imageQuality ?? this.imageQuality,
      resizePreset: resizePreset ?? this.resizePreset,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
    );
  }
}

const losslessImageOutputFormats = {
  MediaOutputFormat.png,
  MediaOutputFormat.webp,
  MediaOutputFormat.tiff,
};

bool supportsLosslessImageCompression(MediaOutputFormat format) {
  return losslessImageOutputFormats.contains(format);
}
