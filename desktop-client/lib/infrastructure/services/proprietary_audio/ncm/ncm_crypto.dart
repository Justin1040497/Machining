import 'dart:typed_data';

import 'package:pointycastle/export.dart';

abstract final class NcmCrypto {
  static final Uint8List coreKey = Uint8List.fromList(const [
    0x68,
    0x7a,
    0x48,
    0x52,
    0x41,
    0x6d,
    0x73,
    0x6f,
    0x35,
    0x6b,
    0x49,
    0x6e,
    0x62,
    0x61,
    0x78,
    0x57,
  ]);

  static Uint8List decryptAesEcbPkcs7(Uint8List encrypted, Uint8List key) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(AESEngine()),
    );
    cipher.init(
      false,
      PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
        KeyParameter(key),
        null,
      ),
    );

    return cipher.process(encrypted);
  }

  static Uint8List xor(Uint8List bytes, int mask) {
    final result = Uint8List(bytes.length);
    for (var index = 0; index < bytes.length; index += 1) {
      result[index] = bytes[index] ^ mask;
    }

    return result;
  }
}
