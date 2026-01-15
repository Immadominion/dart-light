// ignore_for_file: avoid_print, unused_local_variable

/// Compressed token example for Light Protocol SDK.
///
/// This example demonstrates compressed SPL token operations:
/// - Creating a token pool for compression
/// - Minting compressed tokens
/// - Transferring compressed tokens
/// - Querying token balances
///
/// To run this example:
/// ```bash
/// dart run example/compressed_tokens.dart
/// ```
library;

import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';

void main() async {
  print('Light Protocol SDK - Compressed Tokens Example\n');

  // ============================================================
  // Step 1: Setup RPC and wallets
  // ============================================================

  final rpc = Rpc.create(
    'https://devnet.helius-rpc.com?api-key=YOUR_API_KEY',
    compressionApiEndpoint:
        'https://devnet.helius-rpc.com?api-key=YOUR_API_KEY',
    proverEndpoint: 'https://prover.helius.dev',
  );

  final wallet = await Ed25519HDKeyPair.random();
  final mintAuthority = await Ed25519HDKeyPair.random();
  final recipient = await Ed25519HDKeyPair.random();

  print('✓ Setup complete');
  print('  Wallet: ${wallet.publicKey.toBase58()}');
  print('  Mint Authority: ${mintAuthority.publicKey.toBase58()}');
  print('  Recipient: ${recipient.publicKey.toBase58()}');

  // ============================================================
  // Step 2: Create a test SPL Token mint
  // ============================================================

  print('\n--- Creating SPL Token Mint ---');

  // First, create a standard SPL token mint
  final mintKeypair = await Ed25519HDKeyPair.random();
  print('  Mint address: ${mintKeypair.publicKey.toBase58()}');

  // Create mint account instruction
  final createMintIx = SystemInstruction.createAccount(
    fundingAccount: wallet.publicKey,
    newAccount: mintKeypair.publicKey,
    lamports: await rpc.rpcClient.getMinimumBalanceForRentExemption(82),
    space: 82, // SPL Token mint size
    owner: Ed25519HDPublicKey.fromBase58(
      'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
    ),
  );

  // Initialize mint instruction
  final initMintIx = TokenInstruction.initializeMint(
    mint: mintKeypair.publicKey,
    decimals: 9,
    mintAuthority: mintAuthority.publicKey,
    freezeAuthority: null,
  );

  // Build and send transaction
  final createMintTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: wallet,
    additionalSigners: [mintKeypair],
    instructions: [createMintIx, initMintIx],
  );

  try {
    final signature = await sendAndConfirmTransaction(
      rpc: rpc,
      signedTx: createMintTx,
    );
    print('✓ Mint created: $signature');
  } catch (e) {
    print('✗ Failed to create mint: $e');
    return;
  }

  // ============================================================
  // Step 3: Create token pool for compression
  // ============================================================

  print('\n--- Creating Token Pool ---');

  // Get the token pool PDA
  final splInterfacePda = await CompressedTokenProgram.deriveTokenPoolPda(
    mint: mintKeypair.publicKey,
  );

  // Create token pool instruction
  final createPoolIx = await CompressedTokenProgram.createSplInterface(
    feePayer: wallet.publicKey,
    mint: mintKeypair.publicKey,
  );

  final createPoolTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: wallet,
    instructions: [createPoolIx],
  );

  try {
    final signature = await sendAndConfirmTransaction(
      rpc: rpc,
      signedTx: createPoolTx,
    );
    print('✓ Token pool created: $signature');
  } catch (e) {
    print('✗ Failed to create token pool: $e');
    return;
  }

  // Create TokenPoolInfo for minting
  final tokenPoolInfo = TokenPoolInfo(
    splInterfacePda: splInterfacePda,
    mint: mintKeypair.publicKey,
  );

  // ============================================================
  // Step 4: Mint compressed tokens
  // ============================================================

  print('\n--- Minting Compressed Tokens ---');

  // Get state tree info
  final treeInfos = await rpc.getStateTreeInfos();
  final stateTreeInfo = selectStateTreeInfo(treeInfos);

  // Mint 1,000,000 tokens to recipient
  final mintAmount = BigInt.from(
    1000000000000000,
  ); // With 9 decimals = 1M tokens

  final mintToIx = CompressedTokenProgram.mintTo(
    feePayer: wallet.publicKey,
    mint: mintKeypair.publicKey,
    authority: mintAuthority.publicKey,
    recipients: [recipient.publicKey],
    amounts: [mintAmount],
    outputStateTreeInfo: stateTreeInfo,
    tokenPoolInfo: tokenPoolInfo,
  );

  final mintTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: wallet,
    additionalSigners: [mintAuthority],
    instructions: [mintToIx],
  );

  try {
    final signature = await sendAndConfirmTransaction(
      rpc: rpc,
      signedTx: mintTx,
    );
    print('✓ Minted $mintAmount tokens to ${recipient.publicKey.toBase58()}');
    print('  Transaction: $signature');
  } catch (e) {
    print('✗ Failed to mint tokens: $e');
    return;
  }

  // ============================================================
  // Step 5: Query token balances
  // ============================================================

  print('\n--- Querying Token Balances ---');

  final tokenAccounts = await rpc.getCompressedTokenAccountsByOwner(
    recipient.publicKey,
    mint: mintKeypair.publicKey,
  );

  print('Found ${tokenAccounts.items.length} token account(s):');
  for (final account in tokenAccounts.items) {
    print('  • Mint: ${account.parsed.mint.toBase58()}');
    print('    Amount: ${account.parsed.amount}');
    print('    Owner: ${account.parsed.owner.toBase58()}');
  }

  // Get total balance by owner
  final tokenBalances = await rpc.getCompressedTokenBalancesByOwner(
    recipient.publicKey,
  );

  print('\nToken balances by mint:');
  for (final balance in tokenBalances.items) {
    print('  • Mint: ${balance.mint.toBase58()}');
    print('    Total: ${balance.balance}');
  }

  // ============================================================
  // Step 6: Transfer compressed tokens
  // ============================================================

  print('\n--- Transferring Compressed Tokens ---');

  final transferRecipient = await Ed25519HDKeyPair.random();
  final transferAmount = BigInt.from(500000000000000); // 500K tokens

  // Get input token accounts
  final inputAccounts = tokenAccounts.items;

  // Get validity proof for the transfer
  final hashes = inputAccounts.map((a) => a.compressedAccount.hash).toList();
  final proof = await rpc.getValidityProof(hashes: hashes);

  // Create transfer instruction
  final transferIx = CompressedTokenProgram.transfer(
    payer: recipient.publicKey,
    inputCompressedTokenAccounts: inputAccounts,
    toAddress: transferRecipient.publicKey,
    amount: transferAmount,
    recentInputStateRootIndices: proof.rootIndices,
    recentValidityProof: proof.compressedProof,
  );

  final transferTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: recipient,
    instructions: [transferIx],
  );

  try {
    final signature = await sendAndConfirmTransaction(
      rpc: rpc,
      signedTx: transferTx,
    );
    print('✓ Transferred $transferAmount tokens');
    print('  To: ${transferRecipient.publicKey.toBase58()}');
    print('  Transaction: $signature');
  } catch (e) {
    print('✗ Failed to transfer tokens: $e');
    return;
  }

  // ============================================================
  // Step 7: Final balance check
  // ============================================================

  print('\n--- Final Balances ---');

  // Sender balance
  final senderBalance = await rpc.getCompressedTokenAccountsByOwner(
    recipient.publicKey,
    mint: mintKeypair.publicKey,
  );
  final senderTotal = senderBalance.items.fold<BigInt>(
    BigInt.zero,
    (sum, acc) => sum + acc.parsed.amount,
  );
  print(
    '  Sender (${recipient.publicKey.toBase58().substring(0, 8)}...): $senderTotal tokens',
  );

  // Recipient balance
  final receiverBalance = await rpc.getCompressedTokenAccountsByOwner(
    transferRecipient.publicKey,
    mint: mintKeypair.publicKey,
  );
  final receiverTotal = receiverBalance.items.fold<BigInt>(
    BigInt.zero,
    (sum, acc) => sum + acc.parsed.amount,
  );
  print(
    '  Receiver (${transferRecipient.publicKey.toBase58().substring(0, 8)}...): $receiverTotal tokens',
  );

  print('\n✓ Compressed tokens example complete!');
}
