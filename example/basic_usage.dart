// ignore_for_file: avoid_print, unused_local_variable

/// Basic usage example for Light Protocol SDK.
///
/// This example demonstrates the fundamental operations:
/// - Creating an RPC connection with compression support
/// - Compressing SOL
/// - Checking compressed balance
/// - Transferring compressed SOL
/// - Decompressing SOL back to regular account
///
/// To run this example:
/// ```bash
/// dart run example/basic_usage.dart
/// ```
library;

import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';

/// Example wallet for demonstration.
///
/// In production, load this from secure storage.
Future<Ed25519HDKeyPair> loadWallet() async {
  // For demo purposes, generate a random wallet
  // In production, use: Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: ...)
  return Ed25519HDKeyPair.random();
}

void main() async {
  print('Light Protocol SDK - Basic Usage Example\n');

  // ============================================================
  // Step 1: Create RPC connection with compression support
  // ============================================================

  // The Rpc class extends standard Solana RPC with compression APIs.
  // It connects to both the Solana RPC and Photon indexer.
  final rpc = Rpc.create(
    'https://devnet.helius-rpc.com?api-key=YOUR_API_KEY',
    compressionApiEndpoint:
        'https://devnet.helius-rpc.com?api-key=YOUR_API_KEY',
    proverEndpoint: 'https://prover.helius.dev',
  );

  print('✓ Connected to Solana devnet with compression support');

  // ============================================================
  // Step 2: Load wallet
  // ============================================================

  final wallet = await loadWallet();
  print('✓ Wallet loaded: ${wallet.publicKey.toBase58()}');

  // ============================================================
  // Step 3: Check initial balances
  // ============================================================

  // Regular Solana balance
  final regularBalance = await rpc.rpcClient.getBalance(
    wallet.publicKey.toBase58(),
    commitment: Commitment.confirmed,
  );
  print('  Regular SOL balance: ${regularBalance.value / lamportsPerSol} SOL');

  // Compressed SOL balance
  try {
    final compressedBalance = await rpc.getCompressedBalanceByOwner(
      wallet.publicKey,
    );
    print(
      '  Compressed SOL balance: ${compressedBalance / BigInt.from(lamportsPerSol)} SOL',
    );
  } catch (e) {
    print('  Compressed SOL balance: 0 SOL (no compressed accounts)');
  }

  // ============================================================
  // Step 4: Compress SOL (regular → compressed)
  // ============================================================

  print('\n--- Compressing SOL ---');

  // Compress 0.1 SOL to self
  // This creates a compressed account with the SOL
  final compressAmount = BigInt.from(lamportsPerSol ~/ 10); // 0.1 SOL

  try {
    final compressSignature = await compress(
      rpc: rpc,
      payer: wallet,
      lamports: compressAmount,
      toAddress: wallet.publicKey,
    );
    print('✓ Compressed $compressAmount lamports');
    print('  Transaction: $compressSignature');
  } on InsufficientBalanceException catch (e) {
    print('✗ Insufficient balance: $e');
    return;
  }

  // ============================================================
  // Step 5: View compressed accounts
  // ============================================================

  print('\n--- Viewing Compressed Accounts ---');

  final accounts = await rpc.getCompressedAccountsByOwner(wallet.publicKey);

  print('Found ${accounts.items.length} compressed account(s):');
  for (final account in accounts.items) {
    print('  • Hash: ${account.hash.toBase58()}');
    print('    Lamports: ${account.lamports}');
    print('    Tree: ${account.treeInfo.tree.toBase58()}');
  }

  // ============================================================
  // Step 6: Transfer compressed SOL
  // ============================================================

  print('\n--- Transferring Compressed SOL ---');

  // Create a recipient (in practice, this would be another user's address)
  final recipient = await Ed25519HDKeyPair.random();
  final transferAmount = BigInt.from(50000000); // 0.05 SOL

  try {
    final transferSignature = await transfer(
      rpc: rpc,
      payer: wallet,
      owner: wallet,
      lamports: transferAmount,
      toAddress: recipient.publicKey,
    );
    print(
      '✓ Transferred $transferAmount lamports to ${recipient.publicKey.toBase58()}',
    );
    print('  Transaction: $transferSignature');
  } on InsufficientBalanceException catch (e) {
    print('✗ Insufficient compressed balance: $e');
  }

  // ============================================================
  // Step 7: Decompress SOL (compressed → regular)
  // ============================================================

  print('\n--- Decompressing SOL ---');

  final decompressAmount = BigInt.from(25000000); // 0.025 SOL

  try {
    final decompressSignature = await decompress(
      rpc: rpc,
      payer: wallet,
      lamports: decompressAmount,
      recipient: wallet.publicKey,
    );
    print('✓ Decompressed $decompressAmount lamports');
    print('  Transaction: $decompressSignature');
  } on InsufficientBalanceException catch (e) {
    print('✗ Insufficient compressed balance: $e');
  }

  // ============================================================
  // Step 8: Final balance check
  // ============================================================

  print('\n--- Final Balances ---');

  final finalRegularBalance = await rpc.rpcClient.getBalance(
    wallet.publicKey.toBase58(),
    commitment: Commitment.confirmed,
  );
  print('  Regular SOL: ${finalRegularBalance.value / lamportsPerSol} SOL');

  try {
    final finalCompressedBalance = await rpc.getCompressedBalanceByOwner(
      wallet.publicKey,
    );
    print(
      '  Compressed SOL: ${finalCompressedBalance / BigInt.from(lamportsPerSol)} SOL',
    );
  } catch (_) {
    print('  Compressed SOL: 0 SOL');
  }

  print('\n✓ Basic usage example complete!');
}
