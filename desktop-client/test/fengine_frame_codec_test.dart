import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/infrastructure/library.dart';

void main() {
  group('FEngineFrameCodec.encode', () {
    test(
      'writes a big-endian byte length followed by JSON without a newline',
      () {
        const message = <String, Object?>{'type': 'ping'};

        final frame = FEngineFrameCodec.encode(message);
        final payload = utf8.encode(jsonEncode(message));

        expect(
          frame,
          orderedEquals(<int>[0, 0, 0, payload.length, ...payload]),
        );
        expect(frame.last, isNot(0x0a));
      },
    );

    test('counts UTF-8 bytes rather than Dart string code units', () {
      const message = <String, Object?>{'message': '你好'};

      final frame = FEngineFrameCodec.encode(message);
      final payloadLength = ByteData.sublistView(frame, 0, 4).getUint32(0);

      expect(payloadLength, utf8.encode(jsonEncode(message)).length);
    });
  });

  group('FEngineFrameDecoder', () {
    test('accepts a frame split across arbitrary input chunks', () {
      const message = <String, Object?>{
        'type': 'response',
        'request_id': 'request-1',
      };
      final frame = FEngineFrameCodec.encode(message);
      final decoder = FEngineFrameDecoder();

      expect(decoder.add(frame.sublist(0, 2)), isEmpty);
      expect(decoder.add(frame.sublist(2, 7)), isEmpty);
      expect(decoder.add(frame.sublist(7)), <Map<String, Object?>>[message]);
      decoder.close();
    });

    test('returns every complete frame from one input chunk', () {
      const first = <String, Object?>{'type': 'event', 'sequence': 1};
      const second = <String, Object?>{'type': 'event', 'sequence': 2};
      final bytes = Uint8List.fromList(<int>[
        ...FEngineFrameCodec.encode(first),
        ...FEngineFrameCodec.encode(second),
      ]);
      final decoder = FEngineFrameDecoder();

      expect(decoder.add(bytes), <Map<String, Object?>>[first, second]);
      decoder.close();
    });

    test('rejects a zero-length payload', () {
      final decoder = FEngineFrameDecoder();

      expect(
        () => decoder.add(const <int>[0, 0, 0, 0]),
        throwsA(isA<FEngineZeroLengthFrameException>()),
      );
    });

    test('rejects a payload larger than 16 MiB from its header', () {
      final decoder = FEngineFrameDecoder();
      final oversizedLength = fengineMaximumFramePayloadLength + 1;
      final header = ByteData(4)..setUint32(0, oversizedLength);

      expect(
        () => decoder.add(header.buffer.asUint8List()),
        throwsA(
          isA<FEngineFrameTooLargeException>()
              .having(
                (error) => error.payloadLength,
                'payloadLength',
                oversizedLength,
              )
              .having(
                (error) => error.maximumPayloadLength,
                'maximumPayloadLength',
                fengineMaximumFramePayloadLength,
              ),
        ),
      );
    });

    test('reports a truncated header when the input ends', () {
      final decoder = FEngineFrameDecoder()..add(const <int>[0, 0]);

      expect(decoder.close, throwsA(isA<FEngineTruncatedFrameException>()));
    });

    test('reports a truncated payload when the input ends', () {
      final decoder = FEngineFrameDecoder()
        ..add(const <int>[0, 0, 0, 3, 0x7b, 0x7d]);

      expect(
        decoder.close,
        throwsA(
          isA<FEngineTruncatedFrameException>()
              .having((error) => error.expectedBytes, 'expectedBytes', 3)
              .having((error) => error.receivedBytes, 'receivedBytes', 2),
        ),
      );
    });

    test('rejects a payload that is not valid UTF-8', () {
      final decoder = FEngineFrameDecoder();

      expect(
        () => decoder.add(const <int>[0, 0, 0, 2, 0xc3, 0x28]),
        throwsA(isA<FEngineInvalidUtf8Exception>()),
      );
    });

    test('rejects malformed JSON', () {
      final decoder = FEngineFrameDecoder();

      expect(
        () => decoder.add(const <int>[0, 0, 0, 1, 0x7b]),
        throwsA(isA<FEngineInvalidJsonException>()),
      );
    });

    test('rejects valid JSON that is not an object', () {
      final decoder = FEngineFrameDecoder();

      expect(
        () => decoder.add(const <int>[0, 0, 0, 2, 0x5b, 0x5d]),
        throwsA(isA<FEngineNonObjectJsonException>()),
      );
    });
  });
}
