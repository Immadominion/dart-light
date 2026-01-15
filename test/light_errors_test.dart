import 'package:solana/solana.dart'
    show JsonRpcErrorCode, JsonRpcException, TransactionError;
import 'package:test/test.dart';

import 'package:light_sdk/src/errors/light_errors.dart';

void main() {
  group('Error Codes', () {
    test('UtxoErrorCode constants are defined', () {
      expect(UtxoErrorCode.negativeLamports, 'NEGATIVE_LAMPORTS');
      expect(UtxoErrorCode.notU64, 'NOT_U64');
      expect(
        UtxoErrorCode.blindingExceedsFieldSize,
        'BLINDING_EXCEEDS_FIELD_SIZE',
      );
    });

    test('SelectAccountsErrorCode constants are defined', () {
      expect(
        SelectAccountsErrorCode.failedToFindAccountCombination,
        'FAILED_TO_FIND_ACCOUNT_COMBINATION',
      );
      expect(
        SelectAccountsErrorCode.invalidNumberOfInputAccounts,
        'INVALID_NUMBER_OF_INPUT_ACCOUNTS',
      );
    });

    test('LightRpcErrorCode constants are defined', () {
      expect(LightRpcErrorCode.connectionUndefined, 'CONNECTION_UNDEFINED');
      expect(LightRpcErrorCode.compressionApiError, 'COMPRESSION_API_ERROR');
    });

    test('ProofErrorCode constants are defined', () {
      expect(ProofErrorCode.invalidProof, 'INVALID_PROOF');
      expect(ProofErrorCode.proofGenerationFailed, 'PROOF_GENERATION_FAILED');
      expect(ProofErrorCode.proverUnavailable, 'PROVER_UNAVAILABLE');
    });

    test('TransactionErrorCode constants are defined', () {
      expect(TransactionErrorCode.transactionFailed, 'TRANSACTION_FAILED');
      expect(TransactionErrorCode.transactionTimeout, 'TRANSACTION_TIMEOUT');
      expect(
        TransactionErrorCode.transactionSimulationFailed,
        'TRANSACTION_SIMULATION_FAILED',
      );
    });

    test('MerkleTreeErrorCode constants are defined', () {
      expect(
        MerkleTreeErrorCode.merkleTreeNotInitialized,
        'MERKLE_TREE_NOT_INITIALIZED',
      );
      expect(
        MerkleTreeErrorCode.inputAccountNotInsertedInMerkleTree,
        'INPUT_ACCOUNT_NOT_INSERTED_IN_MERKLE_TREE',
      );
    });
  });

  group('LightException', () {
    test('InsufficientBalanceError has correct message', () {
      final error = InsufficientBalanceError(
        required: BigInt.from(1000000000),
        available: BigInt.from(500000000),
      );

      expect(error.required, BigInt.from(1000000000));
      expect(error.available, BigInt.from(500000000));
      expect(error.message, contains('1000000000'));
      expect(error.message, contains('500000000'));
      expect(error.toString(), contains('InsufficientBalanceError'));
    });

    test('CompressedAccountNotFoundError with hash', () {
      const error = CompressedAccountNotFoundError(hash: 'abc123');
      expect(error.message, contains('hash abc123'));
    });

    test('CompressedAccountNotFoundError with address', () {
      const error = CompressedAccountNotFoundError(address: 'xyz789');
      expect(error.message, contains('address xyz789'));
    });

    test('ValidityProofError stores message', () {
      const error = ValidityProofError('Proof verification failed');
      expect(error.message, 'Proof verification failed');
    });

    test('RpcError includes rpcCode and data', () {
      const error = RpcError(
        message: 'Connection failed',
        rpcCode: -32000,
        data: {'detail': 'timeout'},
      );

      expect(error.message, 'Connection failed');
      expect(error.rpcCode, -32000);
      expect(error.data, {'detail': 'timeout'});
    });

    test('TokenPoolNotFoundError includes mint', () {
      const error = TokenPoolNotFoundError(mint: 'TokenMint123');
      expect(error.message, contains('TokenMint123'));
    });

    test('OwnerMismatchError has predefined message', () {
      const error = OwnerMismatchError();
      expect(error.message, contains('same owner'));
    });
  });

  group('TransactionFailedException', () {
    test('stores signature and logs', () {
      final error = TransactionFailedException(
        message: 'Transaction failed',
        signature: 'sig123',
        logs: ['Program log: Error', 'Program log: Details'],
      );

      expect(error.message, 'Transaction failed');
      expect(error.signature, 'sig123');
      expect(error.logs, hasLength(2));
      expect(error.code, TransactionErrorCode.transactionFailed);
    });

    test('toString includes all details', () {
      final error = TransactionFailedException(
        message: 'Custom error',
        signature: 'abc123',
        logs: ['Log 1', 'Log 2'],
        solanaError: TransactionError.instructionError,
      );

      final output = error.toString();
      expect(output, contains('Custom error'));
      expect(output, contains('abc123'));
      expect(output, contains('Log 1'));
      expect(output, contains('Log 2'));
      expect(output, contains('instructionError'));
    });

    test('programError extracts error from logs', () {
      final error = TransactionFailedException(
        message: 'Failed',
        logs: [
          'Program invoked',
          'Error: Custom program error 0x1',
          'Program failed',
        ],
      );

      expect(error.programError, contains('Error:'));
    });

    test('programError returns null when no error in logs', () {
      final error = TransactionFailedException(
        message: 'Failed',
        logs: ['Program invoked', 'Program completed'],
      );

      expect(error.programError, isNull);
    });

    test('programError returns null when logs is null', () {
      final error = TransactionFailedException(message: 'Failed');
      expect(error.programError, isNull);
    });
  });

  group('TransactionTimeoutException', () {
    test('includes signature and timeout duration', () {
      final error = TransactionTimeoutException(
        signature: 'sig456',
        timeout: const Duration(seconds: 30),
      );

      expect(error.signature, 'sig456');
      expect(error.message, contains('sig456'));
      expect(error.message, contains('30 seconds'));
      expect(error.code, TransactionErrorCode.transactionTimeout);
    });
  });

  group('TransactionSimulationException', () {
    test('stores logs and units consumed', () {
      final error = TransactionSimulationException(
        message: 'Simulation failed',
        logs: ['Program log: Error'],
        unitsConsumed: 50000,
      );

      expect(error.message, 'Simulation failed');
      expect(error.logs, hasLength(1));
      expect(error.unitsConsumed, 50000);
      expect(error.code, TransactionErrorCode.transactionSimulationFailed);
    });
  });

  group('ProofGenerationError', () {
    test('includes input context', () {
      final error = ProofGenerationError(
        message: 'Proof failed',
        inputHashes: ['hash1', 'hash2'],
        newAddresses: ['addr1'],
      );

      expect(error.message, 'Proof failed');
      expect(error.inputHashes, hasLength(2));
      expect(error.newAddresses, hasLength(1));
      expect(error.code, ProofErrorCode.proofGenerationFailed);
    });
  });

  group('ProverUnavailableError', () {
    test('includes endpoint and status code', () {
      final error = ProverUnavailableError(
        endpoint: 'https://prover.example.com',
        statusCode: 503,
      );

      expect(error.message, contains('prover.example.com'));
      expect(error.message, contains('503'));
      expect(error.code, ProofErrorCode.proverUnavailable);
    });

    test('works without status code', () {
      final error = ProverUnavailableError(
        endpoint: 'https://prover.example.com',
      );

      expect(error.message, contains('prover.example.com'));
      expect(error.statusCode, isNull);
    });
  });

  group('CompressionApiError', () {
    test('includes method and HTTP status', () {
      final error = CompressionApiError(
        message: 'API error',
        method: 'getCompressedAccountsByOwner',
        httpStatus: 500,
        responseBody: '{"error": "internal"}',
      );

      expect(error.message, 'API error');
      expect(error.method, 'getCompressedAccountsByOwner');
      expect(error.httpStatus, 500);
      expect(error.code, LightRpcErrorCode.compressionApiError);
    });

    test('toString includes all details', () {
      final error = CompressionApiError(
        message: 'Failed',
        method: 'getValidityProof',
        httpStatus: 400,
        responseBody: '{"error": "bad request"}',
      );

      final output = error.toString();
      expect(output, contains('Failed'));
      expect(output, contains('getValidityProof'));
      expect(output, contains('400'));
      expect(output, contains('bad request'));
    });
  });

  group('MerkleTreeNotFoundError', () {
    test('includes tree address', () {
      final error = MerkleTreeNotFoundError(tree: 'Tree123');
      expect(error.message, contains('Tree123'));
      expect(error.code, MerkleTreeErrorCode.merkleTreeUndefined);
    });
  });

  group('AccountNotInMerkleTreeError', () {
    test('includes hash and tree', () {
      final error = AccountNotInMerkleTreeError(
        hash: 'hash123',
        tree: 'tree456',
      );
      expect(error.message, contains('hash123'));
      expect(error.message, contains('tree456'));
      expect(
        error.code,
        MerkleTreeErrorCode.inputAccountNotInsertedInMerkleTree,
      );
    });
  });

  group('AccountSelectionError', () {
    test('includes amounts and count', () {
      final error = AccountSelectionError(
        message: 'Cannot find combination',
        requiredAmount: BigInt.from(1000000000),
        availableAmount: BigInt.from(500000000),
        accountCount: 3,
      );

      expect(error.requiredAmount, BigInt.from(1000000000));
      expect(error.availableAmount, BigInt.from(500000000));
      expect(error.accountCount, 3);
      expect(
        error.code,
        SelectAccountsErrorCode.failedToFindAccountCombination,
      );
    });
  });

  group('parseLightError', () {
    test('parses preflight failure into TransactionSimulationException', () {
      final rpcError = JsonRpcException(
        'Simulation failed',
        JsonRpcErrorCode.sendTransactionPreflightFailure,
        {
          'logs': ['Program log: Error'],
        },
      );

      final result = parseLightError(rpcError);
      expect(result, isA<TransactionSimulationException>());
      expect((result as TransactionSimulationException).logs, isNotNull);
    });

    test('parses signature verification failure', () {
      final rpcError = JsonRpcException(
        'Signature verification failed',
        JsonRpcErrorCode.transactionSignatureVerificationFailure,
        null,
      );

      final result = parseLightError(rpcError);
      expect(result, isA<TransactionFailedException>());
      expect(
        (result as TransactionFailedException).solanaError,
        TransactionError.signatureFailure,
      );
    });

    test('returns RpcError for unknown error codes', () {
      final rpcError = JsonRpcException('Unknown error', -32099, null);

      final result = parseLightError(rpcError);
      expect(result, isA<RpcError>());
      expect((result as RpcError).rpcCode, -32099);
    });
  });

  group('parseProgramError', () {
    test('parses InsufficientBalance', () {
      final logs = ['Program log: InsufficientBalance'];
      final result = parseProgramError(logs);
      expect(result, isA<InsufficientBalanceError>());
    });

    test('parses InvalidMerkleProof', () {
      final logs = ['Program log: InvalidMerkleProof'];
      final result = parseProgramError(logs);
      expect(result, isA<MerkleProofError>());
    });

    test('parses InvalidOwner', () {
      final logs = ['Program log: InvalidOwner'];
      final result = parseProgramError(logs);
      expect(result, isA<OwnerMismatchError>());
    });

    test('parses AccountNotFound', () {
      final logs = ['Program log: AccountNotFound'];
      final result = parseProgramError(logs);
      expect(result, isA<CompressedAccountNotFoundError>());
    });

    test('parses TokenPoolNotFound', () {
      final logs = ['Program log: TokenPoolNotFound'];
      final result = parseProgramError(logs);
      expect(result, isA<TokenPoolNotFoundError>());
    });

    test('parses InvalidProof', () {
      final logs = ['Program log: InvalidProof'];
      final result = parseProgramError(logs);
      expect(result, isA<ProofGenerationError>());
    });

    test('returns null for unknown errors', () {
      final logs = ['Program log: SomeUnknownError'];
      final result = parseProgramError(logs);
      expect(result, isNull);
    });
  });

  group('formatErrorForUser', () {
    test('formats InsufficientBalanceError with SOL amounts', () {
      final error = InsufficientBalanceError(
        required: BigInt.from(2000000000), // 2 SOL
        available: BigInt.from(1000000000), // 1 SOL
      );

      final message = formatErrorForUser(error);
      expect(message, contains('SOL'));
    });

    test('formats TransactionFailedException with program error', () {
      final error = TransactionFailedException(
        message: 'Base error',
        logs: ['Error: Custom program error 0x1'],
      );

      final message = formatErrorForUser(error);
      expect(message, contains('Custom program error'));
    });

    test('formats TransactionTimeoutException with truncated signature', () {
      final error = TransactionTimeoutException(
        signature: 'abcdefghijklmnopqrstuvwxyz123456789',
        timeout: const Duration(seconds: 30),
      );

      final message = formatErrorForUser(error);
      expect(message, contains('abcdefghijklmnop'));
      expect(message, contains('...'));
    });

    test('formats CompressionApiError with method', () {
      final error = CompressionApiError(
        message: 'Rate limited',
        method: 'getValidityProof',
      );

      final message = formatErrorForUser(error);
      expect(message, contains('getValidityProof'));
      expect(message, contains('Rate limited'));
    });

    test('formats TokenPoolNotFoundError', () {
      const error = TokenPoolNotFoundError(mint: 'USDC');
      final message = formatErrorForUser(error);
      expect(message, contains('Token not supported'));
    });

    test('formats generic LightException', () {
      const error = ValidationError('Invalid input');
      final message = formatErrorForUser(error);
      expect(message, 'Invalid input');
    });
  });
}
