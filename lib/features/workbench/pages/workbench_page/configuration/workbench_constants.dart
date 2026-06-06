import 'package:file_selector/file_selector.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';

abstract final class WorkbenchConstants {
  static const double appTopBarHeight = 52;
  static const double minWorkbenchWidth = 685;
  static const double minWorkbenchHeight = 640;

  static const videoTypeGroup = XTypeGroup(
    label: '视频文件',
    extensions: ['mp4', 'mov', 'mkv', 'm4v', 'avi', 'webm'],
    uniformTypeIdentifiers: [
      'public.movie',
      'public.video',
      'public.mpeg-4',
      'com.apple.quicktime-movie',
      'org.matroska.mkv',
    ],
  );

  static const imageTypeGroup = XTypeGroup(
    label: '图片文件',
    extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    uniformTypeIdentifiers: [
      'public.image',
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );

  static const audioTypeGroup = XTypeGroup(
    label: '音频文件',
    extensions: [
      'mp3',
      'wav',
      'aac',
      'flac',
      'm4a',
      'ogg',
      'ncm',
      'mgg',
      'mgg0',
      'mgg1',
      'mggl',
      'mflac',
      'mflac0',
      'qmcflac',
    ],
    uniformTypeIdentifiers: [
      'public.audio',
      'public.mp3',
      'public.mpeg-4-audio',
      'com.microsoft.waveform-audio',
    ],
  );

  static const mediaTypeGroups = [
    videoTypeGroup,
    imageTypeGroup,
    audioTypeGroup,
  ];

  static const qualityOptions = [
    QualityOption(label: '高质量', crf: 24, targetRatio: 0.95),
    QualityOption(label: '清晰+', crf: 25, targetRatio: 0.85),
    QualityOption(label: '清晰', crf: 26, targetRatio: 0.75),
    QualityOption(label: '均衡+', crf: 27, targetRatio: 0.65),
    QualityOption(label: '均衡', crf: 28, targetRatio: 0.50),
    QualityOption(label: '小体积+', crf: 29, targetRatio: 0.35),
    QualityOption(label: '小体积', crf: 30, targetRatio: 0.25),
    QualityOption(label: '极小体积', crf: 31, targetRatio: 0.15),
    QualityOption(label: '最低体积', crf: 32, targetRatio: 0.10),
  ];

  static const targetSizeRatios = [
    0.10,
    0.20,
    0.30,
    0.40,
    0.50,
    0.60,
    0.70,
    0.80,
    0.90,
  ];

  static const defaultTargetSizeRatio = 0.60;
}
