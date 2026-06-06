import 'package:framelean/domain/enums/proprietary_audio_format.dart';

class ProprietaryAudioAdapterRuntime {
  final ProprietaryAudioFormat format;
  final String adapterName;
  final String adapterVersion;
  final String executablePath;

  const ProprietaryAudioAdapterRuntime({
    required this.format,
    required this.adapterName,
    required this.adapterVersion,
    required this.executablePath,
  });
}

class ProprietaryAudioAdapterUnavailableException implements Exception {
  final ProprietaryAudioFormat format;
  final String message;

  const ProprietaryAudioAdapterUnavailableException({
    required this.format,
    required this.message,
  });

  @override
  String toString() {
    return message;
  }
}

/// 解析随包分发或开发环境中的专有音频适配器运行时。
abstract interface class ProprietaryAudioAdapterRegistry {
  Future<ProprietaryAudioAdapterRuntime> resolveRuntime(
    ProprietaryAudioFormat format,
  );
}
