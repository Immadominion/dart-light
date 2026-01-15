import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('Validation', () {
    group('validateSameOwner', () {
      CompressedAccount createAccount(Ed25519HDPublicKey owner) {
        final treeInfo = TreeInfo(
          tree: owner,
          queue: owner,
          treeType: TreeType.stateV1,
        );
        return CompressedAccount(
          owner: owner,
          lamports: BigInt.from(1000000),
          hash: BN254.zero,
          treeInfo: treeInfo,
          leafIndex: 0,
        );
      }

      test('should pass for empty list', () {
        expect(() => validateSameOwner([]), returnsNormally);
      });

      test('should pass for single account', () {
        final owner = Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        );
        final accounts = [createAccount(owner)];
        expect(() => validateSameOwner(accounts), returnsNormally);
      });

      test('should pass for multiple accounts with same owner', () {
        final owner = Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        );
        final accounts = [
          createAccount(owner),
          createAccount(owner),
          createAccount(owner),
        ];
        expect(() => validateSameOwner(accounts), returnsNormally);
      });

      test('should throw for accounts with different owners', () {
        final owner1 = Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        );
        final owner2 = Ed25519HDPublicKey.fromBase58(
          '7yucc7fL3JGbyMwg4neUaenNSdySS39hbAk89Ao3t1Hz',
        );
        final accounts = [createAccount(owner1), createAccount(owner2)];

        expect(
          () => validateSameOwner(accounts),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('validateSufficientBalance', () {
      test('should pass for positive balance', () {
        expect(
          () => validateSufficientBalance(BigInt.from(1000000)),
          returnsNormally,
        );
      });

      test('should pass for zero balance', () {
        expect(() => validateSufficientBalance(BigInt.zero), returnsNormally);
      });

      test('should throw for negative balance', () {
        expect(
          () => validateSufficientBalance(BigInt.from(-1)),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('validateLamports', () {
      test('should pass for valid lamports', () {
        expect(
          () => validateLamports(BigInt.from(1000000000)),
          returnsNormally,
        );
      });

      test('should pass for zero', () {
        expect(() => validateLamports(BigInt.zero), returnsNormally);
      });

      test('should throw for negative', () {
        expect(
          () => validateLamports(BigInt.from(-1)),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw for exceeding u64 max', () {
        final tooBig = BigInt.parse('18446744073709551616'); // 2^64
        expect(() => validateLamports(tooBig), throwsA(isA<ArgumentError>()));
      });
    });

    group('validateAddress', () {
      test('should pass for null address', () {
        expect(() => validateAddress(null), returnsNormally);
      });

      test('should pass for 32-byte address', () {
        final address = List<int>.filled(32, 0);
        expect(() => validateAddress(address), returnsNormally);
      });

      test('should throw for short address', () {
        final address = List<int>.filled(31, 0);
        expect(() => validateAddress(address), throwsA(isA<ArgumentError>()));
      });

      test('should throw for long address', () {
        final address = List<int>.filled(33, 0);
        expect(() => validateAddress(address), throwsA(isA<ArgumentError>()));
      });
    });
  });
}
