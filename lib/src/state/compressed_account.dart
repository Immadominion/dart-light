import 'package:equatable/equatable.dart';
import 'package:solana/solana.dart';

import 'bn254.dart';
import 'tree_info.dart';

/// Data attached to a compressed account.
class CompressedAccountData extends Equatable {
  const CompressedAccountData({
    required this.discriminator,
    required this.data,
    required this.dataHash,
  });

  /// 8-byte discriminator identifying the account type.
  final List<int> discriminator;

  /// Raw account data.
  final List<int> data;

  /// Poseidon hash of the data.
  final List<int> dataHash;

  @override
  List<Object?> get props => [discriminator, data, dataHash];
}

/// A compressed account stored in a Merkle tree.
///
/// Compressed accounts are the core primitive of Light Protocol. Instead of
/// storing account data directly on-chain, the data is hashed and stored in
/// a Merkle tree. This dramatically reduces storage costs while maintaining
/// security through zero-knowledge proofs.
class CompressedAccount extends Equatable {
  const CompressedAccount({
    required this.owner,
    required this.lamports,
    required this.hash,
    required this.treeInfo,
    required this.leafIndex,
    this.address,
    this.data,
    this.readOnly = false,
    this.proveByIndex = false,
  });

  /// Public key of the program or user owning the account.
  final Ed25519HDPublicKey owner;

  /// Lamports attached to the account.
  final BigInt lamports;

  /// Poseidon hash of the account (stored as leaf in state tree).
  final BN254 hash;

  /// Information about the state tree containing this account.
  final TreeInfo treeInfo;

  /// Position of [hash] in the state tree.
  final int leafIndex;

  /// Optional unique account ID that persists across transactions.
  final List<int>? address;

  /// Optional data attached to the account.
  final CompressedAccountData? data;

  /// Whether this account is read-only in the current transaction.
  final bool readOnly;

  /// Whether this account can be proven by index (for batch trees).
  final bool proveByIndex;

  @override
  List<Object?> get props => [
    owner,
    lamports,
    hash,
    treeInfo,
    leafIndex,
    address,
    data,
    readOnly,
    proveByIndex,
  ];
}

/// Compressed account with full Merkle context.
///
/// This type alias exists for API compatibility with the TypeScript SDK.
typedef CompressedAccountWithMerkleContext = CompressedAccount;

/// Create a compressed account with Merkle context.
CompressedAccountWithMerkleContext createCompressedAccountWithMerkleContext({
  required Ed25519HDPublicKey owner,
  required BN254 hash,
  required TreeInfo treeInfo,
  required int leafIndex,
  BigInt? lamports,
  CompressedAccountData? data,
  List<int>? address,
  bool proveByIndex = false,
}) => CompressedAccount(
  owner: owner,
  lamports: lamports ?? BigInt.zero,
  hash: hash,
  treeInfo: treeInfo,
  leafIndex: leafIndex,
  address: address,
  data: data,
  proveByIndex: proveByIndex,
);
