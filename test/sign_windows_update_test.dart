import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/sign_windows_update.dart' as signer;

void main() {
  test('signer emits verifiable Windows update metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'framelean-update-signer-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final installer = File('${directory.path}/FrameLean-setup.exe');
    final seedFile = File('${directory.path}/release.seed');
    final metadataFile = File('${installer.path}.update.json');
    final installerBytes = List<int>.generate(128, (index) => index);
    final seed = List<int>.generate(32, (index) => index + 1);
    await installer.writeAsBytes(installerBytes);
    await seedFile.writeAsBytes(seed);

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    await signer.main([
      '--input',
      installer.path,
      '--private-key',
      seedFile.path,
      '--key-id',
      'stable-v1',
      '--public-key',
      base64Encode(publicKey.bytes),
      '--output',
      metadataFile.path,
    ]);

    final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
    expect(metadata['schemaVersion'], 1);
    expect(metadata['platform'], 'windows-installer');
    expect(metadata['fileName'], 'FrameLean-setup.exe');
    expect(metadata['size'], installerBytes.length);
    expect(
      metadata['sha256'],
      hashes.sha256.convert(installerBytes).toString(),
    );

    final signatureText = metadata['ed25519Signature'] as String;
    final separator = signatureText.indexOf(':');
    expect(signatureText.substring(0, separator), 'stable-v1');
    expect(
      await algorithm.verify(
        installerBytes,
        signature: Signature(
          base64Decode(signatureText.substring(separator + 1)),
          publicKey: publicKey,
        ),
      ),
      isTrue,
    );
  });
}
