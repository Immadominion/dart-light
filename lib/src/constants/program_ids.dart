import 'dart:typed_data';

import 'package:solana/solana.dart';

/// Light Protocol program IDs.
class LightProgramIds {
  LightProgramIds._();

  /// Light System Program ID.
  static final lightSystemProgram = Ed25519HDPublicKey.fromBase58(
    'SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7',
  );

  /// Account Compression Program ID.
  static final accountCompressionProgram = Ed25519HDPublicKey.fromBase58(
    'compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq',
  );

  /// Noop Program ID (for event logging).
  static final noopProgram = Ed25519HDPublicKey.fromBase58(
    'noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV',
  );

  /// Compressed Token Program ID.
  static final compressedTokenProgram = Ed25519HDPublicKey.fromBase58(
    'cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m',
  );

  /// Registry Program ID.
  static final registryProgram = Ed25519HDPublicKey.fromBase58(
    'Lighton6oQpVkeewmo2mcPTQQp7kYHr4fWpAgJyEmDX',
  );

  /// System Program ID.
  static final systemProgram = Ed25519HDPublicKey.fromBase58(
    '11111111111111111111111111111111',
  );
}

/// Get the registered program PDA.
Ed25519HDPublicKey getRegisteredProgramPda() => Ed25519HDPublicKey.fromBase58(
  '35hkDgaAKwMCaxRz2ocSZ6NaUrtKkyNqU6c4RV3tYJRh',
);

/// Account compression authority PDA (pre-computed).
/// Derived from seeds: ["cpi_authority"] with Light System Program ID.
final accountCompressionAuthority = Ed25519HDPublicKey.fromBase58(
  'HwXnGK3tPkkVY6P439H2p68AxpeuWXd5PcrAxFpbmfbA',
);

/// Get the account compression authority PDA.
@Deprecated('Use accountCompressionAuthority constant instead')
Future<Ed25519HDPublicKey> getAccountCompressionAuthority() async {
  final seeds = [Uint8List.fromList('cpi_authority'.codeUnits)];
  return Ed25519HDPublicKey.findProgramAddress(
    seeds: seeds,
    programId: LightProgramIds.lightSystemProgram,
  );
}

/// Default static accounts for Light Protocol transactions.
class DefaultStaticAccounts {
  DefaultStaticAccounts._();

  static final registeredProgramPda = getRegisteredProgramPda();
  static final noopProgram = LightProgramIds.noopProgram;
  static final accountCompressionProgram =
      LightProgramIds.accountCompressionProgram;

  /// Account compression authority PDA (pre-computed).
  static final accountCompressionAuthorityPda = accountCompressionAuthority;
}

/// Instruction discriminators for Light Protocol programs.
class LightDiscriminators {
  LightDiscriminators._();

  /// Invoke instruction discriminator (Light System Program).
  static final invoke = Uint8List.fromList([26, 16, 169, 7, 21, 202, 242, 25]);

  /// Invoke CPI instruction discriminator.
  static final invokeCpi = Uint8List.fromList([
    49,
    212,
    191,
    129,
    39,
    194,
    43,
    196,
  ]);

  /// Invoke CPI with read-only discriminator.
  static final invokeCpiWithReadOnly = Uint8List.fromList([
    86,
    47,
    163,
    166,
    21,
    223,
    92,
    8,
  ]);

  /// Invoke CPI with account info discriminator.
  static final invokeCpiWithAccountInfo = Uint8List.fromList([
    228,
    34,
    128,
    84,
    47,
    139,
    86,
    240,
  ]);

  /// Insert into queues discriminator.
  static final insertIntoQueues = Uint8List.fromList([
    180,
    143,
    159,
    153,
    35,
    46,
    248,
    163,
  ]);

  /// Create token pool discriminator (Compressed Token Program).
  /// Note: This is the newer version discriminator.
  static final createTokenPool = Uint8List.fromList([
    23,
    169,
    27,
    122,
    147,
    169,
    209,
    152,
  ]);

  /// Mint to discriminator (Compressed Token Program).
  static final mintTo = Uint8List.fromList([
    241,
    34,
    48,
    186,
    37,
    179,
    123,
    192,
  ]);

  /// Transfer discriminator (Compressed Token Program).
  static final transfer = Uint8List.fromList([
    163,
    52,
    200,
    231,
    140,
    3,
    69,
    186,
  ]);

  /// Batch compress discriminator (Compressed Token Program).
  static final batchCompress = Uint8List.fromList([
    65,
    206,
    101,
    37,
    147,
    42,
    221,
    144,
  ]);

  /// Compress SPL token account discriminator.
  static final compressSplTokenAccount = Uint8List.fromList([
    112,
    230,
    105,
    101,
    145,
    202,
    157,
    97,
  ]);

  /// Approve discriminator (Compressed Token Program).
  static final approve = Uint8List.fromList([
    69,
    74,
    217,
    36,
    115,
    117,
    97,
    76,
  ]);

  /// Revoke discriminator (Compressed Token Program).
  static final revoke = Uint8List.fromList([
    170,
    23,
    31,
    34,
    133,
    173,
    93,
    242,
  ]);

  /// Add token pool discriminator.
  static final addTokenPool = Uint8List.fromList([
    114,
    143,
    210,
    73,
    96,
    115,
    1,
    228,
  ]);

  /// Decompress accounts idempotent discriminator.
  static final decompressAccountsIdempotent = Uint8List.fromList([107]);
}

/// Alias for backwards compatibility.
typedef Discriminators = LightDiscriminators;

/// API Version enum for Light Protocol.
enum LightApiVersion {
  /// Version 1 API (legacy).
  v1,

  /// Version 2 API (default, batched trees).
  v2,
}

/// Feature flags for Light Protocol SDK.
class LightFeatureFlags {
  LightFeatureFlags._();

  /// Current API version. Default is V2.
  static LightApiVersion version = LightApiVersion.v2;

  /// Check if using V2 API.
  static bool get isV2 => version == LightApiVersion.v2;

  /// Get versioned endpoint name.
  /// E.g., 'getCompressedAccount' becomes 'getCompressedAccountV2' for V2.
  static String versionedEndpoint(String base) => isV2 ? '${base}V2' : base;
}

/// Fee constants for Light Protocol.
class LightFees {
  LightFees._();

  /// State Merkle tree rollover fee per output compressed account (V2).
  static final stateMerkleTreeRolloverFeeV2 = BigInt.one;

  /// State Merkle tree rollover fee per output compressed account (V1).
  static final stateMerkleTreeRolloverFeeV1 = BigInt.from(300);

  /// Get state Merkle tree rollover fee based on current API version.
  static BigInt get stateMerkleTreeRolloverFee =>
      LightFeatureFlags.isV2
          ? stateMerkleTreeRolloverFeeV2
          : stateMerkleTreeRolloverFeeV1;

  /// Address queue rollover fee.
  static final addressQueueRolloverFee = BigInt.from(392);

  /// State Merkle tree network fee (charged if nullifying compressed accounts).
  static final stateMerkleTreeNetworkFee = BigInt.from(5000);

  /// Address tree network fee V1.
  static final addressTreeNetworkFeeV1 = BigInt.from(5000);

  /// Address tree network fee V2.
  static final addressTreeNetworkFeeV2 = BigInt.from(10000);

  /// Get address tree network fee based on current API version.
  static BigInt get addressTreeNetworkFee =>
      LightFeatureFlags.isV2
          ? addressTreeNetworkFeeV2
          : addressTreeNetworkFeeV1;

  /// SPL Token mint rent-exempt balance.
  static const splTokenMintRentExemptBalance = 1461600;
}

/// UTXO management constants.
class UtxoConstants {
  UtxoConstants._();

  /// Threshold (per asset) at which new in-UTXOs get merged.
  static const mergeThreshold = 20;

  /// Maximum number of UTXOs to merge at once.
  static const mergeMaximum = 10;
}

/// Compute budget pattern for Light Protocol transactions.
final computeBudgetPattern = Uint8List.fromList([2, 64, 66, 15, 0]);
