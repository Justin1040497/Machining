import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_adapter_registry.dart';
import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/domain/enums/proprietary_audio_format.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/native_ncm_audio_decoder.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_container_parser.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_crypto.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_key_box.dart';
import 'package:path/path.dart' as path;
import 'package:pointycastle/export.dart';

void main() {
  group('NativeNcmAudioDecoder', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'framelean-native-ncm-test-',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('decodes ncm container into mp3 temporary output', () async {
      final audioBytes = Uint8List.fromList([
        ...utf8.encode('ID3'),
        3,
        0,
        0,
        0,
        0,
        0,
        8,
        ...utf8.encode('decoded'),
      ]);
      final inputPath = path.join(tempDirectory.path, 'source.ncm');
      await writeSyntheticNcmFile(File(inputPath), audioBytes);

      final result = await const NativeNcmAudioDecoder().decode(
        runtime: nativeRuntime,
        inputPath: inputPath,
        temporaryDirectory: path.join(tempDirectory.path, 'decoded'),
      );

      expect(result.decodedExtension, '.mp3');
      expect(result.adapterName, 'native-ncm-dart');
      expect(await File(result.decodedPath).readAsBytes(), audioBytes);
    });

    test('rejects invalid ncm header with readable error', () async {
      final inputPath = path.join(tempDirectory.path, 'broken.ncm');
      File(inputPath).writeAsStringSync('not ncm');

      expect(
        () => const NativeNcmAudioDecoder().decode(
          runtime: nativeRuntime,
          inputPath: inputPath,
          temporaryDirectory: path.join(tempDirectory.path, 'decoded'),
        ),
        throwsA(isA<ProprietaryAudioDecodeException>()),
      );
    });
  });
}

const nativeRuntime = ProprietaryAudioAdapterRuntime(
  format: ProprietaryAudioFormat.ncm,
  adapterName: 'native-ncm-dart',
  adapterVersion: 'builtin',
  executablePath: '',
);

Future<void> writeSyntheticNcmFile(File file, Uint8List audioBytes) async {
  final audioKey = Uint8List.fromList(const [
    0x12,
    0x34,
    0x56,
    0x78,
    0x9a,
    0xbc,
    0xde,
    0xf0,
  ]);
  final keyPlaintext = Uint8List.fromList([
    ...utf8.encode('neteasecloudmusic'),
    ...audioKey,
  ]);
  final encryptedKey = NcmCrypto.xor(
    aesEcbPkcs7Encrypt(keyPlaintext, NcmCrypto.coreKey),
    0x64,
  );
  final encryptedAudio = Uint8List.fromList(audioBytes);
  NcmKeyBox.fromAudioKey(audioKey).transformAudioChunk(encryptedAudio);

  final output = BytesBuilder();
  output.add(NcmContainerParser.magic);
  output.add([0, 0]);
  output.add(uint32Bytes(encryptedKey.length));
  output.add(encryptedKey);
  output.add(uint32Bytes(0));
  output.add([0, 0, 0, 0, 0]);
  output.add(uint32Bytes(0));
  output.add(uint32Bytes(0));
  output.add(encryptedAudio);

  await file.writeAsBytes(output.toBytes());
}

Uint8List aesEcbPkcs7Encrypt(Uint8List plaintext, Uint8List key) {
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    ECBBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
      KeyParameter(key),
      null,
    ),
  );

  return cipher.process(plaintext);
}

List<int> uint32Bytes(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}
