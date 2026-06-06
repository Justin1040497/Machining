import 'dart:io';
import 'dart:typed_data';

import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_crypto.dart';
import 'package:framelean/infrastructure/services/proprietary_audio/ncm/ncm_key_box.dart';

class NcmContainer {
  final NcmKeyBox keyBox;
  final int audioDataOffset;

  const NcmContainer({required this.keyBox, required this.audioDataOffset});
}

class NcmContainerParser {
  static final Uint8List magic = Uint8List.fromList(const [
    0x43,
    0x54,
    0x45,
    0x4e,
    0x46,
    0x44,
    0x41,
    0x4d,
  ]);

  const NcmContainerParser();

  Future<NcmContainer> parse(RandomAccessFile file) async {
    final header = await file.read(magic.length);
    if (!_bytesEqual(header, magic)) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 文件头无效');
    }

    await _skip(file, 2);
    final encryptedKeyLength = await _readUint32(file);
    if (encryptedKeyLength <= 0) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 密钥长度无效');
    }

    final encryptedKey = await _readExact(file, encryptedKeyLength);
    final keyData = _decryptKeyData(encryptedKey);
    final keyBox = NcmKeyBox.fromAudioKey(keyData);

    final metadataLength = await _readUint32(file);
    if (metadataLength > 0) {
      await _skip(file, metadataLength);
    }

    await _skip(file, 5);

    final coverFrameLength = await _readUint32(file);
    final imageLength = await _readUint32(file);
    if (imageLength > coverFrameLength) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 封面数据长度无效');
    }

    if (imageLength > 0) {
      await _skip(file, imageLength);
    }

    final remainingCoverBytes = coverFrameLength - imageLength;
    if (remainingCoverBytes > 0) {
      await _skip(file, remainingCoverBytes);
    }

    return NcmContainer(keyBox: keyBox, audioDataOffset: await file.position());
  }

  Uint8List _decryptKeyData(Uint8List encryptedKey) {
    final decrypted = NcmCrypto.decryptAesEcbPkcs7(
      NcmCrypto.xor(encryptedKey, 0x64),
      NcmCrypto.coreKey,
    );
    const prefixLength = 17;
    if (decrypted.length <= prefixLength) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 解包后的密钥无效');
    }

    return Uint8List.sublistView(decrypted, prefixLength);
  }

  Future<int> _readUint32(RandomAccessFile file) async {
    final bytes = await _readExact(file, 4);
    return ByteData.sublistView(bytes).getUint32(0, Endian.little);
  }

  Future<Uint8List> _readExact(RandomAccessFile file, int length) async {
    final bytes = await file.read(length);
    if (bytes.length != length) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 文件数据不完整');
    }

    return bytes;
  }

  Future<void> _skip(RandomAccessFile file, int length) async {
    if (length < 0) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 文件偏移无效');
    }

    await file.setPosition(await file.position() + length);
  }

  bool _bytesEqual(Uint8List first, Uint8List second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }
}
