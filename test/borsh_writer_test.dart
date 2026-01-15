import 'package:light_sdk/src/utils/borsh.dart';
import 'package:test/test.dart';

void main() {
  group('BorshWriter signed integers', () {
    test('encodes i8 two\'s complement', () {
      final writer =
          BorshWriter()
            ..writeI8(-1)
            ..writeI8(0)
            ..writeI8(127)
            ..writeI8(-128);

      expect(writer.toBytes(), equals([0xFF, 0x00, 0x7F, 0x80]));
    });

    test('encodes i16 little-endian two\'s complement', () {
      final writer =
          BorshWriter()
            ..writeI16(-2)
            ..writeI16(0x7FFF)
            ..writeI16(-0x8000);

      expect(writer.toBytes(), equals([0xFE, 0xFF, 0xFF, 0x7F, 0x00, 0x80]));
    });

    test('encodes i32 little-endian two\'s complement', () {
      final writer =
          BorshWriter()
            ..writeI32(-1)
            ..writeI32(0x7FFFFFFF)
            ..writeI32(-0x80000000);

      expect(
        writer.toBytes(),
        equals([
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0x7F,
          0x00,
          0x00,
          0x00,
          0x80,
        ]),
      );
    });

    test('encodes i64 little-endian two\'s complement', () {
      final writer =
          BorshWriter()
            ..writeI64(BigInt.from(-1))
            ..writeI64(BigInt.from(1))
            ..writeI64(BigInt.from(-2));

      expect(
        writer.toBytes(),
        equals([
          // -1
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          // +1
          0x01,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          // -2
          0xFE,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
        ]),
      );
    });

    test('throws on out-of-range values', () {
      final writer = BorshWriter();

      expect(() => writer.writeI8(128), throwsA(isA<ArgumentError>()));
      expect(() => writer.writeI16(-0x8001), throwsA(isA<ArgumentError>()));
      expect(() => writer.writeI32(0x80000000), throwsA(isA<ArgumentError>()));
      expect(
        () => writer.writeI64(BigInt.one << 63),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => writer.writeI64(-(BigInt.one << 63) - BigInt.one),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('BorshWriter signed helpers', () {
    test('static helpers match writer outputs', () {
      final i64Positive = BorshWriter.i64(BigInt.from(42));
      final i64Negative = BorshWriter.i64(BigInt.from(-42));

      final writer =
          BorshWriter()
            ..writeI64(BigInt.from(42))
            ..writeI64(BigInt.from(-42));

      expect(writer.toBytes().sublist(0, 8), equals(i64Positive));
      expect(writer.toBytes().sublist(8), equals(i64Negative));
    });

    test('static helpers enforce ranges', () {
      expect(() => BorshWriter.i8(200), throwsA(isA<ArgumentError>()));
      expect(() => BorshWriter.i16(0x8000), throwsA(isA<ArgumentError>()));
      expect(() => BorshWriter.i32(-0x80000001), throwsA(isA<ArgumentError>()));
      expect(
        () => BorshWriter.i64(BigInt.from(1) << 63),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
