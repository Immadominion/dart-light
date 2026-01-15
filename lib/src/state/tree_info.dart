import 'package:equatable/equatable.dart';
import 'package:solana/solana.dart';

/// Type of Merkle tree.
enum TreeType {
  /// V1 state tree (concurrent Merkle tree, height 26).
  stateV1,

  /// V2 state tree (batched Merkle tree, height 32).
  stateV2,

  /// V1 address tree (indexed Merkle tree, height 26).
  addressV1,

  /// V2 address tree (batched indexed Merkle tree, height 40).
  addressV2,
}

/// Information about a state or address tree.
class TreeInfo extends Equatable {
  const TreeInfo({
    required this.tree,
    required this.queue,
    required this.treeType,
    this.cpiContext,
    this.nextTreeInfo,
  });

  /// Public key of the Merkle tree account.
  final Ed25519HDPublicKey tree;

  /// Public key of the nullifier queue (or same as tree for V2).
  final Ed25519HDPublicKey queue;

  /// Type of tree.
  final TreeType treeType;

  /// Optional CPI context for cross-program invocations.
  final Ed25519HDPublicKey? cpiContext;

  /// Next tree info for tree rollover.
  final TreeInfo? nextTreeInfo;

  /// Whether this is a V2 (batched) tree.
  bool get isV2 =>
      treeType == TreeType.stateV2 || treeType == TreeType.addressV2;

  /// Whether this is an address tree.
  bool get isAddressTree =>
      treeType == TreeType.addressV1 || treeType == TreeType.addressV2;

  @override
  List<Object?> get props => [tree, queue, treeType, cpiContext, nextTreeInfo];
}

/// Information about an address tree (alias for TreeInfo).
typedef AddressTreeInfo = TreeInfo;

/// State tree information with additional rollover context.
class StateTreeInfo extends TreeInfo {
  const StateTreeInfo({
    required super.tree,
    required super.queue,
    required super.treeType,
    super.cpiContext,
    super.nextTreeInfo,
    this.rolloverThreshold,
  });

  /// Threshold at which the tree should roll over to a new tree.
  final int? rolloverThreshold;

  @override
  List<Object?> get props => [...super.props, rolloverThreshold];
}
