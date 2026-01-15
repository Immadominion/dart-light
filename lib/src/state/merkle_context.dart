import 'package:equatable/equatable.dart';

import 'bn254.dart';
import 'tree_info.dart';

/// Context about where a compressed account is stored in the Merkle tree.
class MerkleContext extends Equatable {
  const MerkleContext({
    required this.treeInfo,
    required this.hash,
    required this.leafIndex,
    this.proveByIndex = false,
  });

  /// Tree information.
  final TreeInfo treeInfo;

  /// Poseidon hash of the account (the leaf value).
  final BN254 hash;

  /// Position of [hash] in the state tree.
  final int leafIndex;

  /// Whether the account can be proven by index (batch trees only).
  final bool proveByIndex;

  @override
  List<Object?> get props => [treeInfo, hash, leafIndex, proveByIndex];
}

/// Create a Merkle context.
MerkleContext createMerkleContext({
  required TreeInfo treeInfo,
  required BN254 hash,
  required int leafIndex,
  bool proveByIndex = false,
}) => MerkleContext(
  treeInfo: treeInfo,
  hash: hash,
  leafIndex: leafIndex,
  proveByIndex: proveByIndex,
);

/// Packed state tree info for instructions.
class PackedStateTreeInfo extends Equatable {
  const PackedStateTreeInfo({
    required this.rootIndex,
    required this.proveByIndex,
    required this.merkleTreePubkeyIndex,
    required this.queuePubkeyIndex,
    required this.leafIndex,
  });

  /// Recent valid root index.
  final int rootIndex;

  /// Whether to prove by index.
  final bool proveByIndex;

  /// Index of the Merkle tree in remaining accounts.
  final int merkleTreePubkeyIndex;

  /// Index of the queue in remaining accounts.
  final int queuePubkeyIndex;

  /// Leaf index in the tree.
  final int leafIndex;

  @override
  List<Object?> get props => [
    rootIndex,
    proveByIndex,
    merkleTreePubkeyIndex,
    queuePubkeyIndex,
    leafIndex,
  ];
}

/// Packed address tree info for instructions.
class PackedAddressTreeInfo extends Equatable {
  const PackedAddressTreeInfo({
    required this.addressMerkleTreePubkeyIndex,
    required this.addressQueuePubkeyIndex,
    required this.rootIndex,
  });

  /// Index of the address Merkle tree in remaining accounts.
  final int addressMerkleTreePubkeyIndex;

  /// Index of the address queue in remaining accounts.
  final int addressQueuePubkeyIndex;

  /// Recent valid root index.
  final int rootIndex;

  @override
  List<Object?> get props => [
    addressMerkleTreePubkeyIndex,
    addressQueuePubkeyIndex,
    rootIndex,
  ];
}
