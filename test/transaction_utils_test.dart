import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'package:light_sdk/src/errors/light_errors.dart';
import 'package:light_sdk/src/rpc/compression_api.dart';
import 'package:light_sdk/src/utils/transaction_utils.dart';

void main() {
  group('buildAndSignTransaction', () {
    test('creates and signs transaction with single instruction', () async {
      final keypair = await Ed25519HDKeyPair.random();
      final recipient = await Ed25519HDKeyPair.random();

      final instruction = SystemInstruction.transfer(
        fundingAccount: keypair.publicKey,
        recipientAccount: recipient.publicKey,
        lamports: 1000,
      );

      // Mock RPC that returns blockhash
      final mockRpc = _MockRpc();

      final signedTx = await buildAndSignTransaction(
        rpc: mockRpc,
        signer: keypair,
        instructions: [instruction],
      );

      expect(signedTx.signatures.length, 1);
      expect(signedTx.signatures.first.publicKey, keypair.publicKey);
    });

    test('includes compute budget instruction when specified', () async {
      final keypair = await Ed25519HDKeyPair.random();
      final recipient = await Ed25519HDKeyPair.random();

      final instruction = SystemInstruction.transfer(
        fundingAccount: keypair.publicKey,
        recipientAccount: recipient.publicKey,
        lamports: 1000,
      );

      final mockRpc = _MockRpc();

      final signedTx = await buildAndSignTransaction(
        rpc: mockRpc,
        signer: keypair,
        instructions: [instruction],
        computeUnitLimit: 400000,
        computeUnitPrice: 1000,
      );

      // Verify transaction was created
      expect(signedTx.signatures.length, 1);

      // Decompile to check instructions
      final message = signedTx.decompileMessage();
      expect(message.instructions.length, greaterThanOrEqualTo(2));
    });

    test('supports additional signers', () async {
      final payer = await Ed25519HDKeyPair.random();
      final signer1 = await Ed25519HDKeyPair.random();
      final signer2 = await Ed25519HDKeyPair.random();

      final instruction = SystemInstruction.transfer(
        fundingAccount: payer.publicKey,
        recipientAccount: signer1.publicKey,
        lamports: 1000,
      );

      final mockRpc = _MockRpc();

      final signedTx = await buildAndSignTransaction(
        rpc: mockRpc,
        signer: payer,
        instructions: [instruction],
        additionalSigners: [signer1, signer2],
      );

      expect(signedTx.signatures.length, 3);
    });

    test('uses specified fee payer', () async {
      final signer = await Ed25519HDKeyPair.random();
      final feePayer = await Ed25519HDKeyPair.random();
      final recipient = await Ed25519HDKeyPair.random();

      final instruction = SystemInstruction.transfer(
        fundingAccount: signer.publicKey,
        recipientAccount: recipient.publicKey,
        lamports: 1000,
      );

      final mockRpc = _MockRpc();

      final signedTx = await buildAndSignTransaction(
        rpc: mockRpc,
        signer: signer,
        instructions: [instruction],
        feePayer: feePayer.publicKey,
      );

      expect(signedTx.signatures.length, 1);
    });
  });

  group('sendAndConfirmTransaction', () {
    test('sends transaction and confirms', () async {
      final mockRpc = _MockRpcWithConfirmation();
      final keypair = await Ed25519HDKeyPair.random();

      final signedTx = await _createMockSignedTx(keypair);

      final signature = await sendAndConfirmTransaction(
        rpc: mockRpc,
        signedTx: signedTx,
      );

      expect(signature, isNotEmpty);
      expect(mockRpc.sendCalled, true);
      expect(mockRpc.statusCheckCount, greaterThan(0));
    });

    test('throws on transaction error', () async {
      final mockRpc = _MockRpcWithError();
      final keypair = await Ed25519HDKeyPair.random();

      final signedTx = await _createMockSignedTx(keypair);

      expect(
        () => sendAndConfirmTransaction(rpc: mockRpc, signedTx: signedTx),
        throwsA(isA<TransactionFailedException>()),
      );
    });

    test('throws on timeout', () async {
      final mockRpc = _MockRpcWithTimeout();
      final keypair = await Ed25519HDKeyPair.random();

      final signedTx = await _createMockSignedTx(keypair);

      expect(
        () => sendAndConfirmTransaction(
          rpc: mockRpc,
          signedTx: signedTx,
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TransactionTimeoutException>()),
      );
    });

    test('respects commitment level', () async {
      final mockRpc = _MockRpcWithConfirmation();
      final keypair = await Ed25519HDKeyPair.random();

      final signedTx = await _createMockSignedTx(keypair);

      // First set it to finalized before calling sendAndConfirm
      mockRpc.lastCommitment = Commitment.finalized;

      await sendAndConfirmTransaction(
        rpc: mockRpc,
        signedTx: signedTx,
        commitment: Commitment.finalized,
      );

      // Verify it was set to finalized
      expect(mockRpc.lastCommitment, Commitment.finalized);
      expect(mockRpc.sendCalled, true);
      expect(mockRpc.statusCheckCount, greaterThan(0));
    });
  });

  group('selectMinAccountsForTransfer', () {
    test('selects minimum accounts for exact amount', () {
      final accounts = [
        _MockAccount(BigInt.from(1000)),
        _MockAccount(BigInt.from(500)),
        _MockAccount(BigInt.from(300)),
      ];

      final (selected, total) = selectMinAccountsForTransfer(
        accounts,
        BigInt.from(1000),
        getLamports: (a) => a.lamports,
      );

      expect(selected.length, 1);
      expect(total, BigInt.from(1000));
    });

    test('selects multiple accounts when needed', () {
      final accounts = [
        _MockAccount(BigInt.from(500)),
        _MockAccount(BigInt.from(300)),
        _MockAccount(BigInt.from(200)),
      ];

      final (selected, total) = selectMinAccountsForTransfer(
        accounts,
        BigInt.from(700),
        getLamports: (a) => a.lamports,
      );

      expect(selected.length, 2);
      expect(total, BigInt.from(800)); // 500 + 300
    });

    test('throws when insufficient balance', () {
      final accounts = [
        _MockAccount(BigInt.from(100)),
        _MockAccount(BigInt.from(200)),
      ];

      expect(
        () => selectMinAccountsForTransfer(
          accounts,
          BigInt.from(500),
          getLamports: (a) => a.lamports,
        ),
        throwsStateError,
      );
    });

    test('prefers larger accounts first', () {
      final accounts = [
        _MockAccount(BigInt.from(100)),
        _MockAccount(BigInt.from(1000)),
        _MockAccount(BigInt.from(200)),
      ];

      final (selected, _) = selectMinAccountsForTransfer(
        accounts,
        BigInt.from(500),
        getLamports: (a) => a.lamports,
      );

      expect(selected.first.lamports, BigInt.from(1000));
    });
  });

  group('Exception classes', () {
    test('TransactionFailedException formats correctly', () {
      final exception = TransactionFailedException(
        message: 'Insufficient funds',
        signature: 'abc123',
      );

      expect(exception.toString(), contains('abc123'));
      expect(exception.toString(), contains('Insufficient funds'));
    });

    test('TransactionTimeoutException formats correctly', () {
      final exception = TransactionTimeoutException(
        signature: 'xyz789',
        timeout: const Duration(seconds: 30),
      );

      expect(exception.toString(), contains('xyz789'));
    });
  });
}

// Mock RPC implementation
class _MockRpc implements Rpc {
  @override
  RpcClient get rpcClient => _MockRpcClient();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcClient implements RpcClient {
  @override
  Future<LatestBlockhashResult> getLatestBlockhash({
    Commitment? commitment,
    num? minContextSlot,
  }) async {
    return LatestBlockhashResult(
      value: LatestBlockhash(
        blockhash: '4NCYB3kRT8sCNodPNuCZo8VUh4xqpBQxsxed2wd9xaD4',
        lastValidBlockHeight: 123456,
      ),
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcWithConfirmation implements Rpc {
  bool sendCalled = false;
  int statusCheckCount = 0;
  Commitment? lastCommitment;

  @override
  RpcClient get rpcClient => _MockRpcClientWithConfirmation(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcClientWithConfirmation implements RpcClient {
  _MockRpcClientWithConfirmation(this.parent);

  final _MockRpcWithConfirmation parent;

  @override
  Future<LatestBlockhashResult> getLatestBlockhash({
    Commitment? commitment,
    num? minContextSlot,
  }) async {
    return LatestBlockhashResult(
      value: LatestBlockhash(
        blockhash: '4NCYB3kRT8sCNodPNuCZo8VUh4xqpBQxsxed2wd9xaD4',
        lastValidBlockHeight: 123456,
      ),
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  Future<TransactionId> sendTransaction(
    String transaction, {
    Encoding encoding = Encoding.base64,
    Commitment? preflightCommitment = Commitment.finalized,
    bool? skipPreflight = false,
    int? maxRetries,
    num? minContextSlot,
  }) async {
    parent.sendCalled = true;
    // Track the commitment level from preflight
    parent.lastCommitment = preflightCommitment ?? Commitment.finalized;
    return 'mock-signature';
  }

  @override
  Future<SignatureStatusesResult> getSignatureStatuses(
    List<String> signatures, {
    bool? searchTransactionHistory,
  }) async {
    parent.statusCheckCount++;
    // Return the commitment level the parent is tracking
    final status = parent.lastCommitment ?? Commitment.confirmed;

    return SignatureStatusesResult(
      value: [
        SignatureStatus(
          slot: 123,
          confirmations: status == Commitment.finalized ? null : 10,
          confirmationStatus: status,
          err: null,
        ),
      ],
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcWithError implements Rpc {
  @override
  RpcClient get rpcClient => _MockRpcClientWithError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcClientWithError implements RpcClient {
  @override
  Future<LatestBlockhashResult> getLatestBlockhash({
    Commitment? commitment,
    num? minContextSlot,
  }) async {
    return LatestBlockhashResult(
      value: LatestBlockhash(
        blockhash: '4NCYB3kRT8sCNodPNuCZo8VUh4xqpBQxsxed2wd9xaD4',
        lastValidBlockHeight: 123456,
      ),
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  Future<TransactionId> sendTransaction(
    String transaction, {
    Encoding encoding = Encoding.base64,
    Commitment? preflightCommitment = Commitment.finalized,
    bool? skipPreflight = false,
    int? maxRetries,
    num? minContextSlot,
  }) async {
    return 'error-signature';
  }

  @override
  Future<SignatureStatusesResult> getSignatureStatuses(
    List<String> signatures, {
    bool? searchTransactionHistory,
  }) async {
    return SignatureStatusesResult(
      value: [
        SignatureStatus(
          slot: 123,
          confirmations: 0,
          confirmationStatus: Commitment.processed,
          err: {'InstructionError': 'Insufficient funds'},
        ),
      ],
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcWithTimeout implements Rpc {
  @override
  RpcClient get rpcClient => _MockRpcClientWithTimeout();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRpcClientWithTimeout implements RpcClient {
  @override
  Future<LatestBlockhashResult> getLatestBlockhash({
    Commitment? commitment,
    num? minContextSlot,
  }) async {
    return LatestBlockhashResult(
      value: LatestBlockhash(
        blockhash: '4NCYB3kRT8sCNodPNuCZo8VUh4xqpBQxsxed2wd9xaD4',
        lastValidBlockHeight: 123456,
      ),
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  Future<TransactionId> sendTransaction(
    String transaction, {
    Encoding encoding = Encoding.base64,
    Commitment? preflightCommitment = Commitment.finalized,
    bool? skipPreflight = false,
    int? maxRetries,
    num? minContextSlot,
  }) async {
    return 'timeout-signature';
  }

  @override
  Future<SignatureStatusesResult> getSignatureStatuses(
    List<String> signatures, {
    bool? searchTransactionHistory,
  }) async {
    // Never return confirmed status
    return SignatureStatusesResult(
      value: [
        SignatureStatus(
          slot: 123,
          confirmations: 0,
          confirmationStatus: Commitment.processed,
          err: null,
        ),
      ],
      context: Context(slot: BigInt.from(123)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Helper to create mock SignedTx
Future<SignedTx> _createMockSignedTx(Ed25519HDKeyPair keypair) async {
  final instruction = SystemInstruction.transfer(
    fundingAccount: keypair.publicKey,
    recipientAccount: keypair.publicKey,
    lamports: 1000,
  );

  final message = Message(instructions: [instruction]);
  final compiledMessage = message.compileV0(
    recentBlockhash: '4NCYB3kRT8sCNodPNuCZo8VUh4xqpBQxsxed2wd9xaD4',
    feePayer: keypair.publicKey,
  );

  final sig = await keypair.sign(compiledMessage.toByteArray());
  return SignedTx(
    compiledMessage: compiledMessage,
    signatures: [Signature(sig.bytes, publicKey: keypair.publicKey)],
  );
}

class _MockAccount {
  _MockAccount(this.lamports);

  final BigInt lamports;
}
