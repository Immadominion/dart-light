import 'package:solana/solana.dart';

import '../programs/light_system_program.dart';
import '../rpc/compression_api.dart';
import '../state/compressed_account.dart';
import '../utils/account_selection.dart';
import '../utils/transaction_utils.dart';

/// Decompress SOL from compressed accounts back to a regular Solana account.
///
/// This operation takes compressed SOL and converts it back to regular SOL
/// in the recipient's account.
///
/// ## Parameters
/// - [rpc] - The RPC connection with compression support
/// - [payer] - The wallet paying for the transaction and owner of compressed SOL
/// - [lamports] - Amount of lamports to decompress
/// - [recipient] - Address to receive the decompressed SOL
/// - [commitment] - Transaction commitment level (default: confirmed)
/// - [timeout] - Transaction confirmation timeout (default: 30 seconds)
///
/// ## Returns
/// Transaction signature of the confirmed transaction.
///
/// ## Example
/// ```dart
/// final signature = await decompress(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(500000000), // 0.5 SOL
///   recipient: wallet.publicKey,
/// );
/// print('Decompressed: $signature');
/// ```
///
/// ## Errors
/// - Throws if payer has insufficient compressed balance
/// - Throws if transaction fails to confirm
Future<String> decompress({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  Ed25519HDPublicKey? recipient,
  Commitment commitment = Commitment.confirmed,
  Duration? timeout,
}) async {
  // Get all compressed accounts owned by payer
  final accountsResult = await rpc.getCompressedAccountsByOwner(
    payer.publicKey,
  );
  final accounts = accountsResult.items;

  // Check total available lamports
  final totalLamports = sumUpLamports(accounts);
  if (lamports > totalLamports) {
    throw ArgumentError(
      'Not enough compressed lamports. Expected $lamports, got $totalLamports',
    );
  }

  // Select minimum accounts needed
  final (inputAccounts, _) = selectMinCompressedSolAccountsForTransfer(
    accounts,
    lamports,
  );

  // Get validity proof for input accounts
  final hashes = inputAccounts.map((a) => a.hash).toList();
  final proof = await rpc.getValidityProof(hashes: hashes);

  // Create decompress instruction
  final instruction = LightSystemProgram.decompress(
    payer: payer.publicKey,
    toAddress: recipient ?? payer.publicKey,
    inputCompressedAccounts: inputAccounts,
    recentValidityProof: proof.compressedProof,
    recentInputStateRootIndices: proof.rootIndices,
    lamports: lamports,
  );

  // Build and sign transaction with compute budget
  final signedTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: payer,
    instructions: [instruction],
    computeUnitLimit: 1000000, // 1M CU as per TypeScript
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

/// Calculate total lamports across compressed accounts.
BigInt sumUpLamports(List<CompressedAccountWithMerkleContext> accounts) =>
    accounts.fold(BigInt.zero, (sum, account) => sum + account.lamports);
