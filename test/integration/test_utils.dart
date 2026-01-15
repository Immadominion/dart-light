/// Test utilities for Light Protocol integration tests.
///
/// Provides helper functions for creating test accounts, managing airdrops,
/// and common test operations.
library;

import 'dart:typed_data';

import 'package:light_sdk/light_sdk.dart';

import 'test_config.dart';
import 'test_rpc.dart';

/// Well-known test keypairs for consistent testing.
///
/// These are derived from deterministic seeds for reproducibility.
class TestKeypairs {
  /// Generate a test keypair from a counter value.
  ///
  /// Counter values 0-255 produce deterministic keypairs.
  /// Values > 255 produce random keypairs.
  static Future<Ed25519HDKeyPair> fromCounter(int counter) async {
    if (counter > 255) {
      return Ed25519HDKeyPair.random();
    }

    // Create deterministic seed from counter
    final seed = Uint8List(32);
    seed[0] = counter;
    // Fill rest with a deterministic pattern
    for (var i = 1; i < 32; i++) {
      seed[i] = (counter + i) % 256;
    }

    return Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed.toList());
  }

  /// Alice - test keypair with counter 255.
  static Future<Ed25519HDKeyPair> get alice => fromCounter(255);

  /// Bob - test keypair with counter 254.
  static Future<Ed25519HDKeyPair> get bob => fromCounter(254);

  /// Charlie - test keypair with counter 253.
  static Future<Ed25519HDKeyPair> get charlie => fromCounter(253);

  /// Dave - test keypair with counter 252.
  static Future<Ed25519HDKeyPair> get dave => fromCounter(252);
}

/// Create a new account and fund it with an airdrop.
///
/// [testRpc] - The TestRpc client to use.
/// [lamports] - Amount of lamports to airdrop (default 1 SOL).
/// [counter] - Optional counter for deterministic keypair generation.
///
/// Returns the funded keypair.
Future<Ed25519HDKeyPair> newAccountWithLamports(
  TestRpc testRpc, {
  int? lamports,
  int? counter,
}) async {
  final airdropAmount = lamports ?? lamportsPerSol;
  final account = await TestKeypairs.fromCounter(counter ?? 256);

  // Request airdrop
  final signature = await testRpc.rpcClient.requestAirdrop(
    account.publicKey.toBase58(),
    airdropAmount,
    commitment: Commitment.confirmed,
  );

  // Wait for confirmation
  await confirmTransaction(testRpc, signature);

  return account;
}

/// Confirm a transaction by waiting for its signature status.
///
/// [testRpc] - The TestRpc client.
/// [signature] - Transaction signature to confirm.
/// [commitment] - Commitment level (default: confirmed).
/// [timeoutMs] - Timeout in milliseconds (default: 60000).
Future<void> confirmTransaction(
  TestRpc testRpc,
  String signature, {
  Commitment commitment = Commitment.confirmed,
  int timeoutMs = defaultTimeoutMs,
}) async {
  final startTime = DateTime.now();
  final timeout = Duration(milliseconds: timeoutMs);

  while (DateTime.now().difference(startTime) < timeout) {
    final statuses = await testRpc.rpcClient.getSignatureStatuses([signature]);

    if (statuses.value.isNotEmpty && statuses.value.first != null) {
      final status = statuses.value.first!;

      // Check for error
      if (status.err != null) {
        throw Exception('Transaction failed: ${status.err}');
      }

      // Check commitment level
      final confirmationStatus = status.confirmationStatus;
      if (confirmationStatus != null) {
        if (commitment == Commitment.processed) {
          return; // Any status is sufficient
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

    // Wait before polling again
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw Exception('Transaction confirmation timeout after ${timeoutMs}ms');
}

/// Get the balance of an account in lamports.
Future<int> getBalance(TestRpc testRpc, Ed25519HDPublicKey address) async {
  final result = await testRpc.rpcClient.getBalance(
    address.toBase58(),
    commitment: Commitment.confirmed,
  );
  return result.value;
}

/// Calculate expected fees for transactions.
///
/// [txs] - List of transaction descriptions with input/output counts.
///
/// Returns total expected fees in lamports.
BigInt calculateExpectedFees(List<TxFeeParams> txs) {
  var totalFee = BigInt.zero;

  for (final tx in txs) {
    // Base Solana transaction fee
    final baseFee = tx.baseFee ?? BigInt.from(5000);

    // State tree rollover fee per output
    final stateOutFee =
        LightFees.stateMerkleTreeRolloverFee * BigInt.from(tx.outputs);

    // Address queue rollover fee per new address
    final addrFee =
        tx.addresses != null
            ? LightFees.addressQueueRolloverFee * BigInt.from(tx.addresses!)
            : BigInt.zero;

    // Network fee for nullifying inputs (V2: once per tx, V1: per input)
    final networkInFee =
        tx.inputs > 0
            ? LightFees.stateMerkleTreeNetworkFee
            : (tx.outputs > 0
                ? LightFees.stateMerkleTreeNetworkFee
                : BigInt.zero);

    // Network fee per address created
    final networkAddressFee =
        tx.addresses != null
            ? LightFees.addressTreeNetworkFeeV1 * BigInt.from(tx.addresses!)
            : BigInt.zero;

    totalFee +=
        baseFee + stateOutFee + addrFee + networkInFee + networkAddressFee;
  }

  return totalFee;
}

/// Parameters for calculating transaction fees.
class TxFeeParams {
  const TxFeeParams({
    required this.inputs,
    required this.outputs,
    this.addresses,
    this.baseFee,
  });

  /// Number of input compressed accounts.
  final int inputs;

  /// Number of output compressed accounts.
  final int outputs;

  /// Number of new addresses created (optional).
  final int? addresses;

  /// Base Solana transaction fee (optional, defaults to 5000).
  final BigInt? baseFee;
}

/// Deep equality comparison for test assertions.
///
/// Handles BigInt comparison correctly.
bool deepEqual(dynamic ref, dynamic val) {
  if (ref.runtimeType != val.runtimeType) {
    return false;
  }

  if (ref is BigInt && val is BigInt) {
    return ref == val;
  }

  if (ref is List && val is List) {
    if (ref.length != val.length) {
      return false;
    }
    for (var i = 0; i < ref.length; i++) {
      if (!deepEqual(ref[i], val[i])) {
        return false;
      }
    }
    return true;
  }

  if (ref is Map && val is Map) {
    if (ref.length != val.length) {
      return false;
    }
    for (final key in ref.keys) {
      if (!val.containsKey(key) || !deepEqual(ref[key], val[key])) {
        return false;
      }
    }
    return true;
  }

  return ref == val;
}

/// Assert that two values are deeply equal.
void assertDeepEqual(dynamic expected, dynamic actual, [String? message]) {
  if (!deepEqual(expected, actual)) {
    throw AssertionError(message ?? 'Expected $expected but got $actual');
  }
}
