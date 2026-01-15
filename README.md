![Light Protocol Dart SDK](dart-light.png)

# Light Protocol SDK for Dart

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.7.0-blue.svg)](https://dart.dev)
[![Tests](https://img.shields.io/badge/tests-275%20passing-green.svg)](test/)

A Dart/Flutter SDK for [Light Protocol](https://lightprotocol.com/) ZK Compression on Solana.

## The Story

I was building a mobile app that needed cheap token transfers on Solana. When I discovered Light Protocol's ZK Compression (1000x cheaper!), I was excited—until I realized there was no Dart SDK. Only TypeScript and Rust.

So I ported it. This is a Dart implementation of `@lightprotocol/stateless.js` and `@lightprotocol/compressed-token`, built for Flutter developers who want to use ZK compression without leaving the Dart ecosystem.

## What This SDK Does

- **Compress SOL** → Store SOL in compressed accounts (way cheaper)
- **Transfer Compressed SOL** → Move compressed SOL between accounts
- **Decompress SOL** → Convert back to regular SOL when needed
- **Compressed Tokens** → Same operations for SPL tokens

## Installation

```yaml
dependencies:
  light_sdk:
    git:
      url: https://github.com/Lightprotocol/light-protocol.git
      path: dart-light
```

> Note: This package depends on the `solana` package from [espresso-cash](https://github.com/espresso-cash/espresso-cash-public).

## Quick Start

```dart
import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';

void main() async {
  // Connect to RPC with compression API support
  final rpc = Rpc.create(
    'https://mainnet.helius-rpc.com?api-key=YOUR_KEY',
  );

  // Your wallet
  final wallet = await Ed25519HDKeyPair.fromMnemonic('your mnemonic...');

  // Compress 1 SOL
  final signature = await compress(
    rpc: rpc,
    payer: wallet,
    lamports: BigInt.from(1000000000),
    toAddress: wallet.publicKey,
  );
  print('Compressed! Signature: $signature');

  // Check compressed balance
  final balance = await rpc.getCompressedBalanceByOwner(wallet.publicKey);
  print('Compressed balance: $balance lamports');

  // Transfer to someone
  final recipient = Ed25519HDPublicKey.fromBase58('...');
  await transfer(
    rpc: rpc,
    payer: wallet,
    owner: wallet,
    lamports: BigInt.from(100000),
    toAddress: recipient,
  );
}
```

## API Overview

### High-Level Actions

```dart
// Compress SOL
await compress(rpc: rpc, payer: wallet, lamports: amount, toAddress: recipient);

// Transfer compressed SOL
await transfer(rpc: rpc, payer: wallet, owner: wallet, lamports: amount, toAddress: recipient);

// Decompress back to regular SOL
await decompress(rpc: rpc, payer: wallet, lamports: amount, recipient: recipient);
```

### RPC Methods

```dart
// Get compressed accounts
final accounts = await rpc.getCompressedAccountsByOwner(owner);

// Get compressed balance
final balance = await rpc.getCompressedBalanceByOwner(owner);

// Get validity proof (needed for transactions)
final proof = await rpc.getValidityProof(hashes: [accountHash]);

// Get token balances
final tokens = await rpc.getCompressedTokenBalancesByOwner(owner);
```

### Compressed Tokens

```dart
// Create token pool (one-time setup per mint)
final poolInstruction = CompressedTokenProgram.createSplInterface(
  payer: wallet.publicKey,
  mint: mintPubkey,
);

// Mint compressed tokens
final mintInstruction = CompressedTokenProgram.mintTo(
  payer: wallet.publicKey,
  mint: mintPubkey,
  authority: mintAuthority.publicKey,
  amount: BigInt.from(1000000),
  toPubkey: recipient,
  outputStateTreeInfo: treeInfo,
);

// Transfer compressed tokens
final transferInstruction = CompressedTokenProgram.transfer(
  payer: wallet.publicKey,
  inputCompressedTokenAccounts: inputAccounts,
  toAddress: recipient,
  amount: BigInt.from(1000),
  recentInputStateRootIndices: proof.rootIndices,
  recentValidityProof: proof.compressedProof,
);
```

## Examples

Check out the [example/](example/) directory:

- `basic_usage.dart` - Compress, transfer, and decompress SOL
- `compressed_tokens.dart` - Working with compressed SPL tokens
- `advanced_usage.dart` - Manual transaction building, validity proofs
- `flutter_integration.dart` - Patterns for Flutter apps

## Requirements

- Dart SDK ≥ 3.7.0
- An RPC endpoint with compression API support (e.g., [Helius](https://helius.dev/))

## How It Works

Light Protocol uses ZK compression to store account state in Merkle trees instead of on-chain accounts. This means:

1. **No rent** - Compressed accounts don't pay rent
2. **Cheaper transactions** - State changes are smaller
3. **Same security** - Zero-knowledge proofs ensure validity

The trade-off is that you need an indexer (like [Photon](https://github.com/helius-labs/photon)) to query compressed state. This SDK handles that automatically through the RPC layer.

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

Apache 2.0 - see [LICENSE](LICENSE)

## Links

- [Light Protocol Docs](https://www.zkcompression.com/)
- [TypeScript SDK](https://github.com/Lightprotocol/light-protocol/tree/main/js/stateless.js)
- [Photon Indexer](https://github.com/helius-labs/photon)
- [Helius RPC](https://helius.dev/)

---

*Built with ☕ and frustration that there was no Dart SDK.*
