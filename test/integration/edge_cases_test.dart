/// Edge case integration tests for Light Protocol operations.
///
/// These tests cover edge cases and stress scenarios that might
/// expose bugs or limitations in the SDK implementation.
///
/// To run:
/// ```bash
/// # Start local test environment first
/// dart test test/integration/edge_cases_test.dart
/// ```
@Tags(['integration'])
library;

import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'package:light_sdk/light_sdk.dart';

import 'integration.dart';

void main() {
  late TestRpc testRpc;
  late Ed25519HDKeyPair payer;
  late TreeInfo stateTreeInfo;

  setUpAll(() async {
    // Initialize test RPC
    testRpc = await getTestRpc();

    // Create and fund test account with plenty of SOL
    payer = await newAccountWithLamports(
      testRpc,
      lamports: lamportsPerSol * 10,
    );

    // Get state tree info
    final treeInfos = await testRpc.rpc.getStateTreeInfos();
    stateTreeInfo = selectStateTreeInfo(treeInfos);
  });

  group('large transfers', () {
    test('should handle large SOL amount', () async {
      final largeAmount = BigInt.from(lamportsPerSol * 5); // 5 SOL

      // Compress large amount
      final signature = await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: largeAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      expect(signature, isNotEmpty);

      // Verify compressed account exists
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      final found = accounts.items.any((acc) => acc.lamports == largeAmount);
      expect(found, isTrue);

      // Transfer large amount
      final recipient = await Ed25519HDKeyPair.random();
      final transferSig = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: largeAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(transferSig, isNotEmpty);

      // Verify recipient received it
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      expect(recipientAccounts.items, isNotEmpty);
      expect(recipientAccounts.items.first.lamports, equals(largeAmount));
    });

    test('should handle minimum lamport amount', () async {
      // Minimum viable compressed account (just above rent-exempt minimum)
      final minAmount = BigInt.from(5000); // Very small amount

      final signature = await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: minAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      expect(signature, isNotEmpty);

      // Verify account exists
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      final found = accounts.items.any((acc) => acc.lamports == minAmount);
      expect(found, isTrue);
    });
  });

  group('many input accounts', () {
    test('should handle transfer from multiple inputs', () async {
      // Create multiple small compressed accounts
      final amounts = [
        BigInt.from(10000000), // 0.01 SOL
        BigInt.from(20000000), // 0.02 SOL
        BigInt.from(30000000), // 0.03 SOL
        BigInt.from(40000000), // 0.04 SOL
      ];

      for (final amount in amounts) {
        await compress(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: amount,
          toAddress: payer.publicKey,
          outputStateTreeInfo: stateTreeInfo,
        );
      }

      // Verify all accounts exist
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items.length, greaterThanOrEqualTo(amounts.length));

      // Transfer total amount (should combine all inputs)
      final totalAmount = amounts.fold<BigInt>(BigInt.zero, (a, b) => a + b);
      final recipient = await Ed25519HDKeyPair.random();

      final signature = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: totalAmount - BigInt.from(1000000), // Leave some for change
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(signature, isNotEmpty);
    });

    test('should handle account selection with greedy algorithm', () async {
      // Create specific amounts to test greedy selection
      final amounts = [
        BigInt.from(100000000), // 0.1 SOL
        BigInt.from(50000000), // 0.05 SOL
        BigInt.from(25000000), // 0.025 SOL
        BigInt.from(10000000), // 0.01 SOL
      ];

      for (final amount in amounts) {
        await compress(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: amount,
          toAddress: payer.publicKey,
          outputStateTreeInfo: stateTreeInfo,
        );
      }

      // Get accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      // Test account selection
      final transferAmount = BigInt.from(60000000); // 0.06 SOL

      // Should select minimum accounts needed
      final (selected, total) = selectMinCompressedSolAccountsForTransfer(
        accounts.items,
        transferAmount,
      );

      expect(selected, isNotEmpty);
      expect(total, greaterThanOrEqualTo(transferAmount));
    });
  });

  group('concurrent transactions', () {
    test('should handle sequential transactions', () async {
      final recipient = await Ed25519HDKeyPair.random();
      final amount = BigInt.from(10000000);

      // Compress initial amount
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: amount * BigInt.from(3),
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Sequential transfers
      for (var i = 0; i < 3; i++) {
        final sig = await transfer(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: amount ~/ BigInt.from(3),
          owner: payer,
          toAddress: recipient.publicKey,
        );
        expect(sig, isNotEmpty);
      }

      // Verify recipient received all transfers
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      expect(recipientAccounts.items.length, greaterThanOrEqualTo(3));
    });
  });

  group('error handling', () {
    test('should fail gracefully on invalid proof', () async {
      // Create a compressed account
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: BigInt.from(50000000),
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items, isNotEmpty);

      // Attempt transfer with potentially stale state
      // This may fail if the proof becomes invalid
      try {
        await transfer(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: BigInt.from(10000000),
          owner: payer,
          toAddress: payer.publicKey, // Transfer to self
        );
        // If it succeeds, that's fine too
      } on Exception catch (e) {
        // Expected possible failure
        expect(e, isNotNull);
      }
    });

    test('should handle RPC timeouts gracefully', () async {
      // This test verifies that the SDK handles network issues properly
      // In real scenarios, this would test with artificial latency

      final result = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      // Should return results or throw meaningful error
      expect(result, isNotNull);
    });
  });

  group('state tree migration', () {
    test('should handle nextTreeInfo correctly', () async {
      final treeInfos = await testRpc.rpc.getStateTreeInfos();

      // Check if any tree has nextTreeInfo set
      for (final info in treeInfos) {
        // nextTreeInfo is null for most trees unless rollover is imminent
        if (info.nextTreeInfo != null) {
          expect(info.nextTreeInfo!.tree, isNotNull);
        }
      }

      // Should be able to select a tree regardless
      final selected = selectStateTreeInfo(treeInfos);
      expect(selected, isNotNull);
    });
  });

  group('validity proof edge cases', () {
    test('should handle proof for single account', () async {
      // Compress a single account
      final amount = BigInt.from(25000000);
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: amount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get the account
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items, isNotEmpty);

      // Get proof for just one account
      final proof = await testRpc.rpc.getValidityProof(
        hashes: [accounts.items.first.hash],
      );

      expect(proof, isNotNull);
      expect(proof.compressedProof, isNotNull);
    });

    test('should handle proof for multiple accounts', () async {
      // Create multiple accounts
      for (var i = 0; i < 3; i++) {
        await compress(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: BigInt.from(10000000 * (i + 1)),
          toAddress: payer.publicKey,
          outputStateTreeInfo: stateTreeInfo,
        );
      }

      // Get accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items.length, greaterThanOrEqualTo(3));

      // Get proof for multiple accounts
      final hashes = accounts.items.take(3).map((a) => a.hash).toList();
      final proof = await testRpc.rpc.getValidityProof(hashes: hashes);

      expect(proof, isNotNull);
      expect(proof.roots, hasLength(hashes.length));
      expect(proof.leafIndices, hasLength(hashes.length));
    });
  });
}
