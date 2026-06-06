import 'dart:typed_data';

import 'package:framelean/application/services/input_runtime/proprietary_audio_decoder.dart';

class NcmKeyBox {
  final Uint8List bytes;

  const NcmKeyBox._(this.bytes);

  factory NcmKeyBox.fromAudioKey(Uint8List audioKey) {
    if (audioKey.isEmpty) {
      throw const ProprietaryAudioDecodeException('NCM 解析失败: 音频密钥为空');
    }

    final box = Uint8List(256);
    for (var index = 0; index < box.length; index += 1) {
      box[index] = index;
    }

    var swapIndex = 0;
    for (var index = 0; index < box.length; index += 1) {
      swapIndex =
          (swapIndex + box[index] + audioKey[index % audioKey.length]) & 0xff;
      final temporary = box[index];
      box[index] = box[swapIndex];
      box[swapIndex] = temporary;
    }

    return NcmKeyBox._(box);
  }

  void transformAudioChunk(Uint8List chunk) {
    for (var index = 0; index < chunk.length; index += 1) {
      final keyIndex = (index + 1) & 0xff;
      final mixedIndex = (bytes[keyIndex] + keyIndex) & 0xff;
      final mask = bytes[(bytes[keyIndex] + bytes[mixedIndex]) & 0xff];
      chunk[index] = chunk[index] ^ mask;
    }
  }
}
