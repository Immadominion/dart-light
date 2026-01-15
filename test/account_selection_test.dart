import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('selectMinCompressedSolAccountsForTransfer', () {
    CompressedAccount createAccount(BigInt lamports, int leafIndex) {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );

      return CompressedAccount(
        owner: owner,
        lamports: lamports,
        hash: BN254.zero,
        treeInfo: treeInfo,
        leafIndex: leafIndex,
      );
    }

    test('should select single account when sufficient', () {
      final accounts = [
        createAccount(BigInt.from(1000000000), 0), // 1 SOL
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(500000000), // 0.5 SOL
      );

      expect(selected.length, equals(1));
      expect(total, equals(BigInt.from(1000000000)));
    });

    test('should select multiple accounts when needed', () {
      final accounts = [
        createAccount(BigInt.from(100000000), 0), // 0.1 SOL
        createAccount(BigInt.from(200000000), 1), // 0.2 SOL
        createAccount(BigInt.from(300000000), 2), // 0.3 SOL
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(400000000), // 0.4 SOL
      );

      // Should select largest first (0.3 + 0.2)
      expect(selected.length, equals(2));
      expect(total, equals(BigInt.from(500000000)));
    });

    test('should throw when insufficient balance', () {
      final accounts = [createAccount(BigInt.from(100000000), 0)];

      expect(
        () => selectMinCompressedSolAccountsForTransfer(
          accounts,
          BigInt.from(200000000),
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });

    test('should select exactly needed amount', () {
      final accounts = [
        createAccount(BigInt.from(100000000), 0),
        createAccount(BigInt.from(200000000), 1),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(200000000),
      );

      // Should only select the 0.2 SOL account (largest first)
      expect(selected.length, equals(1));
      expect(total, equals(BigInt.from(200000000)));
    });

    test('should prefer larger accounts', () {
      final accounts = [
        createAccount(BigInt.from(100), 0),
        createAccount(BigInt.from(1000), 1),
        createAccount(BigInt.from(10), 2),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(500),
      );

      // Should select the 1000 lamport account first
      expect(selected.length, equals(1));
      expect(selected.first.lamports, equals(BigInt.from(1000)));
      expect(total, equals(BigInt.from(1000)));
    });
  });

  group('selectMinCompressedTokenAccountsForTransfer', () {
    test('should select based on custom getter', () {
      final amounts = [BigInt.from(100), BigInt.from(500), BigInt.from(200)];

      final (selected, total) = selectMinCompressedTokenAccountsForTransfer(
        amounts,
        BigInt.from(400),
        (amount) => amount,
      );

      // Should select 500 (largest)
      expect(selected.length, equals(1));
      expect(total, equals(BigInt.from(500)));
    });
  });
}
