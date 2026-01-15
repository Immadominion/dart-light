# Dart Light Protocol SDK - Copilot Instructions

## Project Overview

This is the **Dart Light Protocol SDK** (`dart-light`), a complete port of the TypeScript `@lightprotocol/stateless.js` and `@lightprotocol/compressed-token` packages. It provides Dart/Flutter applications with full access to Light Protocol's ZK Compression on Solana.

## Critical Requirements

### Solana Primitives

**ALWAYS use the `solana` package from espresso-cash** for all Solana-related operations:
- `Ed25519HDPublicKey` for public keys
- `Ed25519HDKeyPair` for keypairs  
- `RpcClient` for base Solana RPC
- `Instruction` for transaction instructions
- `AccountMeta` for account metadata
- `SignedTx` for signed transactions

**DO NOT:**
- Use any other Solana Dart packages
- Create custom public key implementations
- Use web3.js concepts that don't translate

### Program Interactions

Use `coral_xyz` for Anchor program interactions when needed. The Anchor client provides IDL-based program invocation.

### No Mocking

**NEVER mock or simulate:**
- RPC calls
- Cryptographic operations  
- ZK proof generation
- Transaction signing

All implementations must be real and production-ready.

## Architecture

### Directory Structure

```
lib/
├── light_sdk.dart              # Main library export
└── src/
    ├── actions/                # High-level operations
    │   ├── compress.dart
    │   ├── decompress.dart
    │   ├── transfer.dart
    │   └── create_account.dart
    ├── constants/              # Program IDs, discriminators
    │   ├── program_ids.dart
    │   └── tree_config.dart
    ├── errors/                 # Typed exceptions
    │   └── light_errors.dart
    ├── programs/               # Instruction builders
    │   ├── light_system_program.dart
    │   ├── pack.dart
    │   └── instruction_data.dart
    ├── rpc/                    # RPC layer
    │   ├── compression_api.dart
    │   └── rpc_types.dart
    ├── state/                  # Data types
    │   ├── bn254.dart
    │   ├── compressed_account.dart
    │   ├── tree_info.dart
    │   └── validity_proof.dart
    ├── token/                  # Compressed token operations
    │   ├── compressed_token_program.dart
    │   └── token_utils.dart
    └── utils/                  # Helpers
        ├── address.dart
        ├── account_selection.dart
        └── transaction_utils.dart
```

### Key Classes

- `Rpc` - Extended Solana RPC with compression API (Photon)
- `LightSystemProgram` - Core compression program
- `CompressedTokenProgram` - Token compression
- `BN254` - 254-bit field element for ZK proofs
- `CompressedAccount` - Compressed account data
- `TreeInfo` - State tree metadata
- `ValidityProof` - ZK validity proof

## TypeScript Parity

When implementing features, reference the TypeScript SDK:
- `js/stateless.js/src/` - Core SDK
- `js/compressed-token/src/` - Token SDK

Maintain API parity where possible, but adapt to Dart idioms.

## Code Conventions

### Dart Style

- Use `dart format` for formatting
- Follow effective_dart lints
- Prefer `BigInt` over external big number libraries
- Use `Uint8List` for byte arrays
- Use records for tuple-like returns: `(T, U)`

### Naming

- Classes: `PascalCase`
- Methods/functions: `camelCase`  
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`
- Private members: `_prefixed`

### Error Handling

- Use typed exceptions from `errors/light_errors.dart`
- Never swallow errors silently
- Provide helpful error messages

### Documentation

- Document all public APIs
- Include code examples in doc comments
- Use `///` for doc comments

## Program IDs

```dart
class LightProgramIds {
  static const lightSystemProgram = 'SySTEM1eSU2p4BGQfQpimFEWWSC1XDFeun3Nqzz3rT7';
  static const accountCompression = 'compr6CUsB5m2jS4Y3831ztGSTnDpnKJTKS95d64XVq';
  static const compressedToken = 'cTokenmWW8bLPjZEBAUgYy3zKxQZW6VKi7bqNFEVv3m';
  static const registeredProgramPda = 'Fg5jiMFLEg8bKd18jJq8d7mSdzJbD14oVNWctXRFFfTr';
  static const noopProgram = 'noopb9bkMVfRPU8AsbpTUg8AQkHtKwMYZiFUjNRtMmV';
}
```

## API Version

The SDK supports API V2 by default, with fallback to V1. The `Rpc` class handles versioning automatically.

## Testing

Tests should be in `test/` directory. Use the TypeScript SDK tests as reference:
- `js/stateless.js/tests/`
- `js/compressed-token/tests/`

## Dependencies

From `pubspec.yaml`:
- `solana: ^0.31.2` - Espresso Cash Solana package
- `coral_xyz` - Anchor client (path dependency)
- `borsh_annotation` - Serialization
- `equatable` - Value equality
- `http` - HTTP client
- `crypto` - Hashing

## Common Patterns

### Building Transactions

```dart
final instruction = LightSystemProgram.compress(
  payer: wallet.publicKey,
  toAddress: wallet.publicKey,
  lamports: BigInt.from(1000000000),
  outputStateTreeInfo: treeInfo,
);

final signedTx = await buildAndSignTransaction(
  rpc: rpc,
  signer: wallet,
  instructions: [instruction],
);

final signature = await sendAndConfirmTransaction(
  rpc: rpc,
  signedTx: signedTx,
);
```

### Getting Validity Proofs

```dart
final accounts = await rpc.getCompressedAccountsByOwner(owner);
final hashes = accounts.items.map((a) => a.hash).toList();
final proof = await rpc.getValidityProof(hashes: hashes);
```

### Account Selection

```dart
final (selectedAccounts, total) = selectMinCompressedSolAccountsForTransfer(
  accounts,
  transferAmount,
);
```

## Mobile Considerations

This SDK is designed for mobile (Flutter). Keep in mind:
- Minimize memory allocations
- Handle network failures gracefully
- Support offline caching where appropriate
- Be mindful of battery/data usage
