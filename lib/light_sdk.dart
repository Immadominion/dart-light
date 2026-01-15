/// Light Protocol SDK for Dart
///
/// A comprehensive Dart client for Light Protocol ZK Compression on Solana,
/// providing complete feature parity with the TypeScript
/// `@lightprotocol/stateless.js` and `@lightprotocol/compressed-token` packages.
///
/// ## Features
///
/// - **🗜️ ZK Compression**: Compress SOL and SPL tokens for 1000x cost reduction
/// - **🔒 Type-Safe**: Full type safety with Dart's null safety and strong typing
/// - **📱 Mobile-First**: Designed for Flutter mobile applications
/// - **⚡ Modern Async**: Idiomatic Dart async/await patterns
/// - **🎯 TypeScript Parity**: Complete compatibility with JS SDK
///
/// ## Quick Start
///
/// ```dart
/// import 'package:light_sdk/light_sdk.dart';
/// import 'package:solana/solana.dart';
///
/// // Create RPC connection with compression support
/// final rpc = Rpc.create(
///   'https://mainnet.helius-rpc.com?api-key=YOUR_KEY',
/// );
///
/// // Compress SOL
/// final signature = await compress(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(1000000000), // 1 SOL
///   toAddress: wallet.publicKey,
/// );
///
/// // Transfer compressed SOL
/// final txId = await transfer(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(100000),
///   owner: wallet,
///   toAddress: recipientPubkey,
/// );
///
/// // Get compressed balance
/// final balance = await rpc.getCompressedBalanceByOwner(wallet.publicKey);
/// ```
///
/// ## Core Concepts
///
/// ### Compressed Accounts
/// Compressed accounts store state in Merkle trees instead of on-chain accounts.
/// This reduces rent costs dramatically while maintaining security guarantees
/// through zero-knowledge proofs.
///
/// ### Validity Proofs
/// Every state transition requires a validity proof from the indexer (Photon API).
/// The SDK handles proof fetching automatically in high-level actions.
///
/// ### State Trees
/// Compressed accounts are organized in state trees. The SDK manages tree
/// selection and proof construction automatically.
///
/// ## Architecture
///
/// - [Rpc] - Extended Solana RPC client with compression API support
/// - [LightSystemProgram] - Core compression program interface
/// - [CompressedTokenProgram] - SPL token compression operations
/// - [CompressedAccount] - Compressed account data structures
///
/// ## Dependencies
///
/// This SDK uses:
/// - `solana` package from espresso-cash for Solana primitives
///
/// @see https://www.zkcompression.com/ for protocol documentation
library;

// Core exports
export 'src/actions/actions.dart';
export 'src/constants/constants.dart';
export 'src/errors/errors.dart';
export 'src/programs/programs.dart';
export 'src/rpc/rpc.dart';
export 'src/signer/signer.dart';
export 'src/state/state.dart';
export 'src/utils/utils.dart';

// Token exports
export 'src/token/token.dart';
