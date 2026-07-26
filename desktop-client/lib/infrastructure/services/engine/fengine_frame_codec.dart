import 'dart:convert';
import 'dart:typed_data';

const int fengineMaximumFramePayloadLength = 16 * 1024 * 1024;

final class FEngineFrameCodec {
  const FEngineFrameCodec._();

  static Uint8List encode(Map<String, Object?> message) {
    late final Uint8List payload;
    try {
      payload = utf8.encode(jsonEncode(message));
    } on JsonUnsupportedObjectError catch (error) {
      throw FEngineInvalidJsonException(error);
    }

    if (payload.length > fengineMaximumFramePayloadLength) {
      throw FEngineFrameTooLargeException(
        payloadLength: payload.length,
        maximumPayloadLength: fengineMaximumFramePayloadLength,
      );
    }

    final frame = Uint8List(4 + payload.length);
    ByteData.sublistView(frame).setUint32(0, payload.length, Endian.big);
    frame.setRange(4, frame.length, payload);
    return frame;
  }
}

final class FEngineFrameDecoder {
  final List<int> _buffer = <int>[];
  int? _expectedPayloadLength;
  bool _isClosed = false;

  List<Map<String, Object?>> add(List<int> chunk) {
    if (_isClosed) {
      throw StateError(
        'Cannot add bytes after the FEngine frame decoder closes.',
      );
    }

    _buffer.addAll(chunk);
    final messages = <Map<String, Object?>>[];

    while (true) {
      if (_expectedPayloadLength == null) {
        if (_buffer.length < 4) {
          break;
        }

        final payloadLength =
            (_buffer[0] << 24) |
            (_buffer[1] << 16) |
            (_buffer[2] << 8) |
            _buffer[3];
        if (payloadLength == 0) {
          throw const FEngineZeroLengthFrameException();
        }
        if (payloadLength > fengineMaximumFramePayloadLength) {
          throw FEngineFrameTooLargeException(
            payloadLength: payloadLength,
            maximumPayloadLength: fengineMaximumFramePayloadLength,
          );
        }

        _buffer.removeRange(0, 4);
        _expectedPayloadLength = payloadLength;
      }

      final payloadLength = _expectedPayloadLength!;
      if (_buffer.length < payloadLength) {
        break;
      }

      final payload = Uint8List.fromList(_buffer.sublist(0, payloadLength));
      _buffer.removeRange(0, payloadLength);
      _expectedPayloadLength = null;
      messages.add(_decodePayload(payload));
    }

    return messages;
  }

  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;

    final expectedPayloadLength = _expectedPayloadLength;
    if (expectedPayloadLength != null) {
      throw FEngineTruncatedFrameException(
        section: FEngineFrameSection.payload,
        expectedBytes: expectedPayloadLength,
        receivedBytes: _buffer.length,
      );
    }
    if (_buffer.isNotEmpty) {
      throw FEngineTruncatedFrameException(
        section: FEngineFrameSection.header,
        expectedBytes: 4,
        receivedBytes: _buffer.length,
      );
    }
  }

  Map<String, Object?> _decodePayload(Uint8List payload) {
    late final String text;
    try {
      text = utf8.decode(payload, allowMalformed: false);
    } on FormatException catch (error) {
      throw FEngineInvalidUtf8Exception(error);
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw FEngineInvalidJsonException(error);
    }

    if (decoded is! Map<String, dynamic>) {
      throw FEngineNonObjectJsonException(decoded);
    }
    return Map<String, Object?>.unmodifiable(decoded);
  }
}

enum FEngineFrameSection { header, payload }

sealed class FEngineFrameCodecException implements Exception {
  const FEngineFrameCodecException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class FEngineZeroLengthFrameException extends FEngineFrameCodecException {
  const FEngineZeroLengthFrameException()
    : super('FEngine frames must contain a non-empty JSON payload.');
}

final class FEngineFrameTooLargeException extends FEngineFrameCodecException {
  FEngineFrameTooLargeException({
    required this.payloadLength,
    required this.maximumPayloadLength,
  }) : super(
         'FEngine frame payload is $payloadLength bytes; '
         'the maximum is $maximumPayloadLength bytes.',
       );

  final int payloadLength;
  final int maximumPayloadLength;
}

final class FEngineTruncatedFrameException extends FEngineFrameCodecException {
  FEngineTruncatedFrameException({
    required this.section,
    required this.expectedBytes,
    required this.receivedBytes,
  }) : super(
         'FEngine frame ${section.name} ended after $receivedBytes of '
         '$expectedBytes bytes.',
       );

  final FEngineFrameSection section;
  final int expectedBytes;
  final int receivedBytes;
}

final class FEngineInvalidUtf8Exception extends FEngineFrameCodecException {
  FEngineInvalidUtf8Exception(this.cause)
    : super('FEngine frame payload is not valid UTF-8.');

  final FormatException cause;
}

final class FEngineInvalidJsonException extends FEngineFrameCodecException {
  FEngineInvalidJsonException(this.cause)
    : super('FEngine frame payload is not valid JSON.');

  final Object cause;
}

final class FEngineNonObjectJsonException extends FEngineFrameCodecException {
  FEngineNonObjectJsonException(this.decodedValue)
    : super('FEngine frame payload must decode to a JSON object.');

  final Object? decodedValue;
}
