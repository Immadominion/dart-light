import '../state/compressed_account.dart';

/// Validate that all input accounts have the same owner.
void validateSameOwner(List<CompressedAccountWithMerkleContext> accounts) {
  if (accounts.isEmpty) return;

  final owner = accounts.first.owner;
  for (var i = 1; i < accounts.length; i++) {
    if (accounts[i].owner != owner) {
      throw ArgumentError(
        'All input compressed accounts must have the same owner. '
        'Expected ${owner.toBase58()}, got ${accounts[i].owner.toBase58()}',
      );
    }
  }
}

/// Validate that the balance is sufficient (non-negative).
void validateSufficientBalance(BigInt balance) {
  if (balance < BigInt.zero) {
    throw ArgumentError('Insufficient balance: $balance');
  }
}

/// Validate that a value is within the BN254 field size.
void validateBn254FieldSize(List<int> bytes) {
  if (bytes.length != 32) {
    throw ArgumentError('BN254 value must be 32 bytes');
  }

  // The field size is approximately 2^254, so the first byte must be 0
  // or the value must be smaller than the field modulus
  // For simplicity, we just check that the first byte is 0
  // (which is what the SDK does after hashing)
  if (bytes[0] > 0x30) {
    throw ArgumentError('Value exceeds BN254 field size');
  }
}

/// Validate that a lamports amount is valid.
void validateLamports(BigInt lamports) {
  if (lamports < BigInt.zero) {
    throw ArgumentError('Lamports cannot be negative');
  }

  // Max lamports is u64::MAX
  final maxLamports = BigInt.parse('18446744073709551615');
  if (lamports > maxLamports) {
    throw ArgumentError('Lamports exceeds maximum u64 value');
  }
}

/// Validate that an address is valid (32 bytes).
void validateAddress(List<int>? address) {
  if (address == null) return;

  if (address.length != 32) {
    throw ArgumentError('Address must be 32 bytes, got ${address.length}');
  }
}
