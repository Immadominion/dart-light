/// Integration tests for compressed token operations.
///
/// These tests require a local Solana validator with Light Protocol programs
/// deployed, along with Photon indexer and prover services.
///
/// To run:
/// ```bash
/// # Start local test environment first
/// dart test test/integration/token_test.dart
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
  late Ed25519HDKeyPair mintAuthority;
  late Ed25519HDPublicKey mint;
  late TreeInfo stateTreeInfo;
  late TokenPoolInfo tokenPoolInfo;

  setUpAll(() async {
    // Initialize test RPC
    testRpc = await getTestRpc();

    // Create and fund test accounts
    payer = await newAccountWithLamports(testRpc, lamports: lamportsPerSol * 5);
    mintAuthority = await newAccountWithLamports(
      testRpc,
      lamports: lamportsPerSol,
    );

    // Get state tree info
    final treeInfos = await testRpc.rpc.getStateTreeInfos();
    stateTreeInfo = selectStateTreeInfo(treeInfos);

    // Create a test mint and token pool for token operations
    final (mintPubkey, poolInfo) = await _createTestMintAndPool(
      testRpc,
      payer,
      mintAuthority,
    );
    mint = mintPubkey;
    tokenPoolInfo = poolInfo;
  });

  group('create token pool', () {
    test('should create SPL token pool for compression', () async {
      // Create a new mint for this test
      final testMintAuthority = await Ed25519HDKeyPair.random();
      await testRpc.requestAirdropAndConfirm(
        testMintAuthority.publicKey,
        lamportsPerSol,
      );

      final testMint = await _createTestMint(testRpc, payer, testMintAuthority);

      // Create token pool instruction (async)
      final createPoolIx = await CompressedTokenProgram.createSplInterface(
        feePayer: payer.publicKey,
        mint: testMint,
      );

      expect(createPoolIx, isNotNull);
      expect(createPoolIx.accounts, isNotEmpty);

      // Build and send transaction
      final signedTx = await buildAndSignTransaction(
        rpc: testRpc.rpc,
        signer: payer,
        instructions: [createPoolIx],
      );

      final signature = await sendAndConfirmTransaction(
        rpc: testRpc.rpc,
        signedTx: signedTx,
      );

      expect(signature, isNotEmpty);
    });
  });

  group('mint compressed tokens', () {
    test('should mint compressed tokens to recipient', () async {
      final recipient = await TestKeypairs.bob;
      final mintAmount = BigInt.from(1000000000); // 1 billion tokens

      // Mint tokens using proper API
      final mintToIx = CompressedTokenProgram.mintTo(
        feePayer: payer.publicKey,
        mint: mint,
        authority: mintAuthority.publicKey,
        outputStateTreeInfo: stateTreeInfo,
        tokenPoolInfo: tokenPoolInfo,
        recipients: [recipient.publicKey],
        amounts: [mintAmount],
      );

      final signedTx = await buildAndSignTransaction(
        rpc: testRpc.rpc,
        signer: payer,
        additionalSigners: [mintAuthority],
        instructions: [mintToIx],
      );

      final signature = await sendAndConfirmTransaction(
        rpc: testRpc.rpc,
        signedTx: signedTx,
      );

      expect(signature, isNotEmpty);

      // Verify recipient has compressed token account
      final tokenAccounts = await testRpc.rpc.getCompressedTokenAccountsByOwner(
        recipient.publicKey,
        mint: mint,
      );

      expect(tokenAccounts.items, isNotEmpty);

      final recipientBalance = tokenAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.parsed.amount,
      );
      expect(recipientBalance, equals(mintAmount));
    });

    test('should mint to multiple recipients', () async {
      final recipient1 = await TestKeypairs.charlie;
      final recipient2 = await TestKeypairs.dave;
      final amount1 = BigInt.from(500000000);
      final amount2 = BigInt.from(300000000);

      final mintToIx = CompressedTokenProgram.mintTo(
        feePayer: payer.publicKey,
        mint: mint,
        authority: mintAuthority.publicKey,
        outputStateTreeInfo: stateTreeInfo,
        tokenPoolInfo: tokenPoolInfo,
        recipients: [recipient1.publicKey, recipient2.publicKey],
        amounts: [amount1, amount2],
      );

      final signedTx = await buildAndSignTransaction(
        rpc: testRpc.rpc,
        signer: payer,
        additionalSigners: [mintAuthority],
        instructions: [mintToIx],
      );

      final signature = await sendAndConfirmTransaction(
        rpc: testRpc.rpc,
        signedTx: signedTx,
      );

      expect(signature, isNotEmpty);

      // Verify both recipients
      final accounts1 = await testRpc.rpc.getCompressedTokenAccountsByOwner(
        recipient1.publicKey,
        mint: mint,
      );
      final accounts2 = await testRpc.rpc.getCompressedTokenAccountsByOwner(
        recipient2.publicKey,
        mint: mint,
      );

      expect(accounts1.items, isNotEmpty);
      expect(accounts2.items, isNotEmpty);
    });
  });

  group('transfer compressed tokens', () {
    test('should transfer compressed tokens to recipient', () async {
      final sender = await newAccountWithLamports(
        testRpc,
        lamports: lamportsPerSol,
      );
      final recipient = await Ed25519HDKeyPair.random();
      final mintAmount = BigInt.from(1000000);
      final transferAmount = BigInt.from(400000);

      // Mint tokens to sender first
      final mintToIx = CompressedTokenProgram.mintTo(
        feePayer: payer.publicKey,
        mint: mint,
        authority: mintAuthority.publicKey,
        outputStateTreeInfo: stateTreeInfo,
        tokenPoolInfo: tokenPoolInfo,
        recipients: [sender.publicKey],
        amounts: [mintAmount],
      );

      var signedTx = await buildAndSignTransaction(
        rpc: testRpc.rpc,
        signer: payer,
        additionalSigners: [mintAuthority],
        instructions: [mintToIx],
      );

      await sendAndConfirmTransaction(rpc: testRpc.rpc, signedTx: signedTx);

      // Get sender's token accounts
      final senderAccounts = await testRpc.rpc
          .getCompressedTokenAccountsByOwner(sender.publicKey, mint: mint);
      expect(senderAccounts.items, isNotEmpty);

      // Get validity proof - use compressedAccount.hash for BN254 type
      final hashes =
          senderAccounts.items.map((a) => a.compressedAccount.hash).toList();
      final proof = await testRpc.rpc.getValidityProof(hashes: hashes);

      // Create transfer instruction
      final transferIx = CompressedTokenProgram.transfer(
        payer: sender.publicKey,
        inputCompressedTokenAccounts: senderAccounts.items,
        toAddress: recipient.publicKey,
        amount: transferAmount,
        recentInputStateRootIndices: proof.rootIndices,
        recentValidityProof: proof.compressedProof,
      );

      signedTx = await buildAndSignTransaction(
        rpc: testRpc.rpc,
        signer: sender,
        instructions: [transferIx],
      );

      final signature = await sendAndConfirmTransaction(
        rpc: testRpc.rpc,
        signedTx: signedTx,
      );

      expect(signature, isNotEmpty);

      // Verify recipient has tokens
      final recipientAccounts = await testRpc.rpc
          .getCompressedTokenAccountsByOwner(recipient.publicKey, mint: mint);

      expect(recipientAccounts.items, isNotEmpty);

      final recipientBalance = recipientAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.parsed.amount,
      );
      expect(recipientBalance, equals(transferAmount));

      // Verify sender has change
      final senderPostAccounts = await testRpc.rpc
          .getCompressedTokenAccountsByOwner(sender.publicKey, mint: mint);

      final senderBalance = senderPostAccounts.items.fold<BigInt>(
        BigInt.zero,
        (sum, acc) => sum + acc.parsed.amount,
      );
      expect(senderBalance, equals(mintAmount - transferAmount));
    });
  });

  group('compress/decompress tokens', () {
    test('should compress SPL tokens', () async {
      // This test requires an SPL token account with balance
      // Skipping for now as it requires additional setup
    }, skip: 'Requires SPL token account setup');

    test(
      'should decompress compressed tokens to SPL',
      () async {
        // This test requires compressed token account
        // Skipping for now as it requires additional setup
      },
      skip: 'Requires compressed token account setup',
    );
  });
}

/// Create a test SPL token mint.
Future<Ed25519HDPublicKey> _createTestMint(
  TestRpc testRpc,
  Ed25519HDKeyPair payer,
  Ed25519HDKeyPair mintAuthority,
) async {
  final mintKeypair = await Ed25519HDKeyPair.random();

  // Create mint account
  final createAccountIx = SystemInstruction.createAccount(
    fundingAccount: payer.publicKey,
    newAccount: mintKeypair.publicKey,
    lamports: await testRpc.rpcClient.getMinimumBalanceForRentExemption(82),
    space: 82,
    owner: Ed25519HDPublicKey.fromBase58(
      'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
    ),
  );

  // Initialize mint
  final initMintIx = TokenInstruction.initializeMint(
    mint: mintKeypair.publicKey,
    decimals: 9,
    mintAuthority: mintAuthority.publicKey,
    freezeAuthority: null,
  );

  final signedTx = await buildAndSignTransaction(
    rpc: testRpc.rpc,
    signer: payer,
    additionalSigners: [mintKeypair],
    instructions: [createAccountIx, initMintIx],
  );

  await sendAndConfirmTransaction(rpc: testRpc.rpc, signedTx: signedTx);

  return mintKeypair.publicKey;
}

/// Create a test SPL token mint and token pool.
Future<(Ed25519HDPublicKey, TokenPoolInfo)> _createTestMintAndPool(
  TestRpc testRpc,
  Ed25519HDKeyPair payer,
  Ed25519HDKeyPair mintAuthority,
) async {
  // Create mint
  final mint = await _createTestMint(testRpc, payer, mintAuthority);

  // Derive token pool PDA
  final splInterfacePda = await CompressedTokenProgram.deriveTokenPoolPda(
    mint: mint,
  );

  // Create token pool
  final createPoolIx = await CompressedTokenProgram.createSplInterface(
    feePayer: payer.publicKey,
    mint: mint,
  );

  final signedTx = await buildAndSignTransaction(
    rpc: testRpc.rpc,
    signer: payer,
    instructions: [createPoolIx],
  );

  await sendAndConfirmTransaction(rpc: testRpc.rpc, signedTx: signedTx);

  return (mint, TokenPoolInfo(splInterfacePda: splInterfacePda, mint: mint));
}
