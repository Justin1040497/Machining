import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

Future<void> main(List<String> arguments) async {
  final options = _parseArguments(arguments);
  final input = File(_required(options, 'input'));
  final privateKeyFile = File(_required(options, 'private-key'));
  final keyId = _required(options, 'key-id');
  final expectedPublicKey = _required(options, 'public-key');
  final output = File(options['output'] ?? '${input.path}.update.json');
  final version = options['version']?.trim();
  final buildNumber = int.tryParse(options['build-number']?.trim() ?? '');

  if (!await input.exists()) {
    throw StateError('Installer was not found: ${input.path}');
  }
  if (!await privateKeyFile.exists()) {
    throw StateError('Private key file was not found: ${privateKeyFile.path}');
  }

  final seed = await _readSeed(privateKeyFile);
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(seed);
  final publicKey = await keyPair.extractPublicKey();
  final actualPublicKey = base64Encode(publicKey.bytes);
  if (actualPublicKey != expectedPublicKey.trim()) {
    throw StateError('Private key does not match the configured public key');
  }

  final bytes = await input.readAsBytes();
  final signature = await algorithm.sign(bytes, keyPair: keyPair);
  final digest = await Sha256().hash(bytes);
  final metadata = <String, Object>{
    'schemaVersion': 1,
    if (version != null && version.isNotEmpty) 'version': version,
    ...?(buildNumber == null ? null : {'buildNumber': buildNumber}),
    'platform': 'windows-installer',
    'fileName': input.uri.pathSegments.last,
    'size': bytes.length,
    'sha256': digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(),
    'ed25519Signature': '$keyId:${base64Encode(signature.bytes)}',
  };
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
  );
  stdout.writeln(output.path);
}

Future<List<int>> _readSeed(File file) async {
  final raw = await file.readAsBytes();
  if (raw.length == 32) {
    return raw;
  }
  try {
    final decoded = base64Decode(utf8.decode(raw).trim());
    if (decoded.length == 32) {
      return decoded;
    }
  } on FormatException {
    // Fall through to the precise error below.
  }
  throw StateError(
    'Ed25519 private key must be a 32-byte seed or its base64 encoding',
  );
}

Map<String, String> _parseArguments(List<String> arguments) {
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length || !arguments[index].startsWith('--')) {
      throw ArgumentError('Expected --name value arguments');
    }
    result[arguments[index].substring(2)] = arguments[index + 1];
  }
  return result;
}

String _required(Map<String, String> options, String name) {
  final value = options[name]?.trim();
  if (value == null || value.isEmpty) {
    throw ArgumentError('Missing --$name');
  }
  return value;
}
