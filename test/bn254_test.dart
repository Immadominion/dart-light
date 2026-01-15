import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('BN254', () {
    test('should create from bytes', () {
      final bytes = Uint8List(32);
      bytes[31] = 100;
      final bn = BN254.fromBytes(bytes);
      expect(bn.bytes.length, equals(32));
      expect(bn.bytes[31], equals(100));
    });

    test('should create from BigInt', () {
      final bn = BN254.fromBigInt(BigInt.from(100));
      expect(bn.bytes[31], equals(100));
      expect(bn.bytes[0], equals(0)); // Padded with zeros
    });

    test('should create from base58', () {
      // A known base58 encoded value
      final base58 = '11111111111111111111111111111112j';
      final bn = BN254.fromBase58(base58);
      expect(bn.bytes.length, equals(32));
    });

    test('should convert to base58', () {
      final bytes = Uint8List(32);
      bytes[31] = 100;
      final bn = BN254.fromBytes(bytes);
      final base58 = bn.toBase58();
      expect(base58.isNotEmpty, isTrue);
    });

    test('should roundtrip through base58', () {
      final original = Uint8List(32);
      original[0] = 1;
      original[15] = 128;
      original[31] = 255;
      final bn = BN254.fromBytes(original);
      final base58 = bn.toBase58();
      final restored = BN254.fromBase58(base58);
      expect(restored.bytes, equals(original));
    });

    test('field size constant should be correct', () {
      // The BN254 field size as BigInt
      final expectedFieldSize = BigInt.parse(
        '21888242871839275222246405745257275088548364400416034343698204186575808495617',
      );
      expect(BN254.fieldSize, equals(expectedFieldSize));
    });

    test('zero constant should be all zeros', () {
      expect(BN254.zero.bytes, equals(Uint8List(32)));
    });

    test('isZero should return true for zero', () {
      expect(BN254.zero.isZero, isTrue);
    });

    test('isZero should return false for non-zero', () {
      final bytes = Uint8List(32);
      bytes[31] = 1;
      final bn = BN254.fromBytes(bytes);
      expect(bn.isZero, isFalse);
    });

    test('equality should work', () {
      final bytes1 = Uint8List(32);
      bytes1[31] = 100;
      final bn1 = BN254.fromBytes(bytes1);

      final bytes2 = Uint8List(32);
      bytes2[31] = 100;
      final bn2 = BN254.fromBytes(bytes2);

      expect(bn1, equals(bn2));
    });

    test('inequality should work', () {
      final bytes1 = Uint8List(32);
      bytes1[31] = 100;
      final bn1 = BN254.fromBytes(bytes1);

      final bytes2 = Uint8List(32);
      bytes2[31] = 101;
      final bn2 = BN254.fromBytes(bytes2);

      expect(bn1, isNot(equals(bn2)));
    });

    test('should throw for invalid length', () {
      expect(
        () => BN254.fromBytes(Uint8List(31)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
