import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';
import 'package:solana/solana.dart';

import '../constants/tree_config.dart';
import '../state/bn254.dart';

/// Keccak256 hash function using pointycastle.
///
/// This is the same hashing algorithm used by Ethereum and the Light Protocol
/// TypeScript SDK (@noble/hashes/sha3 keccak_256).
Uint8List _keccak256(Uint8List input) {
  final digest = KeccakDigest(256);
  return digest.process(input);
}

/// Hash multiple byte arrays to a value that fits in the BN254 field.
///
/// This performs a Keccak256 hash using an incremental hasher (matching
/// the TypeScript SDK's behavior) and truncates the result to 31 bytes
/// by setting the most significant byte to zero.
///
/// Note: The TypeScript SDK uses an incremental hasher where each input
/// is added via `update()` before calling `digest()`. This produces the
/// same result as concatenating all inputs and hashing once for Keccak256.
Uint8List hashvToBn254FieldSizeBe(List<Uint8List> bytes) {
  final digest = KeccakDigest(256);

  // Feed each input to the hasher (incremental hashing)
  for (final input in bytes) {
    digest.update(input, 0, input.length);
  }

  // Finalize and get the hash
  final hash = Uint8List(32);
  digest.doFinal(hash, 0);

  // Truncate to fit in BN254 field by zeroing the MSB
  hash[0] = 0;

  return hash;
}

/// Hash multiple byte arrays with a bump seed (255) to fit in BN254 field.
///
/// Matches TypeScript's hashvToBn254FieldSizeBeU8Array which appends [255]
/// as a bump seed before digesting.
Uint8List hashvToBn254FieldSizeBeU8Array(List<Uint8List> bytes) {
  final digest = KeccakDigest(256);

  // Feed each input to the hasher
  for (final input in bytes) {
    digest.update(input, 0, input.length);
  }

  // Add bump seed (255) as TypeScript does: hasher.update(Uint8Array.from([255]))
  final bumpSeed = Uint8List.fromList([255]);
  digest.update(bumpSeed, 0, 1);

  // Finalize and get the hash
  final hash = Uint8List(32);
  digest.doFinal(hash, 0);

  // Truncate to fit in BN254 field
  hash[0] = 0;

  return hash;
}

/// Hash bytes with bump seed to fit in BN254 field (legacy method).
///
/// This tries different bump seeds until a valid hash is found.
/// Returns null if no valid hash is found (extremely rare).
(Uint8List, int)? hashToBn254FieldSizeBe(Uint8List bytes) {
  for (var bumpSeed = 255; bumpSeed >= 0; bumpSeed--) {
    final inputWithBump =
        BytesBuilder()
          ..add(bytes)
          ..addByte(bumpSeed);

    final hash = _keccak256(inputWithBump.toBytes());

    if (hash.length != 32) {
      throw StateError('Invalid hash length');
    }

    hash[0] = 0;

    if (_isSmallerThanBn254FieldSize(hash)) {
      return (hash, bumpSeed);
    }
  }

  return null;
}

/// Check if bytes (big-endian) are smaller than the BN254 field size.
bool _isSmallerThanBn254FieldSize(Uint8List bytes) {
  // BN254 field size as bytes (big-endian)
  final fieldSizeBytes = _bigIntToBytes(BN254.fieldSize);

  // Compare byte by byte
  for (var i = 0; i < 32; i++) {
    if (bytes[i] < fieldSizeBytes[i]) return true;
    if (bytes[i] > fieldSizeBytes[i]) return false;
  }

  return false; // Equal to field size, not smaller
}

/// Convert BigInt to 32-byte big-endian Uint8List.
Uint8List _bigIntToBytes(BigInt value) {
  final bytes = Uint8List(32);
  var temp = value;
  for (var i = 31; i >= 0; i--) {
    bytes[i] = (temp & BigInt.from(0xFF)).toInt();
    temp >>= 8;
  }
  return bytes;
}

/// Derive an address seed from seeds and program ID.
///
/// The seed is derived by hashing [programId, ...seeds] together.
Uint8List deriveAddressSeed({
  required List<Uint8List> seeds,
  required Ed25519HDPublicKey programId,
}) {
  final combinedSeeds = [Uint8List.fromList(programId.bytes), ...seeds];

  return hashvToBn254FieldSizeBe(combinedSeeds);
}

/// Derive an address seed using V2 method.
Uint8List deriveAddressSeedV2(List<Uint8List> seeds) =>
    hashvToBn254FieldSizeBeU8Array(seeds);

/// Derive an address for a compressed account.
///
/// The address is derived from a seed and an address Merkle tree public key.
///
/// @param seed - 32-byte seed
/// @param addressMerkleTreePubkey - Merkle tree public key (optional, uses default)
/// @returns Derived address as public key
Ed25519HDPublicKey deriveAddress({
  required Uint8List seed,
  Ed25519HDPublicKey? addressMerkleTreePubkey,
}) {
  if (seed.length != 32) {
    throw ArgumentError('Seed length must be 32 bytes, got ${seed.length}');
  }

  final treePubkey =
      addressMerkleTreePubkey ?? DefaultTestStateTreeAccounts.addressTree;

  final combined =
      BytesBuilder()
        ..add(treePubkey.bytes)
        ..add(seed);

  final result = hashToBn254FieldSizeBe(combined.toBytes());

  if (result == null) {
    throw StateError('Failed to derive address');
  }

  return Ed25519HDPublicKey(result.$1);
}

/// Derive an address using V2 method.
///
/// Matches Rust's derive_address_from_seed implementation.
Ed25519HDPublicKey deriveAddressV2({
  required Uint8List addressSeed,
  required Ed25519HDPublicKey addressMerkleTreePubkey,
  required Ed25519HDPublicKey programId,
}) {
  if (addressSeed.length != 32) {
    throw ArgumentError(
      'Address seed length must be 32 bytes, got ${addressSeed.length}',
    );
  }

  // Match Rust implementation: hash [seed, merkle_tree_pubkey, program_id]
  final combined = [
    addressSeed,
    Uint8List.fromList(addressMerkleTreePubkey.bytes),
    Uint8List.fromList(programId.bytes),
  ];

  final hash = hashvToBn254FieldSizeBeU8Array(combined);
  return Ed25519HDPublicKey(hash);
}
