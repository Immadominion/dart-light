import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('Address Derivation', () {
    // Test vectors from TypeScript SDK (Rust compatibility)
    final programId = Ed25519HDPublicKey.fromBase58(
      '7yucc7fL3JGbyMwg4neUaenNSdySS39hbAk89Ao3t1Hz',
    );
    final addressTreePubkey = Ed25519HDPublicKey(Uint8List(32));

    final testCases = [
      (
        name: '["foo", "bar"]',
        seeds: ['foo', 'bar'],
        expectedSeed: Uint8List.fromList([
          0,
          177,
          134,
          198,
          24,
          76,
          116,
          207,
          56,
          127,
          189,
          181,
          87,
          237,
          154,
          181,
          246,
          54,
          131,
          21,
          150,
          248,
          106,
          75,
          26,
          80,
          147,
          245,
          3,
          23,
          136,
          56,
        ]),
        expectedAddress: Uint8List.fromList([
          0,
          16,
          227,
          141,
          38,
          32,
          23,
          82,
          252,
          50,
          202,
          3,
          183,
          186,
          236,
          133,
          86,
          112,
          59,
          23,
          128,
          162,
          11,
          84,
          91,
          127,
          179,
          208,
          25,
          178,
          1,
          240,
        ]),
      ),
      (
        name: '["ayy", "lmao"]',
        seeds: ['ayy', 'lmao'],
        expectedSeed: Uint8List.fromList([
          0,
          224,
          206,
          65,
          137,
          189,
          70,
          157,
          163,
          133,
          247,
          140,
          198,
          252,
          169,
          250,
          18,
          18,
          16,
          189,
          164,
          131,
          225,
          113,
          197,
          225,
          64,
          81,
          175,
          154,
          221,
          28,
        ]),
        expectedAddress: Uint8List.fromList([
          0,
          226,
          28,
          142,
          199,
          153,
          126,
          212,
          37,
          54,
          82,
          232,
          244,
          161,
          108,
          12,
          67,
          84,
          111,
          66,
          107,
          111,
          8,
          126,
          153,
          233,
          239,
          192,
          83,
          117,
          25,
          6,
        ]),
      ),
    ];

    group('deriveAddressSeedV2', () {
      for (final testCase in testCases) {
        test('should derive seed for ${testCase.name}', () {
          final seedBytes =
              testCase.seeds
                  .map((s) => Uint8List.fromList(s.codeUnits))
                  .toList();

          final addressSeed = deriveAddressSeedV2(seedBytes);

          expect(addressSeed, equals(testCase.expectedSeed));
        });
      }
    });

    group('deriveAddressV2', () {
      for (final testCase in testCases) {
        test('should derive address for ${testCase.name}', () {
          final seedBytes =
              testCase.seeds
                  .map((s) => Uint8List.fromList(s.codeUnits))
                  .toList();

          final addressSeed = deriveAddressSeedV2(seedBytes);
          expect(addressSeed, equals(testCase.expectedSeed));

          final derivedAddress = deriveAddressV2(
            addressSeed: addressSeed,
            addressMerkleTreePubkey: addressTreePubkey,
            programId: programId,
          );

          expect(
            Uint8List.fromList(derivedAddress.bytes),
            equals(testCase.expectedAddress),
          );
        });
      }
    });
  });

  group('hashvToBn254FieldSizeBe', () {
    test('should set first byte to zero', () {
      final input = [
        Uint8List.fromList([1, 2, 3, 4]),
      ];
      final result = hashvToBn254FieldSizeBe(input);

      expect(result.length, equals(32));
      expect(result[0], equals(0)); // First byte is zeroed
    });

    test('should be deterministic', () {
      final input = [
        Uint8List.fromList([1, 2, 3, 4]),
      ];
      final result1 = hashvToBn254FieldSizeBe(input);
      final result2 = hashvToBn254FieldSizeBe(input);

      expect(result1, equals(result2));
    });

    test('should produce different results for different inputs', () {
      final input1 = [
        Uint8List.fromList([1, 2, 3, 4]),
      ];
      final input2 = [
        Uint8List.fromList([1, 2, 3, 5]),
      ];

      final result1 = hashvToBn254FieldSizeBe(input1);
      final result2 = hashvToBn254FieldSizeBe(input2);

      expect(result1, isNot(equals(result2)));
    });
  });

  group('deriveAddress', () {
    test('should throw for invalid seed length', () {
      expect(
        () => deriveAddress(seed: Uint8List(31)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should use default tree if not specified', () {
      final seed = Uint8List(32);
      seed[0] = 1;

      // Should not throw
      final address = deriveAddress(seed: seed);
      expect(address.bytes.length, equals(32));
    });

    test('should produce 32-byte address', () {
      final seed = Uint8List(32);
      seed[0] = 42;

      final address = deriveAddress(seed: seed);
      expect(address.bytes.length, equals(32));
    });
  });
}
