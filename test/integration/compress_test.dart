/// Integration tests for compress and decompress operations.
///
/// These tests require a local Solana validator with Light Protocol programs
/// deployed, along with Photon indexer and prover services.
///
/// To run:
/// ```bash
/// # Start local test environment first
/// dart test test/integration/compress_test.dart
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

    // Create and fund test account
    payer = await newAccountWithLamports(testRpc, lamports: lamportsPerSol);

    // Get state tree info
    final treeInfos = await testRpc.rpc.getStateTreeInfos();
    stateTreeInfo = selectStateTreeInfo(treeInfos);
  });

  group('compress SOL', () {
    test('should compress SOL to new compressed account', () async {
      final compressAmount = BigInt.from(100000000); // 0.1 SOL

      // Get balance before compress
      final preBalance = await getBalance(testRpc, payer.publicKey);

      // Compress SOL
      final signature = await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      expect(signature, isNotEmpty);

      // Verify balance decreased
      final postBalance = await getBalance(testRpc, payer.publicKey);
      expect(postBalance, lessThan(preBalance));

      // Get compressed accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items, isNotEmpty);

      // Find the compressed account with our amount
      final found = accounts.items.any((acc) => acc.lamports == compressAmount);
      expect(found, isTrue);
    });

    test('should compress SOL to different recipient', () async {
      final recipient = await TestKeypairs.bob;
      final compressAmount = BigInt.from(50000000); // 0.05 SOL

      // Compress to recipient
      final signature = await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: recipient.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      expect(signature, isNotEmpty);

      // Verify recipient has compressed account
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      expect(accounts.items, isNotEmpty);
      expect(accounts.items.first.lamports, equals(compressAmount));
    });

    test('should handle zero-slot compress correctly', () async {
      final compressAmount = BigInt.from(10000000); // 0.01 SOL

      final preSlot = await testRpc.getSlot();

      final signature = await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      expect(signature, isNotEmpty);

      final postSlot = await testRpc.getSlot();
      expect(postSlot, greaterThanOrEqualTo(preSlot));
    });
  });

  group('decompress SOL', () {
    test('should decompress SOL back to regular account', () async {
      // First compress some SOL
      final compressAmount = BigInt.from(200000000); // 0.2 SOL

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get compressed accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );
      expect(accounts.items, isNotEmpty);

      // Get pre-decompress balance
      final preBalance = await getBalance(testRpc, payer.publicKey);

      // Decompress
      final decompressAmount = accounts.items.first.lamports;
      final signature = await decompress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: decompressAmount,
        recipient: payer.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify balance increased
      final postBalance = await getBalance(testRpc, payer.publicKey);
      // Account for fees, but balance should increase significantly
      expect(
        postBalance,
        greaterThan(preBalance + decompressAmount.toInt() - 100000),
      );
    });

    test('should decompress partial amount', () async {
      // First compress some SOL
      final compressAmount = BigInt.from(300000000); // 0.3 SOL

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Decompress only half
      final decompressAmount = compressAmount ~/ BigInt.two;
      final signature = await decompress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: decompressAmount,
        recipient: payer.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify there's still a compressed account with remaining balance
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      // Should have change account
      final hasChange = accounts.items.any(
        (acc) => acc.lamports > BigInt.zero && acc.lamports < compressAmount,
      );
      expect(hasChange, isTrue);
    });

    test('should decompress to different recipient', () async {
      final recipient = await TestKeypairs.charlie;

      // First compress some SOL
      final compressAmount = BigInt.from(100000000); // 0.1 SOL

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get recipient pre-balance
      final preRecipientBalance = await getBalance(
        testRpc,
        recipient.publicKey,
      );

      // Decompress to recipient
      final signature = await decompress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount ~/ BigInt.two,
        recipient: recipient.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify recipient balance increased
      final postRecipientBalance = await getBalance(
        testRpc,
        recipient.publicKey,
      );
      expect(postRecipientBalance, greaterThan(preRecipientBalance));
    });
  });

  group('compress fee calculation', () {
    test('should deduct correct fees for compress', () async {
      final compressAmount = BigInt.from(100000000); // 0.1 SOL

      final preBalance = await getBalance(testRpc, payer.publicKey);

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      final postBalance = await getBalance(testRpc, payer.publicKey);

      // Calculate expected fees
      final expectedFees = calculateExpectedFees([
        TxFeeParams(inputs: 0, outputs: 1),
      ]);

      // Balance should be: preBalance - compressAmount - fees
      final actualDiff = preBalance - postBalance;
      final expectedDiff = compressAmount.toInt() + expectedFees.toInt();

      // Allow small variance for network fees
      expect(
        actualDiff,
        closeTo(expectedDiff, 10000), // 0.00001 SOL tolerance
      );
    });
  });
}
