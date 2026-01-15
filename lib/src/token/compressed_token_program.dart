import 'dart:typed_data';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../constants/program_ids.dart';
import '../state/tree_info.dart';
import '../state/validity_proof.dart';
import 'token_types.dart';

/// Seeds for deriving PDAs.
final _poolSeed = 'pool'.codeUnits;

/// Compressed Token Program.
///
/// Provides instructions for:
/// - Creating token pools (SPL interface)
/// - Minting compressed tokens
/// - Compressing SPL tokens
/// - Decompressing compressed tokens
/// - Transferring compressed tokens
/// - Approving/revoking delegates
class CompressedTokenProgram {
  CompressedTokenProgram._();

  /// Compressed Token Program ID.
  static final programId = LightProgramIds.compressedTokenProgram;

  /// SPL Token Program ID.
  static final splTokenProgramId = Ed25519HDPublicKey.fromBase58(
    'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
  );

  /// SPL Token 2022 Program ID.
  static final splToken2022ProgramId = Ed25519HDPublicKey.fromBase58(
    'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
  );

  /// Associated Token Program ID.
  static final associatedTokenProgramId = Ed25519HDPublicKey.fromBase58(
    'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL',
  );

  /// CPI authority PDA (pre-computed).
  /// Derived from seeds: ["cpi_authority"] with Compressed Token Program ID.
  static final cpiAuthorityPda = Ed25519HDPublicKey.fromBase58(
    // Matches on-chain constant in light-protocol/programs/compressed-token
    'GXtd2izAiMJPwMEjfgTRH3d7k9mjn4Jq3JrWFv9gySYy',
  );

  /// Derive the CPI authority PDA.
  @Deprecated('Use cpiAuthorityPda instead - this is now pre-computed')
  static Ed25519HDPublicKey deriveCpiAuthorityPda() => cpiAuthorityPda;

  /// Derive a token pool PDA (async version).
  static Future<Ed25519HDPublicKey> deriveTokenPoolPda({
    required Ed25519HDPublicKey mint,
    int poolIndex = 0,
  }) async {
    final seeds = [
      Uint8List.fromList(_poolSeed),
      Uint8List.fromList(mint.bytes.toList()),
      if (poolIndex > 0) _encodeU8(poolIndex),
    ];

    return Ed25519HDPublicKey.findProgramAddress(
      seeds: seeds,
      programId: programId,
    );
  }

  static Uint8List _encodeU8(int value) => Uint8List.fromList([value & 0xff]);

  /// Create instruction to create a token pool (SPL interface).
  static Future<Instruction> createSplInterface({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey mint,
    Ed25519HDPublicKey? tokenProgramId,
  }) async {
    final tokenProgram = tokenProgramId ?? splTokenProgramId;
    final tokenPoolPda = await deriveTokenPoolPda(mint: mint);

    final systemProgram = Ed25519HDPublicKey.fromBase58(
      '11111111111111111111111111111111',
    );

    final accounts = [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.writeable(pubKey: tokenPoolPda, isSigner: false),
      AccountMeta.readonly(pubKey: systemProgram, isSigner: false),
      AccountMeta.readonly(pubKey: mint, isSigner: false),
      AccountMeta.readonly(pubKey: tokenProgram, isSigner: false),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
    ];

    // Discriminator for create_token_pool
    final discriminator = LightDiscriminators.createTokenPool;

    return Instruction(
      programId: programId,
      accounts: accounts,
      data: ByteArray(discriminator),
    );
  }

  /// Create instruction to mint compressed tokens.
  static Instruction mintTo({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey mint,
    required Ed25519HDPublicKey authority,
    required List<Ed25519HDPublicKey> recipients,
    required List<BigInt> amounts,
    required TreeInfo outputStateTreeInfo,
    required TokenPoolInfo tokenPoolInfo,
  }) {
    if (recipients.length != amounts.length) {
      throw ArgumentError('recipients and amounts must have the same length');
    }

    final tokenProgram = tokenPoolInfo.tokenProgramId ?? splTokenProgramId;

    // Build accounts
    final accounts = _buildMintToAccounts(
      feePayer: feePayer,
      authority: authority,
      mint: mint,
      tokenPoolPda: tokenPoolInfo.splInterfacePda,
      tokenProgram: tokenProgram,
      cpiAuthorityPda: cpiAuthorityPda,
    );

    // Add merkle tree as remaining account
    final remainingAccounts = [
      AccountMeta.writeable(pubKey: outputStateTreeInfo.queue, isSigner: false),
    ];

    // Encode instruction data
    final data = _encodeMintToData(recipients, amounts);

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...remainingAccounts],
      data: data,
    );
  }

  /// Create instruction to transfer compressed tokens.
  static Instruction transfer({
    required Ed25519HDPublicKey payer,
    required List<ParsedTokenAccount> inputCompressedTokenAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt amount,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
  }) {
    if (inputCompressedTokenAccounts.isEmpty) {
      throw ArgumentError('At least one input account is required');
    }

    final mint = inputCompressedTokenAccounts.first.parsed.mint;
    final owner = inputCompressedTokenAccounts.first.parsed.owner;

    // Calculate output state
    final (outputState, _) = _createTransferOutputState(
      inputAccounts: inputCompressedTokenAccounts,
      toAddress: toAddress,
      amount: amount,
    );

    // Pack accounts
    final packed = _packCompressedTokenAccounts(
      inputAccounts: inputCompressedTokenAccounts,
      rootIndices: recentInputStateRootIndices,
      outputState: outputState,
    );

    // Build accounts
    final accounts = _buildTransferAccounts(feePayer: payer, authority: owner);

    // Encode instruction data
    final data = _encodeTransferData(
      proof: recentValidityProof,
      mint: mint,
      packedInput: packed.packedInput,
      packedOutput: packed.packedOutput,
    );

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...packed.remainingAccountMetas],
      data: data,
    );
  }

  /// Create instruction to compress SPL tokens.
  static Instruction compress({
    required Ed25519HDPublicKey payer,
    required Ed25519HDPublicKey owner,
    required Ed25519HDPublicKey source,
    required Ed25519HDPublicKey mint,
    required BigInt amount,
    required TreeInfo outputStateTreeInfo,
    required TokenPoolInfo tokenPoolInfo,
    Ed25519HDPublicKey? toAddress,
  }) {
    final recipient = toAddress ?? owner;
    final tokenProgram = tokenPoolInfo.tokenProgramId ?? splTokenProgramId;

    // Create output state for compression
    final outputState = [
      TokenTransferOutputData(owner: recipient, amount: amount),
    ];

    // Pack for compress (no inputs, only outputs)
    final packed = _packForCompress(
      outputState: outputState,
      outputStateTreeInfo: outputStateTreeInfo,
    );

    // Build accounts for compress
    final accounts = _buildCompressAccounts(
      feePayer: payer,
      authority: owner,
      sourceTokenAccount: source,
      tokenPoolPda: tokenPoolInfo.splInterfacePda,
      tokenProgram: tokenProgram,
    );

    // Encode compress data
    final data = _encodeCompressData(
      mint: mint,
      amount: amount,
      packedOutput: packed.packedOutput,
    );

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...packed.remainingAccountMetas],
      data: data,
    );
  }

  /// Create instruction to decompress compressed tokens to SPL.
  static Instruction decompress({
    required Ed25519HDPublicKey payer,
    required List<ParsedTokenAccount> inputCompressedTokenAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt amount,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
    required TokenPoolInfo tokenPoolInfo,
  }) {
    if (inputCompressedTokenAccounts.isEmpty) {
      throw ArgumentError('At least one input account is required');
    }

    final mint = inputCompressedTokenAccounts.first.parsed.mint;
    final owner = inputCompressedTokenAccounts.first.parsed.owner;

    // Calculate decompress output state (change if any)
    final outputState = _createDecompressOutputState(
      inputAccounts: inputCompressedTokenAccounts,
      amount: amount,
    );

    // Pack accounts
    final packed = _packCompressedTokenAccounts(
      inputAccounts: inputCompressedTokenAccounts,
      rootIndices: recentInputStateRootIndices,
      outputState: outputState,
    );

    final tokenProgram = tokenPoolInfo.tokenProgramId ?? splTokenProgramId;

    // Build accounts for decompress
    final accounts = _buildDecompressAccounts(
      feePayer: payer,
      authority: owner,
      destinationTokenAccount: toAddress,
      tokenPoolPda: tokenPoolInfo.splInterfacePda,
      tokenProgram: tokenProgram,
    );

    // Encode decompress data
    final data = _encodeDecompressData(
      proof: recentValidityProof,
      mint: mint,
      amount: amount,
      packedInput: packed.packedInput,
      packedOutput: packed.packedOutput,
    );

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...packed.remainingAccountMetas],
      data: data,
    );
  }

  /// Create instruction to approve a delegate for compressed tokens.
  static Instruction approve({
    required Ed25519HDPublicKey payer,
    required List<ParsedTokenAccount> inputCompressedTokenAccounts,
    required Ed25519HDPublicKey delegate,
    required BigInt amount,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
  }) {
    if (inputCompressedTokenAccounts.isEmpty) {
      throw ArgumentError('At least one input account is required');
    }

    final mint = inputCompressedTokenAccounts.first.parsed.mint;
    final owner = inputCompressedTokenAccounts.first.parsed.owner;

    // For approve, we create output with delegate set
    final outputState = _createApproveOutputState(
      inputAccounts: inputCompressedTokenAccounts,
      delegate: delegate,
      amount: amount,
    );

    // Pack accounts
    final packed = _packCompressedTokenAccounts(
      inputAccounts: inputCompressedTokenAccounts,
      rootIndices: recentInputStateRootIndices,
      outputState: outputState,
    );

    // Build accounts
    final accounts = _buildApproveAccounts(feePayer: payer, authority: owner);

    // Encode approve data
    final data = _encodeApproveData(
      proof: recentValidityProof,
      mint: mint,
      packedInput: packed.packedInput,
      packedOutput: packed.packedOutput,
    );

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...packed.remainingAccountMetas],
      data: data,
    );
  }

  /// Create instruction to revoke a delegate for compressed tokens.
  static Instruction revoke({
    required Ed25519HDPublicKey payer,
    required List<ParsedTokenAccount> inputCompressedTokenAccounts,
    required List<int> recentInputStateRootIndices,
    required CompressedProof? recentValidityProof,
  }) {
    if (inputCompressedTokenAccounts.isEmpty) {
      throw ArgumentError('At least one input account is required');
    }

    final mint = inputCompressedTokenAccounts.first.parsed.mint;
    final owner = inputCompressedTokenAccounts.first.parsed.owner;

    // Pack accounts (revoke has no outputs, just nullifies and recreates)
    final packed = _packCompressedTokenAccounts(
      inputAccounts: inputCompressedTokenAccounts,
      rootIndices: recentInputStateRootIndices,
      outputState: [], // No outputs for revoke
    );

    // Build accounts
    final accounts = _buildRevokeAccounts(feePayer: payer, authority: owner);

    // Encode revoke data
    final data = _encodeRevokeData(
      proof: recentValidityProof,
      mint: mint,
      packedInput: packed.packedInput,
      outputTreeIndex: _getOutputTreeIndex(inputCompressedTokenAccounts.first),
    );

    return Instruction(
      programId: programId,
      accounts: [...accounts, ...packed.remainingAccountMetas],
      data: data,
    );
  }

  // Internal helper methods

  static List<AccountMeta> _buildMintToAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
    required Ed25519HDPublicKey mint,
    required Ed25519HDPublicKey tokenPoolPda,
    required Ed25519HDPublicKey tokenProgram,
    required Ed25519HDPublicKey cpiAuthorityPda,
  }) {
    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.writeable(pubKey: mint, isSigner: false),
      AccountMeta.writeable(pubKey: tokenPoolPda, isSigner: false),
      AccountMeta.readonly(pubKey: tokenProgram, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.compressedTokenProgram,
        isSigner: false,
      ),
    ];
  }

  static List<AccountMeta> _buildTransferAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
    Ed25519HDPublicKey? tokenPoolPda,
    Ed25519HDPublicKey? compressOrDecompressTokenAccount,
    Ed25519HDPublicKey? tokenProgram,
  }) {
    // When optional accounts are not provided, use the program ID as placeholder
    // This matches the official JS SDK behavior where undefined accounts use defaultPubkey
    final placeholderPubkey = programId;

    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.compressedTokenProgram,
        isSigner: false,
      ),
      // Token pool PDA - required for compress/decompress, placeholder for transfer
      AccountMeta.writeable(
        pubKey: tokenPoolPda ?? placeholderPubkey,
        isSigner: false,
      ),
      // Compress/decompress token account - placeholder when not used
      AccountMeta.writeable(
        pubKey: compressOrDecompressTokenAccount ?? placeholderPubkey,
        isSigner: false,
      ),
      // Token program - placeholder when not used
      AccountMeta.readonly(
        pubKey: tokenProgram ?? placeholderPubkey,
        isSigner: false,
      ),
      // System program - always required
      AccountMeta.readonly(
        pubKey: LightProgramIds.systemProgram,
        isSigner: false,
      ),
    ];
  }

  static List<AccountMeta> _buildCompressAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
    required Ed25519HDPublicKey sourceTokenAccount,
    required Ed25519HDPublicKey tokenPoolPda,
    required Ed25519HDPublicKey tokenProgram,
  }) {
    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: programId, isSigner: false),
      AccountMeta.writeable(pubKey: tokenPoolPda, isSigner: false),
      AccountMeta.writeable(pubKey: sourceTokenAccount, isSigner: false),
      AccountMeta.readonly(pubKey: tokenProgram, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.systemProgram,
        isSigner: false,
      ),
    ];
  }

  static List<AccountMeta> _buildDecompressAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
    required Ed25519HDPublicKey destinationTokenAccount,
    required Ed25519HDPublicKey tokenPoolPda,
    required Ed25519HDPublicKey tokenProgram,
  }) {
    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: programId, isSigner: false),
      AccountMeta.writeable(pubKey: tokenPoolPda, isSigner: false),
      AccountMeta.writeable(pubKey: destinationTokenAccount, isSigner: false),
      AccountMeta.readonly(pubKey: tokenProgram, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.systemProgram,
        isSigner: false,
      ),
    ];
  }

  static List<AccountMeta> _buildApproveAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
  }) {
    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: programId, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.systemProgram,
        isSigner: false,
      ),
    ];
  }

  static List<AccountMeta> _buildRevokeAccounts({
    required Ed25519HDPublicKey feePayer,
    required Ed25519HDPublicKey authority,
  }) {
    return [
      AccountMeta.writeable(pubKey: feePayer, isSigner: true),
      AccountMeta.readonly(pubKey: authority, isSigner: true),
      AccountMeta.readonly(pubKey: cpiAuthorityPda, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.lightSystemProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: getRegisteredProgramPda(), isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.noopProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: accountCompressionAuthority,
        isSigner: false,
      ),
      AccountMeta.readonly(
        pubKey: LightProgramIds.accountCompressionProgram,
        isSigner: false,
      ),
      AccountMeta.readonly(pubKey: programId, isSigner: false),
      AccountMeta.readonly(
        pubKey: LightProgramIds.systemProgram,
        isSigner: false,
      ),
    ];
  }

  static ByteArray _encodeMintToData(
    List<Ed25519HDPublicKey> recipients,
    List<BigInt> amounts,
  ) {
    // Simplified encoding - full implementation would use Borsh
    final buffer = BytesBuilder();

    // Discriminator for mint_to
    buffer.add(LightDiscriminators.mintTo);

    // Encode recipients and amounts
    // Length prefix (u32)
    final lengthData = ByteData(4)
      ..setUint32(0, recipients.length, Endian.little);
    buffer.add(lengthData.buffer.asUint8List());

    for (var i = 0; i < recipients.length; i++) {
      buffer.add(recipients[i].bytes);
      final amountData = ByteData(8)
        ..setUint64(0, amounts[i].toInt(), Endian.little);
      buffer.add(amountData.buffer.asUint8List());
    }

    return ByteArray(buffer.toBytes());
  }

  /// Encodes transfer instruction data matching TS layout:
  /// [TRANSFER_DISCRIMINATOR (8 bytes)][length (4 bytes u32 LE)][borsh data]
  ///
  /// Borsh data follows CompressedTokenInstructionDataTransferLayout:
  /// struct([
  ///   option(CompressedProofLayout, 'proof'),
  ///   publicKey('mint'),
  ///   option(DelegatedTransferLayout, 'delegatedTransfer'),
  ///   vec(InputTokenDataWithContextLayout, 'inputTokenDataWithContext'),
  ///   vec(PackedTokenTransferOutputDataLayout, 'outputCompressedAccounts'),
  ///   bool('isCompress'),
  ///   option(u64(), 'compressOrDecompressAmount'),
  ///   option(CpiContextLayout, 'cpiContext'),
  ///   option(u8(), 'lamportsChangeAccountMerkleTreeIndex'),
  /// ])
  static ByteArray _encodeTransferData({
    required CompressedProof? proof,
    required Ed25519HDPublicKey mint,
    required List<_PackedInputTokenAccount> packedInput,
    required List<_PackedOutputTokenAccount> packedOutput,
  }) {
    // Encode the borsh data first to get its length
    final dataBuffer = BytesBuilder();

    // 1. proof (Option<CompressedProof>)
    if (proof != null) {
      dataBuffer.addByte(1);
      dataBuffer.add(proof.a);
      dataBuffer.add(proof.b);
      dataBuffer.add(proof.c);
    } else {
      dataBuffer.addByte(0);
    }

    // 2. mint (PublicKey - 32 bytes)
    dataBuffer.add(mint.bytes);

    // 3. delegatedTransfer (Option<DelegatedTransfer>) - always None
    dataBuffer.addByte(0);

    // 4. inputTokenDataWithContext (Vec<InputTokenDataWithContext>)
    final inputLenData = ByteData(4)
      ..setUint32(0, packedInput.length, Endian.little);
    dataBuffer.add(inputLenData.buffer.asUint8List());
    for (final input in packedInput) {
      dataBuffer.add(_encodePackedInputTokenAccount(input));
    }

    // 5. outputCompressedAccounts (Vec<PackedTokenTransferOutputData>)
    final outputLenData = ByteData(4)
      ..setUint32(0, packedOutput.length, Endian.little);
    dataBuffer.add(outputLenData.buffer.asUint8List());
    for (final output in packedOutput) {
      dataBuffer.add(_encodePackedOutputTokenAccount(output));
    }

    // 6. isCompress (bool) - false for transfer
    dataBuffer.addByte(0);

    // 7. compressOrDecompressAmount (Option<u64>) - None for transfer
    dataBuffer.addByte(0);

    // 8. cpiContext (Option<CpiContext>) - always None
    dataBuffer.addByte(0);

    // 9. lamportsChangeAccountMerkleTreeIndex (Option<u8>) - always None
    dataBuffer.addByte(0);

    final borshData = dataBuffer.toBytes();

    // Now build the final instruction data
    final buffer = BytesBuilder();

    // Discriminator for transfer
    buffer.add(LightDiscriminators.transfer);

    // Length of borsh data (4 bytes u32 LE)
    final lengthData = ByteData(4)
      ..setUint32(0, borshData.length, Endian.little);
    buffer.add(lengthData.buffer.asUint8List());

    // Borsh data
    buffer.add(borshData);

    return ByteArray(buffer.toBytes());
  }

  /// Encodes compress instruction data matching TS layout.
  /// Uses same format as transfer with isCompress=true and compressOrDecompressAmount set.
  static ByteArray _encodeCompressData({
    required Ed25519HDPublicKey mint,
    required BigInt amount,
    required List<_PackedOutputTokenAccount> packedOutput,
  }) {
    // Encode the borsh data first to get its length
    final dataBuffer = BytesBuilder();

    // 1. proof (Option<CompressedProof>) - None for compress
    dataBuffer.addByte(0);

    // 2. mint (PublicKey - 32 bytes)
    dataBuffer.add(mint.bytes);

    // 3. delegatedTransfer (Option<DelegatedTransfer>) - always None
    dataBuffer.addByte(0);

    // 4. inputTokenDataWithContext (Vec<InputTokenDataWithContext>) - empty for compress
    final inputLenData = ByteData(4)..setUint32(0, 0, Endian.little);
    dataBuffer.add(inputLenData.buffer.asUint8List());

    // 5. outputCompressedAccounts (Vec<PackedTokenTransferOutputData>)
    final outputLenData = ByteData(4)
      ..setUint32(0, packedOutput.length, Endian.little);
    dataBuffer.add(outputLenData.buffer.asUint8List());
    for (final output in packedOutput) {
      dataBuffer.add(_encodePackedOutputTokenAccount(output));
    }

    // 6. isCompress (bool) - true for compress
    dataBuffer.addByte(1);

    // 7. compressOrDecompressAmount (Option<u64>) - Some for compress
    dataBuffer.addByte(1);
    final amountData = ByteData(8)..setUint64(0, amount.toInt(), Endian.little);
    dataBuffer.add(amountData.buffer.asUint8List());

    // 8. cpiContext (Option<CpiContext>) - always None
    dataBuffer.addByte(0);

    // 9. lamportsChangeAccountMerkleTreeIndex (Option<u8>) - always None
    dataBuffer.addByte(0);

    final borshData = dataBuffer.toBytes();

    // Now build the final instruction data
    final buffer = BytesBuilder();

    // Discriminator for transfer (compress uses transfer instruction)
    buffer.add(LightDiscriminators.transfer);

    // Length of borsh data (4 bytes u32 LE)
    final lengthData = ByteData(4)
      ..setUint32(0, borshData.length, Endian.little);
    buffer.add(lengthData.buffer.asUint8List());

    // Borsh data
    buffer.add(borshData);

    return ByteArray(buffer.toBytes());
  }

  /// Encodes decompress instruction data matching TS layout.
  /// Uses same format as transfer with isCompress=false and compressOrDecompressAmount set.
  static ByteArray _encodeDecompressData({
    required CompressedProof? proof,
    required Ed25519HDPublicKey mint,
    required BigInt amount,
    required List<_PackedInputTokenAccount> packedInput,
    required List<_PackedOutputTokenAccount> packedOutput,
  }) {
    // Encode the borsh data first to get its length
    final dataBuffer = BytesBuilder();

    // 1. proof (Option<CompressedProof>)
    if (proof != null) {
      dataBuffer.addByte(1);
      dataBuffer.add(proof.a);
      dataBuffer.add(proof.b);
      dataBuffer.add(proof.c);
    } else {
      dataBuffer.addByte(0);
    }

    // 2. mint (PublicKey - 32 bytes)
    dataBuffer.add(mint.bytes);

    // 3. delegatedTransfer (Option<DelegatedTransfer>) - always None
    dataBuffer.addByte(0);

    // 4. inputTokenDataWithContext (Vec<InputTokenDataWithContext>)
    final inputLenData = ByteData(4)
      ..setUint32(0, packedInput.length, Endian.little);
    dataBuffer.add(inputLenData.buffer.asUint8List());
    for (final input in packedInput) {
      dataBuffer.add(_encodePackedInputTokenAccount(input));
    }

    // 5. outputCompressedAccounts (Vec<PackedTokenTransferOutputData>)
    final outputLenData = ByteData(4)
      ..setUint32(0, packedOutput.length, Endian.little);
    dataBuffer.add(outputLenData.buffer.asUint8List());
    for (final output in packedOutput) {
      dataBuffer.add(_encodePackedOutputTokenAccount(output));
    }

    // 6. isCompress (bool) - false for decompress
    dataBuffer.addByte(0);

    // 7. compressOrDecompressAmount (Option<u64>) - Some for decompress
    dataBuffer.addByte(1);
    final amountData = ByteData(8)..setUint64(0, amount.toInt(), Endian.little);
    dataBuffer.add(amountData.buffer.asUint8List());

    // 8. cpiContext (Option<CpiContext>) - always None
    dataBuffer.addByte(0);

    // 9. lamportsChangeAccountMerkleTreeIndex (Option<u8>) - always None
    dataBuffer.addByte(0);

    final borshData = dataBuffer.toBytes();

    // Now build the final instruction data
    final buffer = BytesBuilder();

    // Discriminator for transfer (decompress uses transfer instruction)
    buffer.add(LightDiscriminators.transfer);

    // Length of borsh data (4 bytes u32 LE)
    final lengthData = ByteData(4)
      ..setUint32(0, borshData.length, Endian.little);
    buffer.add(lengthData.buffer.asUint8List());

    // Borsh data
    buffer.add(borshData);

    return ByteArray(buffer.toBytes());
  }

  static ByteArray _encodeApproveData({
    required CompressedProof? proof,
    required Ed25519HDPublicKey mint,
    required List<_PackedInputTokenAccount> packedInput,
    required List<_PackedOutputTokenAccount> packedOutput,
  }) {
    final buffer = BytesBuilder();

    // Discriminator for approve
    buffer.add(LightDiscriminators.approve);

    // Proof (Option)
    if (proof != null) {
      buffer.addByte(1);
      buffer.add(proof.a);
      buffer.add(proof.b);
      buffer.add(proof.c);
    } else {
      buffer.addByte(0);
    }

    // Mint
    buffer.add(mint.bytes);

    // Input accounts
    final inputLenData = ByteData(4)
      ..setUint32(0, packedInput.length, Endian.little);
    buffer.add(inputLenData.buffer.asUint8List());

    for (final input in packedInput) {
      buffer.add(_encodePackedInputTokenAccount(input));
    }

    // Output accounts
    final outputLenData = ByteData(4)
      ..setUint32(0, packedOutput.length, Endian.little);
    buffer.add(outputLenData.buffer.asUint8List());

    for (final output in packedOutput) {
      buffer.add(_encodePackedOutputTokenAccount(output));
    }

    return ByteArray(buffer.toBytes());
  }

  static ByteArray _encodeRevokeData({
    required CompressedProof? proof,
    required Ed25519HDPublicKey mint,
    required List<_PackedInputTokenAccount> packedInput,
    required int outputTreeIndex,
  }) {
    final buffer = BytesBuilder();

    // Discriminator for revoke
    buffer.add(LightDiscriminators.revoke);

    // Proof (Option)
    if (proof != null) {
      buffer.addByte(1);
      buffer.add(proof.a);
      buffer.add(proof.b);
      buffer.add(proof.c);
    } else {
      buffer.addByte(0);
    }

    // Mint
    buffer.add(mint.bytes);

    // Input accounts
    final inputLenData = ByteData(4)
      ..setUint32(0, packedInput.length, Endian.little);
    buffer.add(inputLenData.buffer.asUint8List());

    for (final input in packedInput) {
      buffer.add(_encodePackedInputTokenAccount(input));
    }

    // outputAccountMerkleTreeIndex
    buffer.addByte(outputTreeIndex);

    return ByteArray(buffer.toBytes());
  }

  /// Encodes InputTokenDataWithContext matching TS layout:
  /// struct([
  ///   u64('amount'),
  ///   option(u8(), 'delegateIndex'),
  ///   struct([
  ///     u8('merkleTreePubkeyIndex'),
  ///     u8('queuePubkeyIndex'),
  ///     u32('leafIndex'),
  ///     bool('proveByIndex'),
  ///   ], 'merkleContext'),
  ///   u16('rootIndex'),
  ///   option(u64(), 'lamports'),
  ///   option(vecU8(), 'tlv'),
  /// ])
  static Uint8List _encodePackedInputTokenAccount(
    _PackedInputTokenAccount input,
  ) {
    final buffer = BytesBuilder();

    // 1. amount (u64)
    final amountData = ByteData(8)
      ..setUint64(0, input.amount.toInt(), Endian.little);
    buffer.add(amountData.buffer.asUint8List());

    // 2. delegateIndex (Option<u8>)
    if (input.delegateIndex != null) {
      buffer.addByte(1);
      buffer.addByte(input.delegateIndex!);
    } else {
      buffer.addByte(0);
    }

    // 3. merkleContext (struct)
    buffer.addByte(input.merkleContext.merkleTreePubkeyIndex);
    buffer.addByte(input.merkleContext.queuePubkeyIndex);
    final leafIndexData = ByteData(4)
      ..setUint32(0, input.merkleContext.leafIndex, Endian.little);
    buffer.add(leafIndexData.buffer.asUint8List());
    buffer.addByte(input.merkleContext.proveByIndex ? 1 : 0);

    // 4. rootIndex (u16)
    final rootIndexData = ByteData(2)
      ..setUint16(0, input.rootIndex, Endian.little);
    buffer.add(rootIndexData.buffer.asUint8List());

    // 5. lamports (Option<u64>) - always None for token transfers
    buffer.addByte(0);

    // 6. tlv (Option<Vec<u8>>) - always None for basic transfers
    buffer.addByte(0);

    return buffer.toBytes();
  }

  /// Encodes PackedTokenTransferOutputData matching TS layout:
  /// struct([
  ///   publicKey('owner'),
  ///   u64('amount'),
  ///   option(u64(), 'lamports'),
  ///   u8('merkleTreeIndex'),
  ///   option(vecU8(), 'tlv'),
  /// ])
  static Uint8List _encodePackedOutputTokenAccount(
    _PackedOutputTokenAccount output,
  ) {
    final buffer = BytesBuilder();

    // 1. owner (PublicKey - 32 bytes)
    buffer.add(output.owner.bytes);

    // 2. amount (u64)
    final amountData = ByteData(8)
      ..setUint64(0, output.amount.toInt(), Endian.little);
    buffer.add(amountData.buffer.asUint8List());

    // 3. lamports (Option<u64>)
    if (output.lamports != null) {
      buffer.addByte(1);
      final lamportsData = ByteData(8)
        ..setUint64(0, output.lamports!.toInt(), Endian.little);
      buffer.add(lamportsData.buffer.asUint8List());
    } else {
      buffer.addByte(0);
    }

    // 4. merkleTreeIndex (u8)
    buffer.addByte(output.merkleTreeIndex);

    // 5. tlv (Option<Vec<u8>>) - always None for basic transfers
    buffer.addByte(0);

    return buffer.toBytes();
  }

  static (List<TokenTransferOutputData>, BigInt) _createTransferOutputState({
    required List<ParsedTokenAccount> inputAccounts,
    required Ed25519HDPublicKey toAddress,
    required BigInt amount,
  }) {
    // Sum input amounts
    final inputAmount = inputAccounts.fold<BigInt>(
      BigInt.zero,
      (sum, account) => sum + account.parsed.amount,
    );

    if (inputAmount < amount) {
      throw ArgumentError(
        'Insufficient balance: have $inputAmount, need $amount',
      );
    }

    final changeAmount = inputAmount - amount;
    final owner = inputAccounts.first.parsed.owner;

    if (changeAmount == BigInt.zero) {
      return (
        [TokenTransferOutputData(owner: toAddress, amount: amount)],
        inputAmount,
      );
    }

    return (
      [
        TokenTransferOutputData(owner: owner, amount: changeAmount),
        TokenTransferOutputData(owner: toAddress, amount: amount),
      ],
      inputAmount,
    );
  }

  static List<TokenTransferOutputData> _createDecompressOutputState({
    required List<ParsedTokenAccount> inputAccounts,
    required BigInt amount,
  }) {
    // Sum input amounts
    final inputAmount = inputAccounts.fold<BigInt>(
      BigInt.zero,
      (sum, account) => sum + account.parsed.amount,
    );

    if (inputAmount < amount) {
      throw ArgumentError(
        'Insufficient balance: have $inputAmount, need $amount',
      );
    }

    final changeAmount = inputAmount - amount;
    final owner = inputAccounts.first.parsed.owner;

    // If no change, return empty (all decompressed to SPL)
    if (changeAmount == BigInt.zero) {
      return [];
    }

    // Return change as compressed token
    return [TokenTransferOutputData(owner: owner, amount: changeAmount)];
  }

  static List<TokenTransferOutputData> _createApproveOutputState({
    required List<ParsedTokenAccount> inputAccounts,
    required Ed25519HDPublicKey delegate,
    required BigInt amount,
  }) {
    // Sum input amounts
    final inputAmount = inputAccounts.fold<BigInt>(
      BigInt.zero,
      (sum, account) => sum + account.parsed.amount,
    );

    if (inputAmount < amount) {
      throw ArgumentError(
        'Insufficient balance: have $inputAmount, need $amount',
      );
    }

    final changeAmount = inputAmount - amount;
    final owner = inputAccounts.first.parsed.owner;

    // Create output with delegation
    final outputs = <TokenTransferOutputData>[];

    if (changeAmount > BigInt.zero) {
      // Change without delegation
      outputs.add(TokenTransferOutputData(owner: owner, amount: changeAmount));
    }

    // Delegated amount
    outputs.add(
      TokenTransferOutputData(owner: owner, amount: amount, delegate: delegate),
    );

    return outputs;
  }

  static int _getOutputTreeIndex(ParsedTokenAccount account) {
    return account.compressedAccount.treeInfo.treeType == TreeType.stateV2
        ? 2
        : 1;
  }

  static _PackedTokenAccounts _packCompressedTokenAccounts({
    required List<ParsedTokenAccount> inputAccounts,
    required List<int> rootIndices,
    required List<TokenTransferOutputData> outputState,
  }) {
    final remainingAccounts = <Ed25519HDPublicKey>[];
    final packedInput = <_PackedInputTokenAccount>[];
    final packedOutput = <_PackedOutputTokenAccount>[];

    // Pack input accounts
    for (var i = 0; i < inputAccounts.length; i++) {
      final account = inputAccounts[i];
      final ca = account.compressedAccount;

      final treeIndex = _getIndexOrAdd(remainingAccounts, ca.treeInfo.tree);
      final queueIndex = _getIndexOrAdd(remainingAccounts, ca.treeInfo.queue);

      packedInput.add(
        _PackedInputTokenAccount(
          merkleContext: _PackedMerkleContext(
            merkleTreePubkeyIndex: treeIndex,
            queuePubkeyIndex: queueIndex,
            leafIndex: ca.leafIndex,
            proveByIndex: ca.proveByIndex,
          ),
          rootIndex: rootIndices[i],
          amount: account.parsed.amount,
          delegateIndex: null,
        ),
      );
    }

    // Determine active output tree (matches stateless.js logic)
    final baseTreeInfo = inputAccounts.first.compressedAccount.treeInfo;
    final activeTreeInfo = baseTreeInfo.nextTreeInfo ?? baseTreeInfo;

    // Provide the state Merkle tree account itself (tree). Using queue here can
    // trip the on-chain discriminator check (error 6042) if the program expects
    // the state tree account. So we always use the tree account.
    final activeTreeOrQueue = activeTreeInfo.tree;

    // Pack output accounts
    for (final output in outputState) {
      final treeIndex = _getIndexOrAdd(remainingAccounts, activeTreeOrQueue);

      packedOutput.add(
        _PackedOutputTokenAccount(
          owner: output.owner,
          amount: output.amount,
          lamports: output.lamports,
          merkleTreeIndex: treeIndex,
        ),
      );
    }

    return _PackedTokenAccounts(
      packedInput: packedInput,
      packedOutput: packedOutput,
      remainingAccountMetas:
          remainingAccounts
              .map((a) => AccountMeta.writeable(pubKey: a, isSigner: false))
              .toList(),
    );
  }

  static _PackedTokenAccounts _packForCompress({
    required List<TokenTransferOutputData> outputState,
    required TreeInfo outputStateTreeInfo,
  }) {
    final remainingAccounts = <Ed25519HDPublicKey>[];
    final packedOutput = <_PackedOutputTokenAccount>[];

    // Determine output tree queue
    final outputTreeQueue =
        outputStateTreeInfo.treeType == TreeType.stateV2
            ? outputStateTreeInfo.queue
            : outputStateTreeInfo.tree;

    // Pack output accounts
    for (final output in outputState) {
      final treeIndex = _getIndexOrAdd(remainingAccounts, outputTreeQueue);

      packedOutput.add(
        _PackedOutputTokenAccount(
          owner: output.owner,
          amount: output.amount,
          lamports: output.lamports,
          merkleTreeIndex: treeIndex,
        ),
      );
    }

    return _PackedTokenAccounts(
      packedInput: [],
      packedOutput: packedOutput,
      remainingAccountMetas:
          remainingAccounts
              .map((a) => AccountMeta.writeable(pubKey: a, isSigner: false))
              .toList(),
    );
  }

  static int _getIndexOrAdd(
    List<Ed25519HDPublicKey> accounts,
    Ed25519HDPublicKey key,
  ) {
    final index = accounts.indexWhere((k) => k == key);
    if (index == -1) {
      accounts.add(key);
      return accounts.length - 1;
    }
    return index;
  }
}

// Internal types for packing

class _PackedMerkleContext {
  const _PackedMerkleContext({
    required this.merkleTreePubkeyIndex,
    required this.queuePubkeyIndex,
    required this.leafIndex,
    required this.proveByIndex,
  });

  final int merkleTreePubkeyIndex;
  final int queuePubkeyIndex;
  final int leafIndex;
  final bool proveByIndex;
}

class _PackedInputTokenAccount {
  const _PackedInputTokenAccount({
    required this.merkleContext,
    required this.rootIndex,
    required this.amount,
    this.delegateIndex,
  });

  final _PackedMerkleContext merkleContext;
  final int rootIndex;
  final BigInt amount;
  final int? delegateIndex;
}

class _PackedOutputTokenAccount {
  const _PackedOutputTokenAccount({
    required this.owner,
    required this.amount,
    this.lamports,
    required this.merkleTreeIndex,
  });

  final Ed25519HDPublicKey owner;
  final BigInt amount;
  final BigInt? lamports;
  final int merkleTreeIndex;
}

class _PackedTokenAccounts {
  const _PackedTokenAccounts({
    required this.packedInput,
    required this.packedOutput,
    required this.remainingAccountMetas,
  });

  final List<_PackedInputTokenAccount> packedInput;
  final List<_PackedOutputTokenAccount> packedOutput;
  final List<AccountMeta> remainingAccountMetas;
}
