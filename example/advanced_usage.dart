// ignore_for_file: avoid_print

/// Advanced usage example for Light Protocol SDK.
///
/// This example demonstrates advanced patterns:
/// - Account selection strategies
/// - Manual transaction building
/// - Batch operations
/// - Error handling patterns
/// - Validity proof caching
///
/// To run this example:
/// ```bash
/// dart run example/advanced_usage.dart
/// ```
library;

import 'dart:typed_data';

import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';

void main() async {
  print('Light Protocol SDK - Advanced Usage Example\n');

  final rpc = Rpc.create('https://devnet.helius-rpc.com?api-key=YOUR_API_KEY');

  final wallet = await Ed25519HDKeyPair.random();

  // ============================================================
  // 1. Account Selection Strategies
  // ============================================================

  print('--- Account Selection Strategies ---\n');

  // Get all compressed accounts
  final accounts = await rpc.getCompressedAccountsByOwner(wallet.publicKey);

  if (accounts.items.isNotEmpty) {
    final transferAmount = BigInt.from(100000000); // 0.1 SOL

    // The SDK uses a greedy algorithm to select minimum accounts
    final (selected, total) = selectMinCompressedSolAccountsForTransfer(
      accounts.items,
      transferAmount,
    );

    print('Selected ${selected.length} accounts for transfer:');
    print('  Transfer amount: $transferAmount');
    print('  Total selected: $total');
    print('  Change: ${total - transferAmount}');

    // You can also select token accounts
    final tokenAccounts = await rpc.getCompressedTokenAccountsByOwner(
      wallet.publicKey,
    );

    if (tokenAccounts.items.isNotEmpty) {
      final tokenTransferAmount = BigInt.from(1000);
      final (
        tokenSelected,
        tokenTotal,
      ) = selectMinCompressedTokenAccountsForTransfer(
        tokenAccounts.items,
        tokenTransferAmount,
        // Custom amount getter - uses parsed.amount by default
        (account) => account.parsed.amount,
      );

      print('Selected ${tokenSelected.length} token accounts');
    }
  }

  // ============================================================
  // 2. Manual Transaction Building
  // ============================================================

  print('\n--- Manual Transaction Building ---\n');

  // Get state tree info
  final treeInfos = await rpc.getStateTreeInfos();
  final stateTreeInfo = selectStateTreeInfo(treeInfos);

  // Build a compress instruction manually
  final compressInstruction = LightSystemProgram.compress(
    payer: wallet.publicKey,
    toAddress: wallet.publicKey,
    lamports: BigInt.from(100000000),
    outputStateTreeInfo: stateTreeInfo,
  );

  print('Compress instruction built:');
  print('  Program: ${compressInstruction.programId.toBase58()}');
  print('  Accounts: ${compressInstruction.accounts.length}');

  // Build transaction with custom compute budget
  // ignore: unused_local_variable
  final signedTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: wallet,
    instructions: [compressInstruction],
    computeUnitLimit: 1000000, // 1M compute units
    computeUnitPrice: 1000, // Micro-lamports per CU
  );

  print('Transaction built with custom compute budget');

  // ============================================================
  // 3. Validity Proofs
  // ============================================================

  print('\n--- Validity Proofs ---\n');

  if (accounts.items.isNotEmpty) {
    // Get proof for existing accounts
    final hashes = accounts.items.take(3).map((a) => a.hash).toList();

    final proof = await rpc.getValidityProof(hashes: hashes);

    print('Validity proof received:');
    print('  Roots: ${proof.roots.length}');
    print('  Leaf indices: ${proof.leafIndices}');
    print('  Root indices: ${proof.rootIndices}');
    print('  Has compressed proof: ${proof.compressedProof != null}');

    if (proof.compressedProof != null) {
      print('  Proof A: ${proof.compressedProof!.a.length} bytes');
      print('  Proof B: ${proof.compressedProof!.b.length} bytes');
      print('  Proof C: ${proof.compressedProof!.c.length} bytes');
    }
  }

  // Request proof with new addresses (for createAccount)
  print('\nRequesting proof with new address:');

  // Derive a new address
  final addressSeed = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    addressSeed[i] = i + 1;
  }

  final newAddress = deriveAddress(
    seed: addressSeed,
    addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
  );

  final proofWithAddress = await rpc.getValidityProof(
    newAddresses: [BN254.fromPublicKey(newAddress)],
  );

  print('  New address: ${newAddress.toBase58()}');
  print('  Proof received: ${proofWithAddress.compressedProof != null}');

  // ============================================================
  // 4. Error Handling Patterns
  // ============================================================

  print('\n--- Error Handling Patterns ---\n');

  // Pattern 1: Typed exception handling
  try {
    await transfer(
      rpc: rpc,
      payer: wallet,
      owner: wallet,
      lamports: BigInt.from(999999999999999999), // Way too much
      toAddress: wallet.publicKey,
    );
  } on InsufficientBalanceException catch (e) {
    print('InsufficientBalanceException caught:');
    print('  Required: ${e.required}');
    print('  Available: ${e.available}');
  } on LightException catch (e) {
    print('LightException caught: ${e.message}');
  }

  // Pattern 2: Parse program errors from logs
  try {
    // Simulate a transaction failure
    // In practice, catch JsonRpcException from RPC calls
    // parseLightError expects a JsonRpcException from RPC calls
    print(
      'parseLightError() converts JsonRpcException to typed LightException',
    );
  } catch (_) {
    // Expected
  }

  // Pattern 3: User-friendly error formatting
  final error = InsufficientBalanceException(
    required: BigInt.from(1000000000),
    available: BigInt.from(500000000),
  );
  print('User message: ${error.toString()}');

  // ============================================================
  // 5. Batch Operations Pattern
  // ============================================================

  print('\n--- Batch Operations Pattern ---\n');

  // For batch operations, get all accounts in one call
  // using pagination
  final allAccounts = <CompressedAccountWithMerkleContext>[];
  String? cursor;

  do {
    final batch = await rpc.getCompressedAccountsByOwner(
      wallet.publicKey,
      cursor: cursor,
      limit: 1000,
    );

    allAccounts.addAll(batch.items);
    cursor = batch.cursor;

    print('Fetched batch: ${batch.items.length} accounts');
  } while (cursor != null);

  print('Total accounts: ${allAccounts.length}');

  // ============================================================
  // 6. Fee Estimation
  // ============================================================

  print('\n--- Fee Estimation ---\n');

  // Light Protocol has specific fees for different operations
  print('Fee constants:');
  print(
    '  State tree rollover: ${LightFees.stateMerkleTreeRolloverFee} lamports',
  );
  print(
    '  Address queue rollover: ${LightFees.addressQueueRolloverFee} lamports',
  );
  print(
    '  State tree network fee: ${LightFees.stateMerkleTreeNetworkFee} lamports',
  );

  // Estimate fees for a transfer (1 input, 2 outputs: recipient + change)
  final estimatedFee =
      LightFees.stateMerkleTreeRolloverFee * BigInt.from(2) + // 2 outputs
      LightFees.stateMerkleTreeNetworkFee + // 1 network fee
      BigInt.from(5000); // Base tx fee

  print('Estimated transfer fee: $estimatedFee lamports');

  // ============================================================
  // 7. Tree Info and Migration
  // ============================================================

  print('\n--- Tree Info and Migration ---\n');

  final allTreeInfos = await rpc.getStateTreeInfos();
  print('Available state trees: ${allTreeInfos.length}');

  for (final info in allTreeInfos) {
    print('  • Tree: ${info.tree.toBase58().substring(0, 8)}...');
    print('    Type: ${info.treeType}');
    print(
      '    CPI Context: ${info.cpiContext?.toBase58().substring(0, 8) ?? 'null'}...',
    );

    if (info.nextTreeInfo != null) {
      print('    ⚠️ Has nextTreeInfo - tree may be full');
    }
  }

  // Always use selectStateTreeInfo to handle tree selection
  final selectedTree = selectStateTreeInfo(allTreeInfos);
  print('\nSelected tree: ${selectedTree.tree.toBase58()}');

  print('\n✓ Advanced usage example complete!');
}
