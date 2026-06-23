import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/domain/library.dart';

class ProprietaryAudioDecodeException implements Exception {
  final String message;

  const ProprietaryAudioDecodeException(this.message);

  @override
  String toString() {
    return message;
  }
}

/// 调用具体本地适配器，把专有音频输入还原为标准音频文件。
abstract interface class ProprietaryAudioDecoder {
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  });
}
