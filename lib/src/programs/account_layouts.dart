import 'dart:typed_data';

import 'package:light_sdk/src/state/compressed_account.dart';
import 'package:light_sdk/src/utils/borsh.dart';
import 'package:solana/solana.dart';

/// Packed Merkle context with account indices for compact serialization.
///
/// Instead of including full pubkeys in transaction data, we reference accounts
/// by their index in the remaining_accounts array.
class PackedMerkleContext {
  const PackedMerkleContext({
    required this.merkleTreePubkeyIndex,
    required this.queuePubkeyIndex,
    required this.leafIndex,
    required this.proveByIndex,
  });

  /// Index in remaining_accounts of the Merkle tree pubkey.
  final int merkleTreePubkeyIndex;

  /// Index in remaining_accounts of the queue pubkey.
  final int queuePubkeyIndex;

  /// Leaf index in the Merkle tree.
  final int leafIndex;

  /// Whether to prove by index (batch trees) or by merkle proof.
  final bool proveByIndex;

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer =
        BorshWriter()
          ..writeU8(merkleTreePubkeyIndex)
          ..writeU8(queuePubkeyIndex)
          ..writeU32(leafIndex)
          ..writeBool(proveByIndex);
    return writer.toBytes();
  }
}

/// Compressed account layout for Borsh serialization.
///
/// This matches the on-chain CompressedAccount struct:
/// - owner: Pubkey (32 bytes)
/// - lamports: u64
/// - address: Option<[u8; 32]>
/// - data: Option<CompressedAccountData>
class CompressedAccountLayout {
  const CompressedAccountLayout({
    required this.owner,
    required this.lamports,
    this.address,
    this.data,
  });

  /// Owner pubkey (32 bytes).
  final Ed25519HDPublicKey owner;

  /// Lamports.
  final BigInt lamports;

  /// Optional address (32 bytes).
  final List<int>? address;

  /// Optional account data.
  final CompressedAccountData? data;

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer =
        BorshWriter()
          ..writeFixedArray(owner.bytes)
          ..writeU64(lamports);

    // Encode Option<[u8; 32]> for address
    writer.writeOption<List<int>>(address, (addr) {
      if (addr.length != 32) {
        throw ArgumentError('Address must be 32 bytes, got ${addr.length}');
      }
      writer.writeFixedArray(addr);
    });

    // Encode Option<CompressedAccountData>
    writer.writeOption<CompressedAccountData>(data, (d) {
      // discriminator: [u8; 8]
      if (d.discriminator.length != 8) {
        throw ArgumentError(
          'Discriminator must be 8 bytes, got ${d.discriminator.length}',
        );
      }
      writer.writeFixedArray(d.discriminator);

      // data: Vec<u8>
      writer.writeVec(Uint8List.fromList(d.data));

      // data_hash: [u8; 32]
      if (d.dataHash.length != 32) {
        throw ArgumentError(
          'Data hash must be 32 bytes, got ${d.dataHash.length}',
        );
      }
      writer.writeFixedArray(d.dataHash);
    });

    return writer.toBytes();
  }

  /// Create from a CompressedAccount.
  factory CompressedAccountLayout.fromCompressedAccount(
    CompressedAccount account,
  ) => CompressedAccountLayout(
    owner: account.owner,
    lamports: account.lamports,
    address: account.address,
    data: account.data,
  );
}

/// Packed compressed account with Merkle context for input accounts.
///
/// This matches the on-chain PackedCompressedAccountWithMerkleContext struct:
/// - compressed_account: CompressedAccount
/// - merkle_context: PackedMerkleContext
/// - root_index: u16
/// - read_only: bool
class PackedCompressedAccountWithMerkleContext {
  const PackedCompressedAccountWithMerkleContext({
    required this.compressedAccount,
    required this.merkleContext,
    required this.rootIndex,
    required this.readOnly,
  });

  /// The compressed account.
  final CompressedAccountLayout compressedAccount;

  /// Packed Merkle context.
  final PackedMerkleContext merkleContext;

  /// Root index for validity proof.
  final int rootIndex;

  /// Read-only flag (placeholder, usually false).
  final bool readOnly;

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer =
        BorshWriter()
          ..writeFixedArray(compressedAccount.encode())
          ..writeFixedArray(merkleContext.encode())
          ..writeU16(rootIndex)
          ..writeBool(readOnly);
    return writer.toBytes();
  }
}

/// Output compressed account with packed context for new accounts.
///
/// This matches the on-chain OutputCompressedAccountWithPackedContext struct:
/// - compressed_account: CompressedAccount
/// - merkle_tree_index: u8
class OutputCompressedAccountWithPackedContext {
  const OutputCompressedAccountWithPackedContext({
    required this.compressedAccount,
    required this.merkleTreeIndex,
  });

  /// The compressed account to be created.
  final CompressedAccountLayout compressedAccount;

  /// Index in remaining_accounts of the output state tree.
  final int merkleTreeIndex;

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer =
        BorshWriter()
          ..writeFixedArray(compressedAccount.encode())
          ..writeU8(merkleTreeIndex);
    return writer.toBytes();
  }
}

/// New address parameters with packed indices.
///
/// This matches the on-chain NewAddressParamsPacked struct:
/// - seed: [u8; 32]
/// - address_queue_account_index: u8
/// - address_merkle_tree_account_index: u8
/// - address_merkle_tree_root_index: u16
class NewAddressParamsPacked {
  const NewAddressParamsPacked({
    required this.seed,
    required this.addressQueueAccountIndex,
    required this.addressMerkleTreeAccountIndex,
    required this.addressMerkleTreeRootIndex,
  });

  /// Seed for address derivation (32 bytes).
  final List<int> seed;

  /// Index of address queue in remaining_accounts.
  final int addressQueueAccountIndex;

  /// Index of address Merkle tree in remaining_accounts.
  final int addressMerkleTreeAccountIndex;

  /// Root index for address proof.
  final int addressMerkleTreeRootIndex;

  /// Encode to Borsh bytes.
  Uint8List encode() {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be 32 bytes, got ${seed.length}');
    }
    final writer =
        BorshWriter()
          ..writeFixedArray(seed)
          ..writeU8(addressQueueAccountIndex)
          ..writeU8(addressMerkleTreeAccountIndex)
          ..writeU16(addressMerkleTreeRootIndex);
    return writer.toBytes();
  }
}
