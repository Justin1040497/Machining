import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/proprietary_audio_decoder_dispatcher.dart';

void main() {
  group('ProprietaryAudioDecoderDispatcher', () {
    test(
      'routes ncm to native decoder and qmc formats to external decoder',
      () async {
        final nativeDecoder = FakeDecoder('native');
        final externalDecoder = FakeDecoder('external');
        final dispatcher = ProprietaryAudioDecoderDispatcher(
          nativeNcmDecoder: nativeDecoder,
          externalAdapterDecoder: externalDecoder,
        );

        await dispatcher.decode(
          runtime: runtime(ProprietaryAudioFormat.ncm),
          inputPath: '/music/song.ncm',
          temporaryDirectory: '/tmp/native',
        );
        await dispatcher.decode(
          runtime: runtime(ProprietaryAudioFormat.qmcMflac),
          inputPath: '/music/song.mflac',
          temporaryDirectory: '/tmp/qmc',
        );

        expect(nativeDecoder.inputPaths, ['/music/song.ncm']);
        expect(externalDecoder.inputPaths, ['/music/song.mflac']);
      },
    );
  });
}

ProprietaryAudioAdapterRuntime runtime(ProprietaryAudioFormat format) {
  return ProprietaryAudioAdapterRuntime(
    format: format,
    adapterName: 'adapter-${format.name}',
    adapterVersion: 'test',
    executablePath: '/adapter',
  );
}

class FakeDecoder implements ProprietaryAudioDecoder {
  final String name;
  final List<String> inputPaths = [];

  FakeDecoder(this.name);

  @override
  Future<ProprietaryAudioDecodeResult> decode({
    required ProprietaryAudioAdapterRuntime runtime,
    required String inputPath,
    required String temporaryDirectory,
  }) async {
    inputPaths.add(inputPath);
    return ProprietaryAudioDecodeResult(
      decodedPath: '$temporaryDirectory/$name.mp3',
      decodedExtension: '.mp3',
      adapterName: name,
      adapterVersion: 'test',
    );
  }
}
