/// State types for compressed accounts and Merkle trees.
///
/// These types represent the core data structures used in Light Protocol:
/// - [CompressedAccount] - A compressed account stored in a Merkle tree
/// - [MerkleContext] - Context about where an account is stored
/// - [ValidityProof] - Zero-knowledge proof for state transitions
/// - [TreeInfo] - Information about state/address trees
/// - [BN254] - Field element type for cryptographic operations
library;

export 'bn254.dart';
export 'compressed_account.dart';
export 'merkle_context.dart';
export 'token_data.dart';
export 'tree_info.dart';
export 'validity_proof.dart';
