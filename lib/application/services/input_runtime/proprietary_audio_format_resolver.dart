import 'package:framelean/domain/enums/proprietary_audio_format.dart';

/// 识别需要本地适配器预处理的专有音频输入格式。
abstract interface class ProprietaryAudioFormatResolver {
  ProprietaryAudioFormat? resolve(String inputPath);
}
