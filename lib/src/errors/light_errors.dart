import 'package:solana/solana.dart'
    show JsonRpcErrorCode, JsonRpcException, TransactionError;

// ============================================================================
// Error Codes (matching TypeScript SDK)
// ============================================================================

/// Utxo-related error codes.
abstract class UtxoErrorCode {
  static const negativeLamports = 'NEGATIVE_LAMPORTS';
  static const notU64 = 'NOT_U64';
  static const blindingExceedsFieldSize = 'BLINDING_EXCEEDS_FIELD_SIZE';
}

/// Account selection error codes.
abstract class SelectAccountsErrorCode {
  static const failedToFindAccountCombination =
      'FAILED_TO_FIND_ACCOUNT_COMBINATION';
  static const invalidNumberOfInputAccounts =
      'INVALID_NUMBER_OF_INPUT_ACCOUNTS';
}

/// Account creation error codes.
abstract class CreateAccountErrorCode {
  static const ownerUndefined = 'OWNER_UNDEFINED';
  static const invalidOutputAccountLength = 'INVALID_OUTPUT_ACCOUNT_LENGTH';
  static const accountDataUndefined = 'ACCOUNT_DATA_UNDEFINED';
}

/// RPC error codes specific to Light Protocol.
abstract class LightRpcErrorCode {
  static const connectionUndefined = 'CONNECTION_UNDEFINED';
  static const rpcPubkeyUndefined = 'RPC_PUBKEY_UNDEFINED';
  static const rpcMethodNotImplemented = 'RPC_METHOD_NOT_IMPLEMENTED';
  static const rpcInvalid = 'RPC_INVALID';
  static const indexerError = 'INDEXER_ERROR';
  static const compressionApiError = 'COMPRESSION_API_ERROR';
}

/// Lookup table error codes.
abstract class LookupTableErrorCode {
  static const lookupTableUndefined = 'LOOK_UP_TABLE_UNDEFINED';
  static const lookupTableNotInitialized = 'LOOK_UP_TABLE_NOT_INITIALIZED';
}

/// Hash error codes.
abstract class HashErrorCode {
  static const noPoseidonHasherProvided = 'NO_POSEIDON_HASHER_PROVIDED';
  static const hashExceedsFieldSize = 'HASH_EXCEEDS_FIELD_SIZE';
  static const invalidHashLength = 'INVALID_HASH_LENGTH';
}

/// Proof error codes.
abstract class ProofErrorCode {
  static const invalidProof = 'INVALID_PROOF';
  static const proofInputUndefined = 'PROOF_INPUT_UNDEFINED';
  static const proofGenerationFailed = 'PROOF_GENERATION_FAILED';
  static const proverUnavailable = 'PROVER_UNAVAILABLE';
}

/// Merkle tree error codes.
abstract class MerkleTreeErrorCode {
  static const merkleTreeNotInitialized = 'MERKLE_TREE_NOT_INITIALIZED';
  static const solMerkleTreeUndefined = 'SOL_MERKLE_TREE_UNDEFINED';
  static const merkleTreeUndefined = 'MERKLE_TREE_UNDEFINED';
  static const inputAccountNotInsertedInMerkleTree =
      'INPUT_ACCOUNT_NOT_INSERTED_IN_MERKLE_TREE';
  static const merkleTreeIndexUndefined = 'MERKLE_TREE_INDEX_UNDEFINED';
  static const merkleTreeSetSpaceUndefined = 'MERKLE_TREE_SET_SPACE_UNDEFINED';
}

/// Transaction error codes.
abstract class TransactionErrorCode {
  static const transactionFailed = 'TRANSACTION_FAILED';
  static const transactionTimeout = 'TRANSACTION_TIMEOUT';
  static const transactionSimulationFailed = 'TRANSACTION_SIMULATION_FAILED';
  static const invalidBlockhash = 'INVALID_BLOCKHASH';
  static const signatureVerificationFailed = 'SIGNATURE_VERIFICATION_FAILED';
}

// ============================================================================
// Base Exception
// ============================================================================

/// Base exception for Light Protocol errors.
abstract class LightException implements Exception {
  const LightException(this.message, {this.code, this.functionName});

  final String message;
  final String? code;
  final String? functionName;

  @override
  String toString() {
    final parts = <String>[];
    if (code != null) parts.add('[$code]');
    parts.add('$runtimeType: $message');
    if (functionName != null) parts.add('in $functionName');
    return parts.join(' ');
  }
}

// ============================================================================
// Balance Errors
// ============================================================================

/// Exception thrown when there is insufficient balance.
class InsufficientBalanceError extends LightException {
  InsufficientBalanceError({required this.required, required this.available})
    : super('Insufficient balance: required $required, available $available');

  final BigInt required;
  final BigInt available;
}

/// Exception thrown when a compressed account is not found.
class CompressedAccountNotFoundError extends LightException {
  const CompressedAccountNotFoundError({String? hash, String? address})
    : super(
        hash != null
            ? 'Compressed account not found: hash $hash'
            : 'Compressed account not found: address $address',
      );
}

/// Exception thrown when validity proof generation fails.
class ValidityProofError extends LightException {
  const ValidityProofError(super.message);
}

/// Exception thrown when a transaction fails.
class TransactionException extends LightException {
  const TransactionException({
    required String message,
    this.signature,
    this.logs,
  }) : super(message);

  final String? signature;
  final List<String>? logs;

  @override
  String toString() {
    var result = 'TransactionException: $message';
    if (signature != null) result += '\nSignature: $signature';
    if (logs != null && logs!.isNotEmpty) {
      result += '\nLogs:\n${logs!.join('\n')}';
    }
    return result;
  }
}

/// Exception thrown when RPC communication fails.
class RpcError extends LightException {
  const RpcError({required String message, this.rpcCode, this.data})
    : super(message);

  final int? rpcCode;
  final dynamic data;
}

/// Exception thrown when address derivation fails.
class AddressDerivationError extends LightException {
  const AddressDerivationError(super.message);
}

/// Exception thrown when a merkle proof is invalid.
class MerkleProofError extends LightException {
  const MerkleProofError(super.message);
}

/// Exception thrown when serialization/deserialization fails.
class SerializationError extends LightException {
  const SerializationError(super.message);
}

/// Exception thrown when instruction encoding fails.
class InstructionEncodingError extends LightException {
  const InstructionEncodingError(super.message);
}

/// Exception thrown when validation fails.
class ValidationError extends LightException {
  const ValidationError(super.message);
}

/// Exception thrown when the indexer returns an error.
class IndexerError extends LightException {
  const IndexerError({required String message, this.httpStatus})
    : super(message);

  final int? httpStatus;
}

/// Exception thrown when the prover returns an error.
class ProverError extends LightException {
  const ProverError(super.message);
}

/// Exception thrown when a state tree is not available.
class StateTreeError extends LightException {
  const StateTreeError(super.message);
}

/// Exception thrown when token operations fail.
class TokenError extends LightException {
  const TokenError(super.message);
}

/// Exception thrown when a token pool is not found.
class TokenPoolNotFoundError extends LightException {
  const TokenPoolNotFoundError({required String mint})
    : super('Token pool not found for mint: $mint');
}

/// Exception thrown when account owners don't match.
class OwnerMismatchError extends LightException {
  const OwnerMismatchError()
    : super('All input accounts must have the same owner');
}

/// Exception thrown for timeout errors.
class TimeoutError extends LightException {
  const TimeoutError(super.message);
}

// ============================================================================
// Transaction-Specific Errors
// ============================================================================

/// Exception thrown when a transaction fails to confirm.
class TransactionFailedException extends LightException {
  TransactionFailedException({
    required String message,
    this.signature,
    this.logs,
    this.solanaError,
  }) : super(message, code: TransactionErrorCode.transactionFailed);

  final String? signature;
  final List<String>? logs;
  final TransactionError? solanaError;

  @override
  String toString() {
    final buffer = StringBuffer('TransactionFailedException: $message');
    if (signature != null) buffer.writeln('\nSignature: $signature');
    if (solanaError != null) buffer.writeln('Solana Error: $solanaError');
    if (logs != null && logs!.isNotEmpty) {
      buffer.writeln('Logs:');
      for (final log in logs!) {
        buffer.writeln('  $log');
      }
    }
    return buffer.toString();
  }

  /// Extract program error message from logs if available.
  String? get programError {
    if (logs == null) return null;
    for (final log in logs!) {
      if (log.contains('Error:') || log.contains('error:')) {
        return log;
      }
      // Light Protocol specific error patterns
      if (log.contains('Program log:') && log.contains('failed')) {
        return log;
      }
    }
    return null;
  }
}

/// Exception thrown when transaction confirmation times out.
class TransactionTimeoutException extends LightException {
  TransactionTimeoutException({
    required this.signature,
    required Duration timeout,
  }) : super(
         'Transaction $signature did not confirm within ${timeout.inSeconds} seconds',
         code: TransactionErrorCode.transactionTimeout,
       );

  final String signature;
}

/// Exception thrown when transaction simulation fails.
class TransactionSimulationException extends LightException {
  TransactionSimulationException({
    required String message,
    this.logs,
    this.unitsConsumed,
  }) : super(message, code: TransactionErrorCode.transactionSimulationFailed);

  final List<String>? logs;
  final int? unitsConsumed;
}

// ============================================================================
// Proof Errors
// ============================================================================

/// Exception thrown when proof generation fails.
class ProofGenerationError extends LightException {
  ProofGenerationError({
    required String message,
    this.inputHashes,
    this.newAddresses,
  }) : super(message, code: ProofErrorCode.proofGenerationFailed);

  final List<String>? inputHashes;
  final List<String>? newAddresses;
}

/// Exception thrown when the prover service is unavailable.
class ProverUnavailableError extends LightException {
  ProverUnavailableError({required String endpoint, this.statusCode})
    : super(
        'Prover service unavailable at $endpoint'
        '${statusCode != null ? ' (HTTP $statusCode)' : ''}',
        code: ProofErrorCode.proverUnavailable,
      );

  final int? statusCode;
}

// ============================================================================
// Merkle Tree Errors
// ============================================================================

/// Exception thrown when a Merkle tree is not found or unavailable.
class MerkleTreeNotFoundError extends LightException {
  MerkleTreeNotFoundError({required String tree})
    : super(
        'Merkle tree not found: $tree',
        code: MerkleTreeErrorCode.merkleTreeUndefined,
      );
}

/// Exception thrown when account is not in the Merkle tree.
class AccountNotInMerkleTreeError extends LightException {
  AccountNotInMerkleTreeError({required String hash, required String tree})
    : super(
        'Account $hash not found in Merkle tree $tree',
        code: MerkleTreeErrorCode.inputAccountNotInsertedInMerkleTree,
      );
}

// ============================================================================
// Compression API Errors
// ============================================================================

/// Exception thrown when the compression API (Photon) returns an error.
class CompressionApiError extends LightException {
  CompressionApiError({
    required String message,
    this.method,
    this.httpStatus,
    this.responseBody,
  }) : super(message, code: LightRpcErrorCode.compressionApiError);

  final String? method;
  final int? httpStatus;
  final String? responseBody;

  @override
  String toString() {
    final buffer = StringBuffer('CompressionApiError: $message');
    if (method != null) buffer.writeln('\nMethod: $method');
    if (httpStatus != null) buffer.writeln('HTTP Status: $httpStatus');
    if (responseBody != null && responseBody!.isNotEmpty) {
      buffer.writeln('Response: $responseBody');
    }
    return buffer.toString();
  }
}

// ============================================================================
// Account Selection Errors
// ============================================================================

/// Exception thrown when no valid account combination is found.
class AccountSelectionError extends LightException {
  AccountSelectionError({
    required String message,
    this.requiredAmount,
    this.availableAmount,
    this.accountCount,
  }) : super(
         message,
         code: SelectAccountsErrorCode.failedToFindAccountCombination,
       );

  final BigInt? requiredAmount;
  final BigInt? availableAmount;
  final int? accountCount;
}

// ============================================================================
// Error Parsing Utilities
// ============================================================================

/// Parses an error from a JSON-RPC exception into a typed Light error.
LightException parseLightError(JsonRpcException e) {
  // Check for transaction-specific errors
  final txError = e.transactionError;
  if (txError != null) {
    return TransactionFailedException(
      message: _getTransactionErrorMessage(txError),
      solanaError: txError,
    );
  }

  // Check for specific RPC error codes
  switch (e.code) {
    case JsonRpcErrorCode.sendTransactionPreflightFailure:
      return TransactionSimulationException(
        message: e.message,
        logs: _extractLogsFromData(e.data),
      );
    case JsonRpcErrorCode.transactionSignatureVerificationFailure:
      return TransactionFailedException(
        message: 'Transaction signature verification failed',
        solanaError: TransactionError.signatureFailure,
      );
    default:
      return RpcError(message: e.message, rpcCode: e.code, data: e.data);
  }
}

/// Extracts logs from RPC error data.
List<String>? _extractLogsFromData(dynamic data) {
  if (data is Map<String, dynamic>) {
    final logs = data['logs'];
    if (logs is List) {
      return logs.cast<String>();
    }
  }
  return null;
}

/// Gets a human-readable message for a transaction error.
String _getTransactionErrorMessage(TransactionError error) {
  switch (error) {
    case TransactionError.accountInUse:
      return 'An account is already being processed in another transaction';
    case TransactionError.accountLoadedTwice:
      return 'An account appears twice in the transaction';
    case TransactionError.accountNotFound:
      return 'Account not found - no prior credit recorded';
    case TransactionError.programAccountNotFound:
      return 'Program account not found';
    case TransactionError.insufficientFundsForFee:
      return 'Insufficient SOL balance to pay transaction fee';
    case TransactionError.invalidAccountForFee:
      return 'This account cannot be used to pay transaction fees';
    case TransactionError.alreadyProcessed:
      return 'Transaction already processed';
    case TransactionError.blockhashNotFound:
      return 'Blockhash not found or expired - please retry with a fresh blockhash';
    case TransactionError.instructionError:
      return 'An error occurred while processing an instruction';
    case TransactionError.callChainTooDeep:
      return 'Program call chain is too deep';
    case TransactionError.missingSignatureForFee:
      return 'Transaction requires a fee but has no signature';
    case TransactionError.invalidAccountIndex:
      return 'Transaction contains an invalid account reference';
    case TransactionError.signatureFailure:
      return 'Transaction signature verification failed';
    case TransactionError.invalidProgramForExecution:
      return 'This program cannot be used for executing instructions';
    case TransactionError.sanitizeFailure:
      return 'Transaction failed to sanitize accounts';
    case TransactionError.clusterMaintenance:
      return 'Cluster is undergoing maintenance';
    case TransactionError.accountBorrowOutstanding:
      return 'Account has outstanding borrowed reference';
    case TransactionError.other:
      return 'Unknown transaction error';
  }
}

/// Parses a Light Protocol program error from transaction logs.
LightException? parseProgramError(List<String> logs) {
  for (final log in logs) {
    // Light System Program errors
    if (log.contains('InsufficientBalance')) {
      return InsufficientBalanceError(
        required: BigInt.zero,
        available: BigInt.zero,
      );
    }
    if (log.contains('InvalidMerkleProof')) {
      return const MerkleProofError('Invalid Merkle proof provided');
    }
    if (log.contains('InvalidOwner')) {
      return const OwnerMismatchError();
    }
    if (log.contains('AccountNotFound')) {
      return const CompressedAccountNotFoundError();
    }
    if (log.contains('InvalidProof')) {
      return ProofGenerationError(message: 'Invalid validity proof');
    }

    // Compressed Token Program errors
    if (log.contains('TokenPoolNotFound')) {
      return const TokenPoolNotFoundError(mint: 'unknown');
    }
    if (log.contains('InvalidTokenOwner')) {
      return const TokenError('Invalid token owner');
    }
    if (log.contains('InvalidDelegateAuthority')) {
      return const TokenError('Invalid delegate authority');
    }
    if (log.contains('InsufficientTokenBalance')) {
      return const TokenError('Insufficient token balance');
    }
  }

  return null;
}

/// Formats an error for user display with helpful context.
String formatErrorForUser(LightException error) {
  switch (error) {
    case InsufficientBalanceError(:final required, :final available):
      final requiredSol = required / BigInt.from(1e9);
      final availableSol = available / BigInt.from(1e9);
      return 'Insufficient balance: you need $requiredSol SOL but only have $availableSol SOL';

    case TransactionFailedException(:final message, :final programError):
      if (programError != null) {
        return 'Transaction failed: $programError';
      }
      return 'Transaction failed: $message';

    case TransactionTimeoutException(:final signature):
      return 'Transaction did not confirm in time. Signature: ${signature.substring(0, 16)}...';

    case CompressionApiError(:final message, :final method):
      return 'Compression API error${method != null ? ' ($method)' : ''}: $message';

    case TokenPoolNotFoundError(:final message):
      return 'Token not supported for compression: $message';

    case ValidityProofError(:final message):
      return 'Proof generation failed: $message';

    default:
      return error.message;
  }
}
