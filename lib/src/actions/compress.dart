import 'package:solana/solana.dart';

import '../programs/light_system_program.dart';
import '../rpc/compression_api.dart';
import '../state/tree_info.dart';
import '../utils/state_tree_utils.dart';
import '../utils/transaction_utils.dart';

/// Compress SOL lamports into a compressed account.
///
/// This operation takes regular SOL from the payer's account and creates
/// a compressed account containing the specified lamports amount.
///
/// ## Parameters
/// - [rpc] - The RPC connection with compression support
/// - [payer] - The wallet paying for the transaction (also source of lamports)
/// - [lamports] - Amount of lamports to compress
/// - [toAddress] - Address to receive the compressed lamports
/// - [outputStateTreeInfo] - Optional: specific state tree to use
/// - [commitment] - Transaction commitment level (default: confirmed)
/// - [timeout] - Transaction confirmation timeout (default: 30 seconds)
///
/// ## Returns
/// Transaction signature of the confirmed transaction.
///
/// ## Example
/// ```dart
/// final signature = await compress(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(1000000000), // 1 SOL
///   toAddress: wallet.publicKey,
/// );
/// print('Compressed: $signature');
/// ```
///
/// ## Errors
/// - Throws if payer has insufficient SOL balance
/// - Throws if transaction fails to confirm
Future<String> compress({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  Ed25519HDPublicKey? toAddress,
  TreeInfo? outputStateTreeInfo,
  Commitment commitment = Commitment.confirmed,
  Duration? timeout,
}) async {
  // Get state tree if not provided
  final treeInfo =
      outputStateTreeInfo ?? selectStateTreeInfo(await rpc.getStateTreeInfos());

  // Create compress instruction
  final instruction = LightSystemProgram.compress(
    payer: payer.publicKey,
    toAddress: toAddress ?? payer.publicKey,
    lamports: lamports,
    outputStateTreeInfo: treeInfo,
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
