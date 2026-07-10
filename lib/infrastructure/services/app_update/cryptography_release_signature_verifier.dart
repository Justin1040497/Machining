import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class CryptographyReleaseSignatureVerifier implements ReleaseSignatureVerifier {
  CryptographyReleaseSignatureVerifier({
    Map<String, String>? publicKeys,
    Ed25519? algorithm,
  }) : publicKeys = publicKeys ?? _readBundledPublicKeys(),
       algorithm = algorithm ?? Ed25519();

  final Map<String, String> publicKeys;
  final Ed25519 algorithm;

  @override
  Future<void> verify({
    required File file,
    required AppUpdatePackageInfo package,
    required EnterpriseUpdateConfig config,
  }) async {
    if (!config.requiresReleaseSignature) {
      return;
    }

    final rawSignature = package.ed25519Signature?.trim();
    if (rawSignature == null || rawSignature.isEmpty) {
      throw StateError('更新包缺少 Ed25519 签名');
    }

    final parsed = _ParsedSignature.parse(rawSignature);
    final keyIds = parsed.keyId == null
        ? config.trustedReleaseKeyIds
        : [parsed.keyId!];
    final allowedKeyIds = keyIds
        .where(config.trustedReleaseKeyIds.contains)
        .where(publicKeys.containsKey)
        .toList(growable: false);

    if (allowedKeyIds.isEmpty) {
      throw StateError('更新包签名使用了不受信任的 key id');
    }

    final data = await file.readAsBytes();
    for (final keyId in allowedKeyIds) {
      final publicKeyText = publicKeys[keyId];
      if (publicKeyText == null || publicKeyText.isEmpty) {
        continue;
      }
      final verified = await algorithm.verify(
        data,
        signature: Signature(
          base64Decode(parsed.signatureBase64),
          publicKey: SimplePublicKey(
            base64Decode(publicKeyText),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (verified) {
        return;
      }
    }

    throw StateError('更新包 Ed25519 签名校验失败');
  }
}

class _ParsedSignature {
  const _ParsedSignature({required this.keyId, required this.signatureBase64});

  final String? keyId;
  final String signatureBase64;

  static _ParsedSignature parse(String raw) {
    final separator = raw.indexOf(':');
    if (separator <= 0) {
      return _ParsedSignature(keyId: null, signatureBase64: raw);
    }
    return _ParsedSignature(
      keyId: raw.substring(0, separator).trim(),
      signatureBase64: raw.substring(separator + 1).trim(),
    );
  }
}

Map<String, String> _readBundledPublicKeys() {
  const raw = String.fromEnvironment('FRAMELEAN_RELEASE_PUBLIC_KEYS');
  final result = <String, String>{};
  for (final entry in raw.split(',')) {
    final separator = entry.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final keyId = entry.substring(0, separator).trim();
    final publicKey = entry.substring(separator + 1).trim();
    if (keyId.isNotEmpty && publicKey.isNotEmpty) {
      result[keyId] = publicKey;
    }
  }
  return Map.unmodifiable(result);
}
