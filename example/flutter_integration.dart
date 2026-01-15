// ignore_for_file: avoid_print

/// Flutter integration example for Light Protocol SDK.
///
/// This example demonstrates how to integrate the Light Protocol SDK
/// into a Flutter application with proper state management patterns.
///
/// Note: This is a conceptual example showing patterns - it won't run
/// standalone as it requires a Flutter environment.
library;

import 'dart:async';

import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';

// ============================================================
// 1. Service Layer Pattern
// ============================================================

/// Service class for Light Protocol operations.
///
/// Encapsulates all compression-related operations in a single service
/// that can be injected into your widgets or state management solution.
class LightProtocolService {
  LightProtocolService({
    required String rpcEndpoint,
    String? compressionApiEndpoint,
    String? proverEndpoint,
  }) : _rpc = Rpc.create(
         rpcEndpoint,
         compressionApiEndpoint: compressionApiEndpoint,
         proverEndpoint: proverEndpoint,
       );

  final Rpc _rpc;

  // StreamControllers for reactive updates
  final _balanceController = StreamController<BigInt>.broadcast();
  final _accountsController =
      StreamController<List<CompressedAccountWithMerkleContext>>.broadcast();

  /// Stream of compressed balance updates.
  Stream<BigInt> get balanceStream => _balanceController.stream;

  /// Stream of compressed account updates.
  Stream<List<CompressedAccountWithMerkleContext>> get accountsStream =>
      _accountsController.stream;

  /// Get current compressed balance.
  Future<BigInt> getBalance(Ed25519HDPublicKey owner) async {
    try {
      final balance = await _rpc.getCompressedBalanceByOwner(owner);
      _balanceController.add(balance);
      return balance;
    } catch (e) {
      _balanceController.add(BigInt.zero);
      return BigInt.zero;
    }
  }

  /// Get compressed accounts with caching.
  Future<List<CompressedAccountWithMerkleContext>> getAccounts(
    Ed25519HDPublicKey owner,
  ) async {
    final result = await _rpc.getCompressedAccountsByOwner(owner);
    _accountsController.add(result.items);
    return result.items;
  }

  /// Compress SOL with progress callback.
  Future<String> compressSol({
    required Ed25519HDKeyPair wallet,
    required BigInt amount,
    Ed25519HDPublicKey? recipient,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Preparing transaction...');

    try {
      final signature = await compress(
        rpc: _rpc,
        payer: wallet,
        lamports: amount,
        toAddress: recipient ?? wallet.publicKey,
      );

      onProgress?.call('Transaction confirmed!');

      // Refresh balance after successful compression
      await getBalance(wallet.publicKey);

      return signature;
    } on InsufficientBalanceException {
      onProgress?.call('Insufficient balance');
      rethrow;
    } on TransactionFailedException catch (e) {
      onProgress?.call('Transaction failed: ${e.message}');
      rethrow;
    }
  }

  /// Transfer compressed SOL.
  Future<String> transferSol({
    required Ed25519HDKeyPair wallet,
    required BigInt amount,
    required Ed25519HDPublicKey recipient,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Building transfer...');

    try {
      final signature = await transfer(
        rpc: _rpc,
        payer: wallet,
        owner: wallet,
        lamports: amount,
        toAddress: recipient,
      );

      onProgress?.call('Transfer complete!');

      // Refresh balance
      await getBalance(wallet.publicKey);

      return signature;
    } catch (e) {
      onProgress?.call('Transfer failed');
      rethrow;
    }
  }

  /// Decompress SOL back to regular account.
  Future<String> decompressSol({
    required Ed25519HDKeyPair wallet,
    required BigInt amount,
    Ed25519HDPublicKey? recipient,
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Decompressing...');

    try {
      final signature = await decompress(
        rpc: _rpc,
        payer: wallet,
        lamports: amount,
        recipient: recipient ?? wallet.publicKey,
      );

      onProgress?.call('Decompression complete!');
      await getBalance(wallet.publicKey);

      return signature;
    } catch (e) {
      onProgress?.call('Decompression failed');
      rethrow;
    }
  }

  /// Clean up resources.
  void dispose() {
    _balanceController.close();
    _accountsController.close();
  }
}

// ============================================================
// 2. Repository Pattern for Token Operations
// ============================================================

/// Repository for compressed token operations.
class CompressedTokenRepository {
  CompressedTokenRepository(this._rpc);

  final Rpc _rpc;

  /// Get all token balances for an owner.
  Future<Map<String, BigInt>> getTokenBalances(Ed25519HDPublicKey owner) async {
    final balances = await _rpc.getCompressedTokenBalancesByOwner(owner);

    return Map.fromEntries(
      balances.items.map((b) => MapEntry(b.mint.toBase58(), b.balance)),
    );
  }

  /// Get token accounts for a specific mint.
  Future<List<ParsedTokenAccount>> getTokenAccounts(
    Ed25519HDPublicKey owner,
    Ed25519HDPublicKey mint,
  ) async {
    final result = await _rpc.getCompressedTokenAccountsByOwner(
      owner,
      mint: mint,
    );
    return result.items;
  }

  /// Transfer tokens with automatic account selection.
  Future<String> transferTokens({
    required Ed25519HDKeyPair wallet,
    required Ed25519HDPublicKey mint,
    required Ed25519HDPublicKey recipient,
    required BigInt amount,
  }) async {
    // Get input accounts
    final accounts = await getTokenAccounts(wallet.publicKey, mint);

    // Select minimum accounts needed
    final (selected, _) = selectMinCompressedTokenAccountsForTransfer(
      accounts,
      amount,
      (a) => a.parsed.amount,
    );

    // Get validity proof
    final hashes = selected.map((a) => a.compressedAccount.hash).toList();
    final proof = await _rpc.getValidityProof(hashes: hashes);

    // Build transfer instruction
    final instruction = CompressedTokenProgram.transfer(
      payer: wallet.publicKey,
      inputCompressedTokenAccounts: selected,
      toAddress: recipient,
      amount: amount,
      recentInputStateRootIndices: proof.rootIndices,
      recentValidityProof: proof.compressedProof,
    );

    // Build and send transaction
    final signedTx = await buildAndSignTransaction(
      rpc: _rpc,
      signer: wallet,
      instructions: [instruction],
    );

    return sendAndConfirmTransaction(rpc: _rpc, signedTx: signedTx);
  }
}

// ============================================================
// 3. Error Handling in UI
// ============================================================

/// Wrapper for displaying errors in UI.
class LightProtocolError {
  LightProtocolError({
    required this.title,
    required this.message,
    this.isRecoverable = true,
  });

  factory LightProtocolError.fromException(Object error) {
    if (error is InsufficientBalanceException) {
      return LightProtocolError(
        title: 'Insufficient Balance',
        message:
            'You need ${error.required} lamports but only have ${error.available}.',
        isRecoverable: false,
      );
    }

    if (error is TransactionFailedException) {
      return LightProtocolError(
        title: 'Transaction Failed',
        message: error.message,
      );
    }

    if (error is TransactionTimeoutException) {
      return LightProtocolError(
        title: 'Transaction Timeout',
        message: 'The transaction took too long. Please try again.',
      );
    }

    if (error is LightException) {
      return LightProtocolError(
        title: 'Light Protocol Error',
        message: error.message,
      );
    }

    return LightProtocolError(
      title: 'Unknown Error',
      message: error.toString(),
    );
  }

  final String title;
  final String message;
  final bool isRecoverable;
}

// ============================================================
// 4. Amount Formatting Utilities
// ============================================================

/// Format lamports as SOL string.
String formatSol(BigInt lamports, {int decimals = 4}) {
  final sol = lamports / BigInt.from(lamportsPerSol);
  return '${sol.toStringAsFixed(decimals)} SOL';
}

/// Format token amount with decimals.
String formatTokenAmount(BigInt amount, int tokenDecimals, {int display = 2}) {
  final divisor = BigInt.from(10).pow(tokenDecimals);
  final whole = amount ~/ divisor;
  final fraction = amount % divisor;
  final fractionStr = fraction.toString().padLeft(tokenDecimals, '0');
  return '$whole.${fractionStr.substring(0, display.clamp(0, tokenDecimals))}';
}

/// Parse SOL input to lamports.
BigInt? parseSolInput(String input) {
  try {
    final sol = double.parse(input);
    return BigInt.from(sol * lamportsPerSol);
  } catch (_) {
    return null;
  }
}

// ============================================================
// 5. Example Usage (conceptual)
// ============================================================

void main() async {
  print('Flutter Integration Example\n');

  // Initialize service
  final service = LightProtocolService(
    rpcEndpoint: 'https://devnet.helius-rpc.com?api-key=YOUR_KEY',
  );

  // Subscribe to balance updates
  service.balanceStream.listen((balance) {
    print('Balance updated: ${formatSol(balance)}');
  });

  // Create wallet
  final wallet = await Ed25519HDKeyPair.random();

  // Fetch initial balance
  final balance = await service.getBalance(wallet.publicKey);
  print('Initial balance: ${formatSol(balance)}');

  // Example: Compress with progress tracking
  try {
    final signature = await service.compressSol(
      wallet: wallet,
      amount: BigInt.from(lamportsPerSol ~/ 10), // 0.1 SOL
      onProgress: (status) => print('Status: $status'),
    );
    print('Compressed: $signature');
  } on InsufficientBalanceException catch (e) {
    final error = LightProtocolError.fromException(e);
    print('Error: ${error.title} - ${error.message}');
  }

  // Clean up
  service.dispose();

  print('\n✓ Flutter integration example complete!');
}
