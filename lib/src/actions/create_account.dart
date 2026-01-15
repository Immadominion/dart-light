import 'dart:typed_data';

import 'package:solana/solana.dart';

import '../programs/instruction_data.dart';
import '../programs/light_system_program.dart';
import '../rpc/compression_api.dart';
import '../state/bn254.dart';
import '../state/tree_info.dart';
import '../utils/address.dart';
import '../utils/transaction_utils.dart';

/// Create a compressed account with a derived address (PDA).
///
/// This creates a new compressed account with a program-derived address,
/// similar to how PDAs work for regular Solana accounts.
///
/// ## Parameters
/// - [rpc] - The RPC connection with compression support
/// - [payer] - The wallet paying for the transaction
/// - [seeds] - Seeds for address derivation
/// - [programId] - Program ID for address derivation
/// - [lamports] - Optional lamports to attach to the new account
/// - [outputStateTreeInfo] - Optional specific state tree to use
///
/// ## Returns
/// A record containing the transaction signature and the derived address.
///
/// ## Example
/// ```dart
/// final result = await createAccount(
///   rpc: rpc,
///   payer: wallet,
///   seeds: [utf8.encode('my-account')],
///   programId: myProgramId,
/// );
/// print('Created account: ${result.address}');
/// print('Signature: ${result.signature}');
/// ```
Future<({String signature, Ed25519HDPublicKey address})> createAccount({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required List<List<int>> seeds,
  required Ed25519HDPublicKey programId,
  BigInt? lamports,
  TreeInfo? outputStateTreeInfo,
}) async {
  // Get address tree info
  final addressTreeInfo = await rpc.getAddressTreeInfoV2();

  // Derive address seed
  final addressSeed = deriveAddressSeed(
    seeds: seeds.map((s) => Uint8List.fromList(s)).toList(),
    programId: programId,
  );

  // Derive the actual address
  final address = deriveAddress(
    seed: addressSeed,
    addressMerkleTreePubkey: addressTreeInfo.tree,
  );

  // Get validity proof for the new address
  final proof = await rpc.getValidityProof(
    newAddresses: [BN254.fromPublicKey(address)],
  );

  // Create new address params
  final newAddressParams = NewAddressParams(
    seed: addressSeed,
    addressMerkleTreeRootIndex:
        proof.rootIndices.isNotEmpty ? proof.rootIndices.first : 0,
    addressMerkleTreePubkey: addressTreeInfo.tree,
    addressQueuePubkey: addressTreeInfo.queue,
  );

  // Create account instruction
  final instruction = LightSystemProgram.createAccount(
    payer: payer.publicKey,
    newAddressParams: newAddressParams,
    newAddress: address.bytes.toList(),
    recentValidityProof: proof.compressedProof,
    outputStateTreeInfo: outputStateTreeInfo,
    lamports: lamports,
  );

  // Build and sign transaction
  final signedTx = await buildAndSignTransaction(
    rpc: rpc,
    signer: payer,
    instructions: [instruction],
  );

  // Send and confirm
  final signature = await sendAndConfirmTransaction(
    rpc: rpc,
    signedTx: signedTx,
  );

  return (signature: signature, address: address);
}
