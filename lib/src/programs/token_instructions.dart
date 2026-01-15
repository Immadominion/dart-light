import 'dart:typed_data';

import 'package:solana/solana.dart';

import '../state/state.dart';
import '../utils/borsh.dart';
import 'account_layouts.dart';
import 'instruction_cpi.dart';

/// Token data for an input compressed token account with packed merkle context.
class InputTokenDataWithContext {
  final BigInt amount;
  final int? delegateIndex;
  final PackedMerkleContext merkleContext;
  final int rootIndex;
  final BigInt? lamports;
  final Uint8List? tlv;

  const InputTokenDataWithContext({
    required this.amount,
    this.delegateIndex,
    required this.merkleContext,
    required this.rootIndex,
    this.lamports,
    this.tlv,
  });

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // amount: u64
    writer.writeU64(amount);

    // delegateIndex: Option<u8>
    writer.writeOption(delegateIndex, (val) => writer.writeU8(val));

    // merkleContext: PackedMerkleContext (7 bytes)
    writer.writeFixedArray(merkleContext.encode());

    // rootIndex: u16
    writer.writeU16(rootIndex);

    // lamports: Option<u64>
    writer.writeOption(lamports, (val) => writer.writeU64(val));

    // tlv: Option<Vec<u8>>
    writer.writeOption(tlv, (val) => writer.writeVec(val));

    return writer.toBytes();
  }
}

/// Packed output data for token transfers.
class PackedTokenTransferOutputData {
  final Ed25519HDPublicKey owner;
  final BigInt amount;
  final BigInt? lamports;
  final int merkleTreeIndex;
  final Uint8List? tlv;

  const PackedTokenTransferOutputData({
    required this.owner,
    required this.amount,
    this.lamports,
    required this.merkleTreeIndex,
    this.tlv,
  });

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // owner: [u8; 32]
    writer.writeFixedArray(owner.bytes);

    // amount: u64
    writer.writeU64(amount);

    // lamports: Option<u64>
    writer.writeOption(lamports, (val) => writer.writeU64(val));

    // merkleTreeIndex: u8
    writer.writeU8(merkleTreeIndex);

    // tlv: Option<Vec<u8>>
    writer.writeOption(tlv, (val) => writer.writeVec(val));

    return writer.toBytes();
  }
}

/// Delegated transfer information.
class DelegatedTransfer {
  final Ed25519HDPublicKey owner;
  final int? delegateChangeAccountIndex;

  const DelegatedTransfer({
    required this.owner,
    this.delegateChangeAccountIndex,
  });

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // owner: [u8; 32]
    writer.writeFixedArray(owner.bytes);

    // delegateChangeAccountIndex: Option<u8>
    writer.writeOption(
      delegateChangeAccountIndex,
      (val) => writer.writeU8(val),
    );

    return writer.toBytes();
  }
}

/// Transfer instruction data for compressed tokens.
/// Used for: transfer, compress, decompress operations.
class InstructionDataTransfer {
  final CompressedProof? proof;
  final Ed25519HDPublicKey mint;
  final DelegatedTransfer? delegatedTransfer;
  final List<InputTokenDataWithContext> inputTokenDataWithContext;
  final List<PackedTokenTransferOutputData> outputCompressedAccounts;
  final bool isCompress;
  final BigInt? compressOrDecompressAmount;
  final CompressedCpiContext? cpiContext;
  final int? lamportsChangeAccountMerkleTreeIndex;

  const InstructionDataTransfer({
    this.proof,
    required this.mint,
    this.delegatedTransfer,
    required this.inputTokenDataWithContext,
    required this.outputCompressedAccounts,
    required this.isCompress,
    this.compressOrDecompressAmount,
    this.cpiContext,
    this.lamportsChangeAccountMerkleTreeIndex,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // proof: Option<CompressedProof>
    writer.writeOption(proof, (val) => writer.writeFixedArray(val.encode()));

    // mint: [u8; 32]
    writer.writeFixedArray(mint.bytes);

    // delegatedTransfer: Option<DelegatedTransfer>
    writer.writeOption(delegatedTransfer, (val) {
      writer.writeFixedArray(val.encode());
    });

    // inputTokenDataWithContext: Vec<InputTokenDataWithContext>
    final inputsBytes = BytesBuilder();
    inputsBytes.add(BorshWriter.u32(inputTokenDataWithContext.length));
    for (final item in inputTokenDataWithContext) {
      inputsBytes.add(item.encode());
    }
    writer.writeFixedArray(inputsBytes.toBytes());

    // outputCompressedAccounts: Vec<PackedTokenTransferOutputData>
    final outputsBytes = BytesBuilder();
    outputsBytes.add(BorshWriter.u32(outputCompressedAccounts.length));
    for (final item in outputCompressedAccounts) {
      outputsBytes.add(item.encode());
    }
    writer.writeFixedArray(outputsBytes.toBytes());

    // isCompress: bool
    writer.writeBool(isCompress);

    // compressOrDecompressAmount: Option<u64>
    writer.writeOption(
      compressOrDecompressAmount,
      (val) => writer.writeU64(val),
    );

    // cpiContext: Option<CompressedCpiContext>
    writer.writeOption(cpiContext, (val) {
      writer.writeFixedArray(val.encode());
    });

    // lamportsChangeAccountMerkleTreeIndex: Option<u8>
    writer.writeOption(
      lamportsChangeAccountMerkleTreeIndex,
      (val) => writer.writeU8(val),
    );

    return writer.toBytes();
  }
}

/// MintTo instruction data for compressed tokens.
class InstructionDataMintTo {
  final List<Ed25519HDPublicKey> recipients;
  final List<BigInt> amounts;
  final BigInt? lamports;

  const InstructionDataMintTo({
    required this.recipients,
    required this.amounts,
    this.lamports,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // recipients: Vec<Pubkey>
    final recipientsBytes = BytesBuilder();
    recipientsBytes.add(BorshWriter.u32(recipients.length));
    for (final pubkey in recipients) {
      recipientsBytes.add(pubkey.bytes);
    }
    writer.writeFixedArray(recipientsBytes.toBytes());

    // amounts: Vec<u64>
    final amountsBytes = BytesBuilder();
    amountsBytes.add(BorshWriter.u32(amounts.length));
    for (final amount in amounts) {
      amountsBytes.add(BorshWriter.u64(amount));
    }
    writer.writeFixedArray(amountsBytes.toBytes());

    // lamports: Option<u64>
    writer.writeOption(lamports, (val) => writer.writeU64(val));

    return writer.toBytes();
  }
}

/// Batch compress instruction data.
class InstructionDataBatchCompress {
  final List<Ed25519HDPublicKey> pubkeys;
  final List<BigInt>? amounts;
  final BigInt? lamports;
  final BigInt? amount;
  final int index;
  final int bump;

  const InstructionDataBatchCompress({
    required this.pubkeys,
    this.amounts,
    this.lamports,
    this.amount,
    required this.index,
    required this.bump,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // pubkeys: Vec<Pubkey>
    final pubkeysBytes = BytesBuilder();
    pubkeysBytes.add(BorshWriter.u32(pubkeys.length));
    for (final pubkey in pubkeys) {
      pubkeysBytes.add(pubkey.bytes);
    }
    writer.writeFixedArray(pubkeysBytes.toBytes());

    // amounts: Option<Vec<u64>>
    writer.writeOption(amounts, (vals) {
      final amountsBytes = BytesBuilder();
      amountsBytes.add(BorshWriter.u32(vals.length));
      for (final amt in vals) {
        amountsBytes.add(BorshWriter.u64(amt));
      }
      writer.writeFixedArray(amountsBytes.toBytes());
    });

    // lamports: Option<u64>
    writer.writeOption(lamports, (val) => writer.writeU64(val));

    // amount: Option<u64>
    writer.writeOption(amount, (val) => writer.writeU64(val));

    // index: u8
    writer.writeU8(index);

    // bump: u8
    writer.writeU8(bump);

    return writer.toBytes();
  }
}

/// Compress SPL token account instruction data.
class InstructionDataCompressSplTokenAccount {
  final Ed25519HDPublicKey owner;
  final BigInt? remainingAmount;
  final CompressedCpiContext? cpiContext;

  const InstructionDataCompressSplTokenAccount({
    required this.owner,
    this.remainingAmount,
    this.cpiContext,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // owner: Pubkey
    writer.writeFixedArray(owner.bytes);

    // remainingAmount: Option<u64>
    writer.writeOption(remainingAmount, (val) => writer.writeU64(val));

    // cpiContext: Option<CompressedCpiContext>
    writer.writeOption(cpiContext, (val) {
      writer.writeFixedArray(val.encode());
    });

    return writer.toBytes();
  }
}

/// Approve instruction data for compressed tokens.
class InstructionDataApprove {
  final CompressedProof proof;
  final Ed25519HDPublicKey mint;
  final List<InputTokenDataWithContext> inputTokenDataWithContext;
  final CompressedCpiContext? cpiContext;
  final Ed25519HDPublicKey delegate;
  final BigInt delegatedAmount;
  final int delegateMerkleTreeIndex;
  final int changeAccountMerkleTreeIndex;
  final BigInt? delegateLamports;

  const InstructionDataApprove({
    required this.proof,
    required this.mint,
    required this.inputTokenDataWithContext,
    this.cpiContext,
    required this.delegate,
    required this.delegatedAmount,
    required this.delegateMerkleTreeIndex,
    required this.changeAccountMerkleTreeIndex,
    this.delegateLamports,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // proof: CompressedProof (non-optional in approve/revoke)
    writer.writeFixedArray(proof.encode());

    // mint: [u8; 32]
    writer.writeFixedArray(mint.bytes);

    // inputTokenDataWithContext: Vec<InputTokenDataWithContext>
    final inputsBytes = BytesBuilder();
    inputsBytes.add(BorshWriter.u32(inputTokenDataWithContext.length));
    for (final item in inputTokenDataWithContext) {
      inputsBytes.add(item.encode());
    }
    writer.writeFixedArray(inputsBytes.toBytes());

    // cpiContext: Option<CompressedCpiContext>
    writer.writeOption(cpiContext, (val) {
      writer.writeFixedArray(val.encode());
    });

    // delegate: [u8; 32]
    writer.writeFixedArray(delegate.bytes);

    // delegatedAmount: u64
    writer.writeU64(delegatedAmount);

    // delegateMerkleTreeIndex: u8
    writer.writeU8(delegateMerkleTreeIndex);

    // changeAccountMerkleTreeIndex: u8
    writer.writeU8(changeAccountMerkleTreeIndex);

    // delegateLamports: Option<u64>
    writer.writeOption(delegateLamports, (val) => writer.writeU64(val));

    return writer.toBytes();
  }
}

/// Revoke instruction data for compressed tokens.
class InstructionDataRevoke {
  final CompressedProof proof;
  final Ed25519HDPublicKey mint;
  final List<InputTokenDataWithContext> inputTokenDataWithContext;
  final CompressedCpiContext? cpiContext;
  final int outputAccountMerkleTreeIndex;

  const InstructionDataRevoke({
    required this.proof,
    required this.mint,
    required this.inputTokenDataWithContext,
    this.cpiContext,
    required this.outputAccountMerkleTreeIndex,
  });

  /// Encode instruction data to Borsh bytes.
  Uint8List encode() {
    final writer = BorshWriter();

    // proof: CompressedProof (non-optional)
    writer.writeFixedArray(proof.encode());

    // mint: [u8; 32]
    writer.writeFixedArray(mint.bytes);

    // inputTokenDataWithContext: Vec<InputTokenDataWithContext>
    final inputsBytes = BytesBuilder();
    inputsBytes.add(BorshWriter.u32(inputTokenDataWithContext.length));
    for (final item in inputTokenDataWithContext) {
      inputsBytes.add(item.encode());
    }
    writer.writeFixedArray(inputsBytes.toBytes());

    // cpiContext: Option<CompressedCpiContext>
    writer.writeOption(cpiContext, (val) {
      writer.writeFixedArray(val.encode());
    });

    // outputAccountMerkleTreeIndex: u8
    writer.writeU8(outputAccountMerkleTreeIndex);

    return writer.toBytes();
  }
}
