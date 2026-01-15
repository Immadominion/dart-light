/// Test RPC client for Light Protocol integration tests.
///
/// Provides a TestRpc class that extends the standard Rpc with
/// additional test helpers and mock capabilities.
library;

import 'package:light_sdk/light_sdk.dart';

import 'test_config.dart';

/// Configuration for TestRpc.
class TestRpcConfig {
  const TestRpcConfig({this.depth = 26, this.log = false});

  /// Merkle tree depth.
  final int depth;

  /// Whether to log proof generation time.
  final bool log;
}

/// Test RPC client for integration tests.
///
/// Wraps the standard [Rpc] class with test-specific helpers
/// for local validator testing.
///
/// ## Example
/// ```dart
/// final testRpc = await getTestRpc();
/// final payer = await newAccountWithLamports(testRpc);
///
/// // Compress SOL
/// await compress(testRpc, payer, 1e9.toInt(), payer.publicKey);
/// ```
class TestRpc {
  TestRpc._({required this.rpc, required this.config});

  /// The underlying Rpc instance.
  final Rpc rpc;

  /// Test configuration.
  final TestRpcConfig config;

  /// Get the underlying RPC client.
  RpcClient get rpcClient => rpc.rpcClient;

  /// Create a TestRpc instance for local testing.
  factory TestRpc.create({
    String endpoint = localRpcUrl,
    String compressionApiEndpoint = localCompressionApiUrl,
    String proverEndpoint = localProverUrl,
    ApiVersion apiVersion = ApiVersion.v2,
    TestRpcConfig config = const TestRpcConfig(),
    Duration timeout = const Duration(seconds: 30),
  }) {
    return TestRpc._(
      rpc: Rpc.create(
        endpoint,
        compressionApiEndpoint: compressionApiEndpoint,
        proverEndpoint: proverEndpoint,
        apiVersion: apiVersion,
        timeout: timeout,
      ),
      config: config,
    );
  }

  /// Get the current slot.
  Future<int> getSlot({Commitment commitment = Commitment.confirmed}) async {
    final result = await rpcClient.getSlot(commitment: commitment);
    return result;
  }

  /// Get account balance.
  Future<int> getBalance(
    Ed25519HDPublicKey address, {
    Commitment commitment = Commitment.confirmed,
  }) async {
    final result = await rpcClient.getBalance(
      address.toBase58(),
      commitment: commitment,
    );
    return result.value;
  }

  /// Request an airdrop and wait for confirmation.
  Future<String> requestAirdropAndConfirm(
    Ed25519HDPublicKey address,
    int lamports, {
    Commitment commitment = Commitment.confirmed,
  }) async {
    final signature = await rpcClient.requestAirdrop(
      address.toBase58(),
      lamports,
      commitment: commitment,
    );

    // Wait for confirmation
    await _waitForConfirmation(signature, commitment: commitment);

    return signature;
  }

  /// Wait for transaction confirmation.
  Future<void> _waitForConfirmation(
    String signature, {
    Commitment commitment = Commitment.confirmed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      final statuses = await rpcClient.getSignatureStatuses([signature]);

      if (statuses.value.isNotEmpty && statuses.value.first != null) {
        final status = statuses.value.first!;

        if (status.err != null) {
          throw Exception('Transaction failed: ${status.err}');
        }

        final confirmationStatus = status.confirmationStatus;
        if (confirmationStatus != null) {
          if (commitment == Commitment.processed) {
            return;
          }
          if (commitment == Commitment.confirmed &&
              (confirmationStatus == Commitment.confirmed ||
                  confirmationStatus == Commitment.finalized)) {
            return;
          }
          if (commitment == Commitment.finalized &&
              confirmationStatus == Commitment.finalized) {
            return;
          }
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Transaction confirmation timeout');
  }
}

/// Create a TestRpc instance for local testing.
///
/// This is the primary way to get a TestRpc for integration tests.
///
/// [endpoint] - Solana RPC endpoint (default: local).
/// [compressionApiEndpoint] - Photon API endpoint (default: local).
/// [proverEndpoint] - Prover service endpoint (default: local).
/// [config] - Test configuration.
Future<TestRpc> getTestRpc({
  String endpoint = localRpcUrl,
  String compressionApiEndpoint = localCompressionApiUrl,
  String proverEndpoint = localProverUrl,
  TestRpcConfig config = const TestRpcConfig(),
}) async {
  return TestRpc.create(
    endpoint: endpoint,
    compressionApiEndpoint: compressionApiEndpoint,
    proverEndpoint: proverEndpoint,
    config: config,
  );
}
