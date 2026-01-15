/// Integration tests for compressed SOL transfer operations.
///
/// These tests require a local Solana validator with Light Protocol programs
/// deployed, along with Photon indexer and prover services.
///
/// To run:
/// ```bash
/// # Start local test environment first
/// dart test test/integration/transfer_test.dart
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
    payer = await newAccountWithLamports(testRpc, lamports: lamportsPerSol * 2);

    // Get state tree info
    final treeInfos = await testRpc.rpc.getStateTreeInfos();
    stateTreeInfo = selectStateTreeInfo(treeInfos);

    // Pre-compress some SOL for transfer tests
    await compress(
      rpc: testRpc.rpc,
      payer: payer,
      lamports: BigInt.from(lamportsPerSol), // 1 SOL
      toAddress: payer.publicKey,
      outputStateTreeInfo: stateTreeInfo,
    );
  });

  group('transfer compressed SOL', () {
    test('should transfer compressed SOL to new recipient', () async {
      final recipient = await TestKeypairs.bob;
      final transferAmount = BigInt.from(100000000); // 0.1 SOL

      // Get pre-transfer balances
      final payerAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );
      expect(payerAccounts.items, isNotEmpty);

      final payerPreBalance = payerAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );

      // Transfer
      final signature = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: transferAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify recipient has compressed account
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      expect(recipientAccounts.items, isNotEmpty);

      final recipientBalance = recipientAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );
      expect(recipientBalance, greaterThanOrEqualTo(transferAmount));

      // Verify payer balance decreased
      final payerPostAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      final payerPostBalance = payerPostAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );

      expect(payerPostBalance, lessThan(payerPreBalance));
    });

    test('should transfer exact amount with no change', () async {
      final recipient = await TestKeypairs.charlie;

      // First compress exact amount
      final exactAmount = BigInt.from(50000000); // 0.05 SOL
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: exactAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get payer accounts before transfer
      final preAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      // Find the account with exact amount
      final sourceAccount = preAccounts.items.firstWhere(
        (acc) => acc.lamports == exactAmount,
        orElse: () => throw Exception('Source account not found'),
      );

      expect(sourceAccount.lamports, equals(exactAmount));

      // Transfer exact amount - should not create change
      final signature = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: exactAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify recipient received the amount
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      final received = recipientAccounts.items.any(
        (acc) => acc.lamports == exactAmount,
      );
      expect(received, isTrue);
    });

    test('should handle transfer with change correctly', () async {
      final recipient = await TestKeypairs.dave;
      final sourceAmount = BigInt.from(200000000); // 0.2 SOL
      final transferAmount = BigInt.from(75000000); // 0.075 SOL

      // Compress source amount
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: sourceAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Transfer partial amount
      final signature = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: transferAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify recipient got transfer amount
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      final received = recipientAccounts.items.any(
        (acc) => acc.lamports == transferAmount,
      );
      expect(received, isTrue);

      // Verify payer has change account
      final payerAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      // Change should be sourceAmount - transferAmount (minus fees)
      final expectedChange = sourceAmount - transferAmount;
      final hasChange = payerAccounts.items.any(
        (acc) => acc.lamports <= expectedChange && acc.lamports > BigInt.zero,
      );
      expect(hasChange, isTrue);
    });

    test('should transfer from multiple input accounts', () async {
      final recipient = await Ed25519HDKeyPair.random();
      final amount1 = BigInt.from(100000000); // 0.1 SOL
      final amount2 = BigInt.from(150000000); // 0.15 SOL

      // Compress two separate amounts
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: amount1,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: amount2,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Transfer combined amount (should use both inputs)
      final transferAmount =
          amount1 + amount2 - BigInt.from(10000000); // Leave some for change

      final signature = await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: transferAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      expect(signature, isNotEmpty);

      // Verify recipient received the full amount
      final recipientAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        recipient.publicKey,
      );

      final recipientBalance = recipientAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );
      expect(recipientBalance, equals(transferAmount));
    });

    test('should fail on insufficient balance', () async {
      final recipient = await Ed25519HDKeyPair.random();

      // Try to transfer more than available
      final hugeAmount = BigInt.from(1000000000000); // 1000 SOL

      expect(
        () => transfer(
          rpc: testRpc.rpc,
          payer: payer,
          lamports: hugeAmount,
          owner: payer,
          toAddress: recipient.publicKey,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });
  });

  group('transfer fee calculation', () {
    test('should deduct correct fees for transfer', () async {
      final recipient = await Ed25519HDKeyPair.random();
      final compressAmount = BigInt.from(100000000); // 0.1 SOL
      final transferAmount = BigInt.from(50000000); // 0.05 SOL

      // Compress fresh amount
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get pre-transfer compressed balance
      final preAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );
      final preBalance = preAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );

      // Transfer
      await transfer(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: transferAmount,
        owner: payer,
        toAddress: recipient.publicKey,
      );

      // Get post-transfer compressed balance (payer only)
      final postAccounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );
      final postBalance = postAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.lamports,
      );

      // Calculate expected fees (1 input, 2 outputs: recipient + change)
      final expectedFees = calculateExpectedFees([
        TxFeeParams(inputs: 1, outputs: 2),
      ]);

      // Change should be: preBalance - transferAmount - fees
      final expectedChange = preBalance - transferAmount - expectedFees;

      // Allow for small variance due to state tree fees
      expect(
        (postBalance - expectedChange).abs(),
        lessThan(BigInt.from(100000)), // 0.0001 SOL tolerance
      );
    });
  });
}
