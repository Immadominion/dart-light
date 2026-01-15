import 'dart:typed_data';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../constants/program_ids.dart';
import '../state/compressed_account.dart';
import '../state/tree_info.dart';
import '../state/validity_proof.dart';
import 'instruction_data.dart';
import 'pack.dart';

/// Light System Program for compressed account operations.
///
/// Provides instructions for:
/// - Compressing SOL (transfer from regular to compressed account)
/// - Decompressing SOL (transfer from compressed to regular account)
/// - Transferring compressed SOL between addresses
/// - Creating compressed accounts with PDAs
class LightSystemProgram {
  LightSystemProgram._();

  /// The Light System Program ID.
  static final programId = LightProgramIds.lightSystemProgram;

  /// Account Compression Program ID.
  static final accountCompressionProgramId =
      LightProgramIds.accountCompressionProgram;

  /// Noop Program ID (for logging).
  static final noopProgramId = LightProgramIds.noopProgram;

  /// Registered Program PDA.
  static final registeredProgramPda = getRegisteredProgramPda();

  /// SOL Pool PDA (pre-computed).
  /// Derived from seeds: ["sol_pool_pda"] with Light System Program ID.
  /// Dart derivation: CHK57ywWSDncAoRu1F8QgwYJeXuAJyyBYT4LixLXvMZ1
  /// (TypeScript comment shows: Cwct1kQLwJm8Z3HetLu8m4SXkhD6FZ5fXbJQCxTxPnGY but may be outdated)
  static final solPoolPda = Ed25519HDPublicKey.fromBase58(
    'CHK57ywWSDncAoRu1F8QgwYJeXuAJyyBYT4LixLXvMZ1',
  );

  /// Derive the SOL pool PDA address (async).
  static Future<Ed25519HDPublicKey> deriveCompressedSolPda() async {
    final seeds = [Uint8List.fromList('sol_pool_pda'.codeUnits)];
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: seeds,
      programId: programId,
    );
  }

  /// Sum up lamports from a list of compressed accounts.
  static BigInt sumUpLamports(
    List<CompressedAccountWithMerkleContext> accounts,
  ) => accounts.fold(BigInt.zero, (sum, account) => sum + account.lamports);

  /// Create transfer output state.
  static List<CompressedAccountLegacy> createTransferOutputState({
    required List<CompressedAccountWithMerkleContext> inputCompressedAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt lamports,
  }) {
    final inputLamports = sumUpLamports(inputCompressedAccounts);
    final changeLamports = inputLamports - lamports;

    if (changeLamports < BigInt.zero) {
      throw ArgumentError(
        'Insufficient balance: have $inputLamports, need $lamports',
      );
    }

    if (changeLamports == BigInt.zero) {
      return [CompressedAccountLegacy.create(toAddress, lamports)];
    }

    // Validate same owner
    _validateSameOwner(inputCompressedAccounts);

    return [
      CompressedAccountLegacy.create(
        inputCompressedAccounts.first.owner,
        changeLamports,
      ),
      CompressedAccountLegacy.create(toAddress, lamports),
    ];
  }

  /// Create decompress output state.
  static List<CompressedAccountLegacy> createDecompressOutputState({
    required List<CompressedAccountWithMerkleContext> inputCompressedAccounts,
    required BigInt lamports,
  }) {
    final inputLamports = sumUpLamports(inputCompressedAccounts);
    final changeLamports = inputLamports - lamports;

    if (changeLamports < BigInt.zero) {
      throw ArgumentError(
        'Insufficient balance: have $inputLamports, need $lamports',
      );
    }

    // All lamports decompressed, no change output needed
    if (changeLamports == BigInt.zero) {
      return [];
    }

    _validateSameOwner(inputCompressedAccounts);

    return [
      CompressedAccountLegacy.create(
        inputCompressedAccounts.first.owner,
        changeLamports,
      ),
    ];
  }

  /// Create new address output state.
  static List<CompressedAccountLegacy> createNewAddressOutputState({
    required List<int> address,
    required Ed25519HDPublicKey owner,
    BigInt? lamports,
    List<CompressedAccountWithMerkleContext>? inputCompressedAccounts,
  }) {
    final lamportsValue = lamports ?? BigInt.zero;
    final inputLamports = sumUpLamports(inputCompressedAccounts ?? []);
    final changeLamports = inputLamports - lamportsValue;

    if (changeLamports < BigInt.zero) {
      throw ArgumentError(
        'Insufficient balance: have $inputLamports, need $lamportsValue',
      );
    }

    if (changeLamports == BigInt.zero || inputCompressedAccounts == null) {
      return [
        CompressedAccountLegacy(
          owner: owner,
          lamports: lamportsValue,
          address: address,
        ),
      ];
    }

    _validateSameOwner(inputCompressedAccounts);

    return [
      CompressedAccountLegacy.create(
        inputCompressedAccounts.first.owner,
        changeLamports,
      ),
      CompressedAccountLegacy(
        owner: owner,
        lamports: lamportsValue,
        address: address,
      ),
    ];
  }

  static void _validateSameOwner(
    List<CompressedAccountWithMerkleContext> accounts,
  ) {
    if (accounts.isEmpty) return;

    final owner = accounts.first.owner;
    for (final account in accounts.skip(1)) {
      if (account.owner != owner) {
        throw ArgumentError('All input accounts must have the same owner');
      }
    }
  }

  /// Create an instruction to compress SOL.
  static Instruction compress({
    required Ed25519HDPublicKey payer,
    required Ed25519HDPublicKey toAddress,
    required BigInt lamports,
    required TreeInfo outputStateTreeInfo,
  }) {
    final outputCompressedAccount = CompressedAccountLegacy.create(
      toAddress,
      lamports,
    );

    final packed = packCompressedAccounts(
      inputCompressedAccounts: [],
      inputStateRootIndices: [],
      outputCompressedAccounts: [outputCompressedAccount],
      outputStateTreeInfo: outputStateTreeInfo,
    );

    final instructionData = InstructionDataInvoke(
      proof: null,
      inputCompressedAccountsWithMerkleContext:
          packed.packedInputCompressedAccounts,
      outputCompressedAccounts: packed.packedOutputCompressedAccounts,
      relayFee: null,
      newAddressParams: [],
      compressOrDecompressLamports: lamports,
      isCompress: true,
    );

    final data = _encodeInvokeInstruction(instructionData);

    final accounts = _buildInvokeAccounts(
      feePayer: payer,
      authority: payer,
      solPoolPda: solPoolPda,
      decompressionRecipient: null,
    );

    final keys = [...accounts, ...toAccountMetas(packed.remainingAccounts)];

    return Instruction(
      programId: programId,
      accounts: keys,
      data: ByteArray(data),
    );
  }

  /// Create an instruction to decompress SOL.
  static Instruction decompress({
    required Ed25519HDPublicKey payer,
    required List<CompressedAccountWithMerkleContext> inputCompressedAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt lamports,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
  }) {
    final outputCompressedAccounts = createDecompressOutputState(
      inputCompressedAccounts: inputCompressedAccounts,
      lamports: lamports,
    );

    final packed = packCompressedAccounts(
      inputCompressedAccounts: inputCompressedAccounts,
      inputStateRootIndices: recentInputStateRootIndices,
      outputCompressedAccounts: outputCompressedAccounts,
    );

    final instructionData = InstructionDataInvoke(
      proof: recentValidityProof,
      inputCompressedAccountsWithMerkleContext:
          packed.packedInputCompressedAccounts,
      outputCompressedAccounts: packed.packedOutputCompressedAccounts,
      relayFee: null,
      newAddressParams: [],
      compressOrDecompressLamports: lamports,
      isCompress: false,
    );

    final data = _encodeInvokeInstruction(instructionData);

    final accounts = _buildInvokeAccounts(
      feePayer: payer,
      authority: payer,
      solPoolPda: solPoolPda,
      decompressionRecipient: toAddress,
    );

    final keys = [...accounts, ...toAccountMetas(packed.remainingAccounts)];

    return Instruction(
      programId: programId,
      accounts: keys,
      data: ByteArray(data),
    );
  }

  /// Create an instruction to transfer compressed SOL.
  static Instruction transfer({
    required Ed25519HDPublicKey payer,
    required List<CompressedAccountWithMerkleContext> inputCompressedAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt lamports,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
  }) {
    final outputCompressedAccounts = createTransferOutputState(
      inputCompressedAccounts: inputCompressedAccounts,
      toAddress: toAddress,
      lamports: lamports,
    );

    final packed = packCompressedAccounts(
      inputCompressedAccounts: inputCompressedAccounts,
      inputStateRootIndices: recentInputStateRootIndices,
      outputCompressedAccounts: outputCompressedAccounts,
    );

    final instructionData = InstructionDataInvoke(
      proof: recentValidityProof,
      inputCompressedAccountsWithMerkleContext:
          packed.packedInputCompressedAccounts,
      outputCompressedAccounts: packed.packedOutputCompressedAccounts,
      relayFee: null,
      newAddressParams: [],
      compressOrDecompressLamports: null,
      isCompress: false,
    );

    final data = _encodeInvokeInstruction(instructionData);

    final accounts = _buildInvokeAccounts(
      feePayer: payer,
      authority: payer,
      solPoolPda: null,
      decompressionRecipient: null,
    );

    final keys = [...accounts, ...toAccountMetas(packed.remainingAccounts)];

    return Instruction(
      programId: programId,
      accounts: keys,
      data: ByteArray(data),
    );
  }

  /// Create an instruction to create a compressed account with PDA.
  static Instruction createAccount({
    required Ed25519HDPublicKey payer,
    required NewAddressParams newAddressParams,
    required List<int> newAddress,
    required CompressedProof? recentValidityProof,
    TreeInfo? outputStateTreeInfo,
    List<CompressedAccountWithMerkleContext>? inputCompressedAccounts,
    List<int>? inputStateRootIndices,
    BigInt? lamports,
  }) {
    final outputCompressedAccounts = createNewAddressOutputState(
      address: newAddress,
      owner: payer,
      lamports: lamports,
      inputCompressedAccounts: inputCompressedAccounts,
    );

    final packed = packCompressedAccounts(
      inputCompressedAccounts: inputCompressedAccounts ?? [],
      inputStateRootIndices: inputStateRootIndices ?? [],
      outputCompressedAccounts: outputCompressedAccounts,
      outputStateTreeInfo:
          (inputCompressedAccounts == null || inputCompressedAccounts.isEmpty)
              ? outputStateTreeInfo
              : null,
    );

    final packedNewAddress = packNewAddressParams([
      newAddressParams,
    ], packed.remainingAccounts);

    final instructionData = InstructionDataInvoke(
      proof: recentValidityProof,
      inputCompressedAccountsWithMerkleContext:
          packed.packedInputCompressedAccounts,
      outputCompressedAccounts: packed.packedOutputCompressedAccounts,
      relayFee: null,
      newAddressParams: packedNewAddress.newAddressParamsPacked,
      compressOrDecompressLamports: null,
      isCompress: false,
    );

    final data = _encodeInvokeInstruction(instructionData);

    final accounts = _buildInvokeAccounts(
      feePayer: payer,
      authority: payer,
      solPoolPda: null,
      decompressionRecipient: null,
    );

    final keys = [
      ...accounts,
      ...toAccountMetas(packedNewAddress.remainingAccounts),
    ];

    return Instruction(
      programId: programId,
      accounts: keys,
      data: ByteArray(data),
    );
  }

  /// Build invoke accounts.
  static List<AccountMeta> _buildInvokeAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
    Ed25519HDPublicKey? solPoolPda,
    Ed25519HDPublicKey? decompressionRecipient,
  }) {
    final systemProgram = Ed25519HDPublicKey.fromBase58(
      '11111111111111111111111111111111',
    );

    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: registeredProgramPda, isSigner: false),
      AccountMeta.readonly(pubKey: noopProgramId, isSigner: false),
      AccountMeta.readonly(
        pubKey: accountCompressionProgramId,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: programId, isSigner: false),
      if (solPoolPda != null)
        AccountMeta.writeable(pubKey: solPoolPda, isSigner: false)
      else
        AccountMeta.readonly(pubKey: programId, isSigner: false),
      if (decompressionRecipient != null)
        AccountMeta.writeable(pubKey: decompressionRecipient, isSigner: false)
      else
        AccountMeta.readonly(pubKey: programId, isSigner: false),
      AccountMeta.readonly(pubKey: systemProgram, isSigner: false),
    ];
  }

  /// Encode invoke instruction.
  static Uint8List _encodeInvokeInstruction(InstructionDataInvoke data) {
    final dataBytes = data.encode();
    final lengthBuffer = ByteData(4)
      ..setUint32(0, dataBytes.length, Endian.little);

    final buffer =
        BytesBuilder()
          ..add(LightDiscriminators.invoke)
          ..add(lengthBuffer.buffer.asUint8List())
          ..add(dataBytes);

    return buffer.toBytes();
  }
}
