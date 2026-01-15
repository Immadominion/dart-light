import 'dart:typed_data';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../errors/light_errors.dart';
import '../programs/light_system_program.dart';
import '../rpc/compression_api.dart';
import '../signer/signer.dart';

/// Build and sign a transaction with the given instructions.
///
/// This creates a transaction with the provided instructions and signs it
/// with the given keypair.
Future<SignedTx> buildAndSignTransaction({
  required Rpc rpc,
  required Ed25519HDKeyPair signer,
  required List<Instruction> instructions,
  Ed25519HDPublicKey? feePayer,
  Commitment commitment = Commitment.confirmed,
  List<Ed25519HDKeyPair>? additionalSigners,
  int? computeUnitLimit,
  int? computeUnitPrice,
}) async {
  final actualFeePayer = feePayer ?? signer.publicKey;

  // Get recent blockhash
  final blockhashResult = await rpc.rpcClient.getLatestBlockhash(
    commitment: commitment,
  );
  final blockhash = blockhashResult.value.blockhash;

  // Add compute budget instructions if specified
  final finalInstructions = <Instruction>[];
  if (computeUnitLimit != null) {
    finalInstructions.add(
      ComputeBudgetInstruction.setComputeUnitLimit(units: computeUnitLimit),
    );
  }
  if (computeUnitPrice != null) {
    finalInstructions.add(
      ComputeBudgetInstruction.setComputeUnitPrice(
        microLamports: computeUnitPrice,
      ),
    );
  }
  finalInstructions.addAll(instructions);

  // Create message
  final message = Message(instructions: finalInstructions);

  // Compile to versioned message (using V0 for address lookup table support)
  final compiledMessage = message.compileV0(
    recentBlockhash: blockhash,
    feePayer: actualFeePayer,
  );

  // Sign with all signers
  final allSigners = [signer, ...?additionalSigners];
  final signatures = await Future.wait(
    allSigners.map((s) async {
      final sig = await s.sign(compiledMessage.toByteArray());
      return Signature(sig.bytes, publicKey: s.publicKey);
    }),
  );

  return SignedTx(compiledMessage: compiledMessage, signatures: signatures);
}

/// Build and sign a transaction using the [Signer] interface.
///
/// This version supports external signers (e.g., Privy, hardware wallets)
/// that don't expose private keys directly.
///
/// ## Example with Privy
/// ```dart
/// final signer = PrivyExternalSigner(embeddedWallet);
/// final signedTx = await buildAndSignTransactionWithSigner(
///   rpc: rpc,
///   signer: signer,
///   instructions: [instruction],
/// );
/// ```
Future<SignedTx> buildAndSignTransactionWithSigner({
  required Rpc rpc,
  required Signer signer,
  required List<Instruction> instructions,
  Ed25519HDPublicKey? feePayer,
  Commitment commitment = Commitment.confirmed,
  List<Signer>? additionalSigners,
  int? computeUnitLimit,
  int? computeUnitPrice,
}) async {
  final actualFeePayer = feePayer ?? signer.publicKey;

  // Get recent blockhash
  final blockhashResult = await rpc.rpcClient.getLatestBlockhash(
    commitment: commitment,
  );
  final blockhash = blockhashResult.value.blockhash;

  // Add compute budget instructions if specified
  final finalInstructions = <Instruction>[];
  if (computeUnitLimit != null) {
    finalInstructions.add(
      ComputeBudgetInstruction.setComputeUnitLimit(units: computeUnitLimit),
    );
  }
  if (computeUnitPrice != null) {
    finalInstructions.add(
      ComputeBudgetInstruction.setComputeUnitPrice(
        microLamports: computeUnitPrice,
      ),
    );
  }
  finalInstructions.addAll(instructions);

  // Create message
  final message = Message(instructions: finalInstructions);

  // Compile to versioned message (using V0 for address lookup table support)
  final compiledMessage = message.compileV0(
    recentBlockhash: blockhash,
    feePayer: actualFeePayer,
  );

  // Sign with all signers using the Signer interface
  final allSigners = [signer, ...?additionalSigners];
  final messageBytes = compiledMessage.toByteArray();
  // Convert ByteArray to Uint8List for signing
  final messageBytesUint8 = Uint8List.fromList(messageBytes.toList());

  final signatures = await Future.wait(
    allSigners.map((s) async {
      final signatureBytes = await s.sign(messageBytesUint8);
      return Signature(signatureBytes.toList(), publicKey: s.publicKey);
    }),
  );

  return SignedTx(compiledMessage: compiledMessage, signatures: signatures);
}

/// Send and confirm a signed transaction.
Future<String> sendAndConfirmTransaction({
  required Rpc rpc,
  required SignedTx signedTx,
  Commitment commitment = Commitment.confirmed,
  Duration? timeout,
}) async {
  // Send transaction
  final signature = await rpc.rpcClient.sendTransaction(
    signedTx.encode(),
    preflightCommitment: commitment,
  );

  // Confirm transaction
  await _confirmTransaction(
    rpc: rpc,
    signature: signature,
    commitment: commitment,
    timeout: timeout ?? const Duration(seconds: 30),
  );

  return signature;
}

/// Confirm a transaction by polling for status.
Future<void> _confirmTransaction({
  required Rpc rpc,
  required String signature,
  required Commitment commitment,
  required Duration timeout,
}) async {
  final startTime = DateTime.now();

  while (DateTime.now().difference(startTime) < timeout) {
    final status = await rpc.rpcClient.getSignatureStatuses([signature]);

    if (status.value.isNotEmpty && status.value.first != null) {
      final signatureStatus = status.value.first!;

      // Check for error
      if (signatureStatus.err != null) {
        throw TransactionFailedException(
          message: signatureStatus.err.toString(),
          signature: signature,
        );
      }

      // Check confirmation level based on requested commitment
      final confirmed = switch (commitment) {
        Commitment.processed => true, // Any confirmation is sufficient
        Commitment.confirmed =>
          signatureStatus.confirmationStatus == Commitment.confirmed ||
              signatureStatus.confirmationStatus == Commitment.finalized,
        Commitment.finalized =>
          signatureStatus.confirmationStatus == Commitment.finalized,
      };

      if (confirmed) return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw TransactionTimeoutException(signature: signature, timeout: timeout);
}

/// Build a compress SOL transaction.
Future<SignedTx> buildCompressTransaction({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  Ed25519HDPublicKey? toAddress,
}) async {
  // Get state tree info
  final treeInfos = await rpc.getStateTreeInfos();
  if (treeInfos.isEmpty) {
    throw StateError('No state trees available');
  }

  final instruction = LightSystemProgram.compress(
    payer: payer.publicKey,
    toAddress: toAddress ?? payer.publicKey,
    lamports: lamports,
    outputStateTreeInfo: treeInfos.first,
  );

  return buildAndSignTransaction(
    rpc: rpc,
    signer: payer,
    instructions: [instruction],
  );
}

/// Build a decompress SOL transaction.
Future<SignedTx> buildDecompressTransaction({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  Ed25519HDPublicKey? toAddress,
}) async {
  // Get compressed accounts owned by payer
  final accounts = await rpc.getCompressedAccountsByOwner(payer.publicKey);

  if (accounts.items.isEmpty) {
    throw StateError('No compressed accounts found');
  }

  // Select accounts for transfer
  final (selectedAccounts, _) = selectMinAccountsForTransfer(
    accounts.items,
    lamports,
  );

  // Get validity proof
  final hashes = selectedAccounts.map((a) => a.hash).toList();
  final proof = await rpc.getValidityProof(hashes: hashes);

  final instruction = LightSystemProgram.decompress(
    payer: payer.publicKey,
    inputCompressedAccounts: selectedAccounts,
    toAddress: toAddress ?? payer.publicKey,
    lamports: lamports,
    recentInputStateRootIndices: proof.rootIndices,
    recentValidityProof: proof.compressedProof,
  );

  return buildAndSignTransaction(
    rpc: rpc,
    signer: payer,
    instructions: [instruction],
  );
}

/// Select minimum accounts for a transfer.
(List<T>, BigInt) selectMinAccountsForTransfer<T>(
  List<T> accounts,
  BigInt amount, {
  BigInt Function(T)? getLamports,
}) {
  final getAmount = getLamports ?? (T a) => (a as dynamic).lamports as BigInt;

  var accumulated = BigInt.zero;
  final selected = <T>[];

  // Sort by amount descending
  final sorted = List<T>.from(accounts)
    ..sort((a, b) => getAmount(b).compareTo(getAmount(a)));

  for (final account in sorted) {
    if (accumulated >= amount) break;
    accumulated += getAmount(account);
    selected.add(account);
  }

  if (accumulated < amount) {
    throw StateError('Insufficient balance: have $accumulated, need $amount');
  }

  return (selected, accumulated);
}
