import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';
import 'package:framelean/infrastructure/services/input_runtime/standard_cli_proprietary_audio_decoder.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/native_ncm_audio_decoder.dart';

class ProprietaryAudioDecoderDispatcher implements ProprietaryAudioDecoder {
  final ProprietaryAudioDecoder nativeNcmDecoder;
  final ProprietaryAudioDecoder externalAdapterDecoder;

  const ProprietaryAudioDecoderDispatcher({
    this.nativeNcmDecoder = const NativeNcmAudioDecoder(),
    this.externalAdapterDecoder = const StandardCliProprietaryAudioDecoder(),
  });

  @override
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  }) {
    return switch (runtime.format) {
      ProprietaryAudioFormat.ncm => nativeNcmDecoder.decode(
        runtime: runtime,
        inputPath: inputPath,
        temporaryDirectory: temporaryDirectory,
      ),
      ProprietaryAudioFormat.qmcMgg ||
      ProprietaryAudioFormat.qmcMflac => externalAdapterDecoder.decode(
        runtime: runtime,
        inputPath: inputPath,
        temporaryDirectory: temporaryDirectory,
      ),
    };
  }
}
