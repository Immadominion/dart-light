import 'package:solana/solana.dart';

import '../programs/light_system_program.dart';
import '../rpc/compression_api.dart';
import '../state/compressed_account.dart';
import '../utils/account_selection.dart';
import '../utils/transaction_utils.dart';

/// Transfer compressed SOL from one address to another.
///
/// This operation transfers compressed lamports between compressed accounts.
/// It automatically selects the minimum number of input accounts needed
/// and creates change accounts if necessary.
///
/// ## Parameters
/// - [rpc] - The RPC connection with compression support
/// - [payer] - The wallet paying for transaction fees
/// - [lamports] - Amount of lamports to transfer
/// - [owner] - Owner of the source compressed accounts (signer)
/// - [toAddress] - Recipient address
/// - [commitment] - Transaction commitment level (default: confirmed)
/// - [timeout] - Transaction confirmation timeout (default: 30 seconds)
///
/// ## Returns
/// Transaction signature of the confirmed transaction.
///
/// ## Example
/// ```dart
/// final signature = await transfer(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(100000),
///   owner: wallet,
///   toAddress: recipientPubkey,
/// );
/// print('Transferred: $signature');
/// ```
///
/// ## Errors
/// - Throws if owner has insufficient compressed balance
/// - Throws if transaction fails to confirm
Future<String> transfer({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  required Ed25519HDKeyPair owner,
  required Ed25519HDPublicKey toAddress,
  Commitment commitment = Commitment.confirmed,
  Duration? timeout,
}) async {
  // Accumulate compressed accounts until we have enough lamports
  var accumulatedLamports = BigInt.zero;
  final compressedAccounts = <CompressedAccountWithMerkleContext>[];
  String? cursor;
  const batchSize = 1000;

  while (accumulatedLamports < lamports) {
    final batch = await rpc.getCompressedAccountsByOwner(
      owner.publicKey,
      cursor: cursor,
      limit: batchSize,
    );

    for (final account in batch.items) {
      if (account.lamports > BigInt.zero) {
        compressedAccounts.add(account);
        accumulatedLamports += account.lamports;
      }
    }

    cursor = batch.cursor;
    if (batch.items.length < batchSize || accumulatedLamports >= lamports) {
      break;
    }
  }

  if (accumulatedLamports < lamports) {
    throw ArgumentError(
      'Insufficient balance for transfer. '
      'Required: $lamports, Available: $accumulatedLamports',
    );
  }

  // Select minimum accounts needed for transfer
  final (inputAccounts, _) = selectMinCompressedSolAccountsForTransfer(
    compressedAccounts,
    lamports,
  );

  // Get validity proof
  final hashes = inputAccounts.map((a) => a.hash).toList();
  final proof = await rpc.getValidityProof(hashes: hashes);

  // Create transfer instruction
  final instruction = LightSystemProgram.transfer(
    payer: payer.publicKey,
    inputCompressedAccounts: inputAccounts,
    toAddress: toAddress,
    lamports: lamports,
    recentInputStateRootIndices: proof.rootIndices,
    recentValidityProof: proof.compressedProof,
  );

  // Build and sign transaction with additional signers if owner != payer
  final additionalSigners = <Ed25519HDKeyPair>[];
  if (owner.publicKey.toBase58() != payer.publicKey.toBase58()) {
    additionalSigners.add(owner);
  }

  final signedTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: payer,
    instructions: [instruction],
    additionalSigners: additionalSigners,
    computeUnitLimit: 350000, // 350k CU as per TypeScript
    commitment: commitment,
  );

  // Send and confirm
  return sendAndConfirmTransaction(
    rpc: rpc,
    signedTx: signedTx,
    commitment: commitment,
    timeout: timeout,
  );
}
