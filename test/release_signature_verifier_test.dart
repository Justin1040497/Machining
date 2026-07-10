import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/value_objects/app_update_package_info.dart';
import 'package:framelean/domain/value_objects/enterprise_update_config.dart';
import 'package:framelean/infrastructure/services/app_update/cryptography_release_signature_verifier.dart';

void main() {
  test('verifies package Ed25519 signature with trusted key id', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final directory = await Directory.systemTemp.createTemp(
      'framelean-signature-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/update.bin');
    await file.writeAsString('signed update payload');
    final signature = await algorithm.sign(
      await file.readAsBytes(),
      keyPair: keyPair,
    );
    final verifier = CryptographyReleaseSignatureVerifier(
      publicKeys: {'stable-v1': base64Encode(publicKey.bytes)},
      algorithm: algorithm,
    );

    await verifier.verify(
      file: file,
      package: AppUpdatePackageInfo(
        fileName: 'update.bin',
        sizeBytes: await file.length(),
        sha256: 'a'.padRight(64, 'a'),
        ed25519Signature: 'stable-v1:${base64Encode(signature.bytes)}',
      ),
      config: EnterpriseUpdateConfig.bundled().copyWith(
        trustedReleaseKeyIds: ['stable-v1'],
      ),
    );
  });

  test('requires signature when trusted key ids are configured', () async {
    final directory = await Directory.systemTemp.createTemp(
      'framelean-signature-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/update.bin');
    await file.writeAsString('unsigned update payload');
    final fileSize = await file.length();
    final verifier = CryptographyReleaseSignatureVerifier(
      publicKeys: const {'stable-v1': 'invalid'},
    );

    expect(
      () => verifier.verify(
        file: file,
        package: AppUpdatePackageInfo(
          fileName: 'update.bin',
          sizeBytes: fileSize,
          sha256: 'a'.padRight(64, 'a'),
        ),
        config: EnterpriseUpdateConfig.bundled().copyWith(
          trustedReleaseKeyIds: ['stable-v1'],
        ),
      ),
      throwsStateError,
    );
  });
}
