/// Integration test configuration for Light Protocol SDK.
///
/// These tests require a local Solana validator with Light Protocol programs
/// deployed, along with Photon indexer and prover services.
///
/// To run integration tests:
/// 1. Start local Solana validator: `solana-test-validator`
/// 2. Deploy Light Protocol programs
/// 3. Start Photon indexer
/// 4. Start prover service
/// 5. Run: `dart test test/integration/`
library;

import 'package:solana/solana.dart';

// Re-export solana package for integration tests
export 'package:solana/solana.dart';

/// Default local Solana RPC endpoint.
const String localRpcUrl = 'http://127.0.0.1:8899';

/// Default local Solana WebSocket endpoint.
const String localWsUrl = 'ws://127.0.0.1:8900';

/// Default Photon compression API endpoint.
const String localCompressionApiUrl = 'http://127.0.0.1:8784';

/// Default prover service endpoint.
const String localProverUrl = 'http://127.0.0.1:3001';

/// Devnet Solana RPC endpoint.
const String devnetRpcUrl = 'https://api.devnet.solana.com';

/// Devnet Solana WebSocket endpoint.
const String devnetWsUrl = 'wss://api.devnet.solana.com';

/// Devnet Photon compression API endpoint.
const String devnetCompressionApiUrl = 'https://devnet.helius-rpc.com';

/// Default commitment level for tests.
const String defaultCommitment = 'confirmed';

/// Default timeout for transactions in milliseconds.
const int defaultTimeoutMs = 60000;

/// Default airdrop amount for test accounts (1 SOL).
final int defaultAirdropLamports = lamportsPerSol;

/// Check if running in CI environment.
bool get isCI => const bool.fromEnvironment('CI', defaultValue: false);

/// Get the RPC URL from environment or use default.
String get rpcUrl =>
    const String.fromEnvironment('SOLANA_RPC_URL', defaultValue: localRpcUrl);

/// Get the WebSocket URL from environment or use default.
String get wsUrl =>
    const String.fromEnvironment('SOLANA_WS_URL', defaultValue: localWsUrl);

/// Get the compression API URL from environment or use default.
String get compressionApiUrl => const String.fromEnvironment(
  'COMPRESSION_API_URL',
  defaultValue: localCompressionApiUrl,
);

/// Get the prover URL from environment or use default.
String get proverUrl =>
    const String.fromEnvironment('PROVER_URL', defaultValue: localProverUrl);
