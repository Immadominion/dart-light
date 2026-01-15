import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:solana/solana.dart';

/// BN254 field element - a 254-bit number used in ZK proofs.
///
/// This type represents elements of the BN254 scalar field, which is the
/// cryptographic field used for Poseidon hashing and ZK proof verification
/// in Light Protocol.
///
/// The field size is:
/// 21888242871839275222246405745257275088548364400416034343698204186575808495617
class BN254 extends Equatable {
  const BN254._(this._bytes);

  /// Create a BN254 from a 32-byte array (big-endian).
  factory BN254.fromBytes(Uint8List bytes) {
    if (bytes.length != 32) {
      throw ArgumentError(
        'BN254 must be exactly 32 bytes, got ${bytes.length}',
      );
    }
    return BN254._(Uint8List.fromList(bytes));
  }

  /// Create a BN254 from a BigInt value.
  factory BN254.fromBigInt(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('BN254 cannot be negative');
    }
    if (value >= fieldSize) {
      throw ArgumentError('BN254 value exceeds field size');
    }

    final bytes = Uint8List(32);
    var temp = value;
    for (var i = 31; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp >>= 8;
    }
    return BN254._(bytes);
  }

  /// Create a BN254 from a base58-encoded string.
  factory BN254.fromBase58(String base58) {
    final bytes = Ed25519HDPublicKey.fromBase58(base58).bytes;
    return BN254.fromBytes(Uint8List.fromList(bytes.toList()));
  }

  /// Create a BN254 from a public key.
  factory BN254.fromPublicKey(Ed25519HDPublicKey pubkey) =>
      BN254.fromBytes(Uint8List.fromList(pubkey.bytes.toList()));

  /// Zero value.
  static final BN254 zero = BN254.fromBigInt(BigInt.zero);

  /// The BN254 field size.
  static final BigInt fieldSize = BigInt.parse(
    '21888242871839275222246405745257275088548364400416034343698204186575808495617',
  );

  /// The highest valid address plus one.
  static final BigInt highestAddressPlusOne = BigInt.parse(
    '452312848583266388373324160190187140051835877600158453279131187530910662655',
  );

  final Uint8List _bytes;

  /// Get the raw bytes (big-endian, 32 bytes).
  Uint8List get bytes => Uint8List.fromList(_bytes);

  /// Convert to BigInt.
  BigInt toBigInt() {
    var result = BigInt.zero;
    for (var i = 0; i < 32; i++) {
      result = (result << 8) | BigInt.from(_bytes[i]);
    }
    return result;
  }

  /// Convert to base58 string.
  String toBase58() => Ed25519HDPublicKey(bytes.toList()).toBase58();

  /// Convert to a list of integers (for serialization).
  List<int> toList() => _bytes.toList();

  /// Check if this value is zero.
  bool get isZero => toBigInt() == BigInt.zero;

  @override
  List<Object?> get props => [_bytes];

  @override
  String toString() => 'BN254(${toBase58()})';
}

/// Extension to create BN254 from BigInt.
extension BigIntToBN254 on BigInt {
  /// Convert this BigInt to a BN254 field element.
  BN254 toBN254() => BN254.fromBigInt(this);
}
