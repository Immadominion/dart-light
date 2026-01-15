import 'package:test/test.dart';

import 'package:light_sdk/src/utils/account_selection.dart';
import 'package:light_sdk/src/state/compressed_account.dart';
import 'package:light_sdk/src/state/bn254.dart';
import 'package:light_sdk/src/state/tree_info.dart';
import 'package:solana/solana.dart';

void main() {
  group('Account Selection for SOL', () {
    test(
      'selectMinCompressedSolAccountsForTransfer selects minimum accounts',
      () {
        final accounts = [
          _createMockAccount(BigInt.from(500000000), 0), // 0.5 SOL
          _createMockAccount(BigInt.from(300000000), 1), // 0.3 SOL
          _createMockAccount(BigInt.from(200000000), 2), // 0.2 SOL
          _createMockAccount(BigInt.from(100000000), 3), // 0.1 SOL
        ];

        final (selected, total) = selectMinCompressedSolAccountsForTransfer(
          accounts,
          BigInt.from(600000000), // Need 0.6 SOL
        );

        // Should select the 0.5 SOL + 0.3 SOL = 0.8 SOL accounts (greedy algorithm)
        expect(selected.length, 2);
        expect(selected[0].lamports, BigInt.from(500000000));
        expect(selected[1].lamports, BigInt.from(300000000));
        expect(total, BigInt.from(800000000));
      },
    );

    test('throws InsufficientBalanceException when insufficient balance', () {
      final accounts = [
        _createMockAccount(BigInt.from(100000000), 0), // 0.1 SOL
        _createMockAccount(BigInt.from(50000000), 1), // 0.05 SOL
      ];

      expect(
        () => selectMinCompressedSolAccountsForTransfer(
          accounts,
          BigInt.from(1000000000), // Need 1 SOL (more than available)
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });

    test('handles exact amount match', () {
      final accounts = [
        _createMockAccount(BigInt.from(500000000), 0),
        _createMockAccount(BigInt.from(500000000), 1),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(500000000), // Exactly one account
      );

      expect(selected.length, 1);
      expect(selected[0].lamports, BigInt.from(500000000));
      expect(total, BigInt.from(500000000));
    });

    test('sorts accounts by largest first (greedy algorithm)', () {
      final accounts = [
        _createMockAccount(BigInt.from(100000000), 0),
        _createMockAccount(BigInt.from(1000000000), 1),
        _createMockAccount(BigInt.from(500000000), 2),
        _createMockAccount(BigInt.from(200000000), 3),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(600000000),
      );

      // Should select 1 SOL account (greedy - largest first)
      expect(selected.length, 1);
      expect(selected[0].lamports, BigInt.from(1000000000));
      expect(total, BigInt.from(1000000000));
    });

    test('accumulates accounts until sufficient balance', () {
      final accounts = [
        _createMockAccount(BigInt.from(300000000), 0),
        _createMockAccount(BigInt.from(250000000), 1),
        _createMockAccount(BigInt.from(200000000), 2),
        _createMockAccount(BigInt.from(150000000), 3),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(650000000), // Need 0.65 SOL
      );

      // Should select: 0.3 + 0.25 + 0.2 = 0.75 SOL (3 accounts)
      expect(selected.length, 3);
      expect(total, BigInt.from(750000000));
      expect(total >= BigInt.from(650000000), true);
    });

    test('throws on empty account list', () {
      expect(
        () => selectMinCompressedSolAccountsForTransfer([], BigInt.from(1000)),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });

    test('handles single account with exact balance', () {
      final accounts = [_createMockAccount(BigInt.from(1000000000), 0)];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(1000000000),
      );

      expect(selected.length, 1);
      expect(total, BigInt.from(1000000000));
    });

    test('selects all accounts when needed for total', () {
      final accounts = [
        _createMockAccount(BigInt.from(100000000), 0),
        _createMockAccount(BigInt.from(200000000), 1),
        _createMockAccount(BigInt.from(300000000), 2),
      ];

      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts,
        BigInt.from(550000000), // Need 0.55 SOL
      );

      expect(selected.length, 3);
      expect(total, BigInt.from(600000000));
    });
  });

  group('Account Selection for Tokens', () {
    test(
      'selectMinCompressedTokenAccountsForTransfer works with token amount getter',
      () {
        final tokenAccounts = [
          _MockTokenAccount(amount: BigInt.from(1000)),
          _MockTokenAccount(amount: BigInt.from(500)),
          _MockTokenAccount(amount: BigInt.from(250)),
        ];

        final (selected, total) = selectMinCompressedTokenAccountsForTransfer(
          tokenAccounts,
          BigInt.from(1200),
          (account) => account.amount,
        );

        expect(selected.length, 2);
        expect(total, BigInt.from(1500));
      },
    );

    test('throws InsufficientBalanceException for tokens', () {
      final tokenAccounts = [_MockTokenAccount(amount: BigInt.from(100))];

      expect(
        () => selectMinCompressedTokenAccountsForTransfer(
          tokenAccounts,
          BigInt.from(1000),
          (account) => account.amount,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });
  });

  group('InsufficientBalanceException', () {
    test('has correct message format', () {
      final exception = InsufficientBalanceException(
        required: BigInt.from(1000000000),
        available: BigInt.from(500000000),
      );

      expect(exception.toString(), contains('Required 1000000000'));
      expect(exception.toString(), contains('available 500000000'));
    });

    test('stores required and available amounts', () {
      final exception = InsufficientBalanceException(
        required: BigInt.from(100),
        available: BigInt.from(50),
      );

      expect(exception.required, BigInt.from(100));
      expect(exception.available, BigInt.from(50));
    });
  });
}

/// Creates a mock compressed account for testing.
CompressedAccountWithMerkleContext _createMockAccount(
  BigInt lamports,
  int leafIndex,
) {
  return createCompressedAccountWithMerkleContext(
    owner: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111115'),
    lamports: lamports,
    hash: BN254.fromBigInt(
      BigInt.from(12345 + leafIndex),
    ), // Unique hash per account
    treeInfo: TreeInfo(
      tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111112'),
      queue: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111113'),
      cpiContext: Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111114',
      ),
      treeType: TreeType.stateV1,
    ),
    leafIndex: leafIndex,
  );
}

/// Simple mock token account for testing token selection.
class _MockTokenAccount {
  _MockTokenAccount({required this.amount});
  final BigInt amount;
}
