import 'dart:typed_data';

import 'package:solana/solana.dart';

import '../state/validity_proof.dart';
import '../utils/borsh.dart';

/// Instruction data for the invoke instruction.
class InstructionDataInvoke {
  const InstructionDataInvoke({
    this.proof,
    required this.inputCompressedAccountsWithMerkleContext,
    required this.outputCompressedAccounts,
    this.relayFee,
    required this.newAddressParams,
    this.compressOrDecompressLamports,
    required this.isCompress,
  });

  /// Compressed ZK proof (optional for pure compress operations).
  final CompressedProof? proof;

  /// Input accounts with merkle context.
  final List<PackedCompressedAccountWithMerkleContext>
  inputCompressedAccountsWithMerkleContext;

  /// Output accounts with merkle tree index.
  final List<OutputCompressedAccountWithPackedContext> outputCompressedAccounts;

  /// Relay fee (optional).
  final BigInt? relayFee;

  /// New address parameters.
  final List<NewAddressParamsPacked> newAddressParams;

  /// Amount of lamports to compress or decompress.
  final BigInt? compressOrDecompressLamports;

  /// Whether this is a compress operation (vs decompress).
  final bool isCompress;

  /// Encode to bytes using Borsh format.
  Uint8List encode() {
    final writer = BorshWriter();

    // Proof (Option)
    writer.writeOption<CompressedProof>(proof, (p) {
      writer.writeFixedArray(p.a);
      writer.writeFixedArray(p.b);
      writer.writeFixedArray(p.c);
    });

    // Input accounts (Vec)
    writer.writeU32(inputCompressedAccountsWithMerkleContext.length);
    for (final account in inputCompressedAccountsWithMerkleContext) {
      writer.writeFixedArray(_encodePackedAccount(account));
    }

    // Output accounts (Vec)
    writer.writeU32(outputCompressedAccounts.length);
    for (final account in outputCompressedAccounts) {
      writer.writeFixedArray(_encodeOutputAccount(account));
    }

    // Relay fee (Option<u64>)
    writer.writeOption<BigInt>(relayFee, writer.writeU64);

    // New address params (Vec)
    writer.writeU32(newAddressParams.length);
    for (final params in newAddressParams) {
      writer.writeFixedArray(_encodeNewAddressParams(params));
    }

    // Compress or decompress lamports (Option<u64>)
    writer.writeOption<BigInt>(compressOrDecompressLamports, writer.writeU64);

    // Is compress (bool)
    writer.writeBool(isCompress);

    return writer.toBytes();
  }

  Uint8List _encodePackedAccount(
    PackedCompressedAccountWithMerkleContext account,
  ) {
    final writer = BorshWriter();
    writer.writeFixedArray(
      _encodeCompressedAccountCore(account.compressedAccount),
    );
    writer.writeFixedArray(_encodeMerkleContext(account.merkleContext));
    writer.writeFixedArray(BorshWriter.u16(account.rootIndex));
    writer.writeBool(account.readOnly);
    return writer.toBytes();
  }

  Uint8List _encodeOutputAccount(
    OutputCompressedAccountWithPackedContext account,
  ) {
    final writer = BorshWriter();
    writer.writeFixedArray(
      _encodeCompressedAccountCore(account.compressedAccount),
    );
    writer.writeU8(account.merkleTreeIndex);
    return writer.toBytes();
  }

  Uint8List _encodeCompressedAccountCore(CompressedAccountCore account) {
    final writer = BorshWriter();
    writer.writeFixedArray(account.owner.bytes);
    writer.writeU64(account.lamports);

    writer.writeOption<List<int>>(account.address, (addr) {
      writer.writeFixedArray(addr);
    });

    writer.writeOption<PackedCompressedAccountData>(account.data, (data) {
      writer.writeFixedArray(data.discriminator);
      writer.writeVec(data.data);
      writer.writeFixedArray(data.dataHash);
    });

    return writer.toBytes();
  }

  Uint8List _encodeMerkleContext(PackedMerkleContext context) {
    final writer = BorshWriter();
    writer.writeU8(context.merkleTreePubkeyIndex);
    writer.writeU8(context.queuePubkeyIndex);
    writer.writeU32(context.leafIndex);
    writer.writeBool(context.proveByIndex);
    return writer.toBytes();
  }

  Uint8List _encodeNewAddressParams(NewAddressParamsPacked params) {
    final writer = BorshWriter();
    writer.writeFixedArray(params.seed);
    writer.writeU8(params.addressQueueAccountIndex);
    writer.writeU8(params.addressMerkleTreeAccountIndex);
    writer.writeFixedArray(BorshWriter.u16(params.addressMerkleTreeRootIndex));
    return writer.toBytes();
  }
}

/// Core compressed account data (without merkle context).
class CompressedAccountCore {
  const CompressedAccountCore({
    required this.owner,
    required this.lamports,
    this.address,
    this.data,
  });

  /// Program owner of the account.
  final Ed25519HDPublicKey owner;

  /// Lamports in the account.
  final BigInt lamports;

  /// Optional 32-byte address (PDA).
  final List<int>? address;

  /// Optional account data.
  final PackedCompressedAccountData? data;
}

/// Packed compressed account data for instruction encoding.
class PackedCompressedAccountData {
  const PackedCompressedAccountData({
    required this.discriminator,
    required this.data,
    required this.dataHash,
  });

  /// 8-byte discriminator.
  final Uint8List discriminator;

  /// Raw data bytes.
  final Uint8List data;

  /// 32-byte hash of the data.
  final Uint8List dataHash;
}

/// Packed merkle context with index pointers.
class PackedMerkleContext {
  const PackedMerkleContext({
    required this.merkleTreePubkeyIndex,
    required this.queuePubkeyIndex,
    required this.leafIndex,
    required this.proveByIndex,
  });

  /// Index into remaining accounts for merkle tree.
  final int merkleTreePubkeyIndex;

  /// Index into remaining accounts for queue.
  final int queuePubkeyIndex;

  /// Leaf index in the tree.
  final int leafIndex;

  /// Whether to prove by index vs by hash.
  final bool proveByIndex;
}

/// Packed compressed account with merkle context for input.
class PackedCompressedAccountWithMerkleContext {
  const PackedCompressedAccountWithMerkleContext({
    required this.compressedAccount,
    required this.merkleContext,
    required this.rootIndex,
    required this.readOnly,
  });

  /// The compressed account.
  final CompressedAccountCore compressedAccount;

  /// Packed merkle context.
  final PackedMerkleContext merkleContext;

  /// Root index for validity.
  final int rootIndex;

  /// Whether account is read-only.
  final bool readOnly;
}

/// Output compressed account with packed context.
class OutputCompressedAccountWithPackedContext {
  const OutputCompressedAccountWithPackedContext({
    required this.compressedAccount,
    required this.merkleTreeIndex,
  });

  /// The compressed account.
  final CompressedAccountCore compressedAccount;

  /// Index into remaining accounts for output merkle tree.
  final int merkleTreeIndex;
}

/// Packed new address parameters.
class NewAddressParamsPacked {
  const NewAddressParamsPacked({
    required this.seed,
    required this.addressQueueAccountIndex,
    required this.addressMerkleTreeAccountIndex,
    required this.addressMerkleTreeRootIndex,
  });

  /// 32-byte seed for address derivation.
  final Uint8List seed;

  /// Index into remaining accounts for address queue.
  final int addressQueueAccountIndex;

  /// Index into remaining accounts for address merkle tree.
  final int addressMerkleTreeAccountIndex;

  /// Root index for address merkle tree.
  final int addressMerkleTreeRootIndex;
}

/// Parameters for creating a new address.
class NewAddressParams {
  const NewAddressParams({
    required this.seed,
    required this.addressQueuePubkey,
    required this.addressMerkleTreePubkey,
    required this.addressMerkleTreeRootIndex,
  });

  /// 32-byte seed for address derivation.
  final Uint8List seed;

  /// Address queue public key.
  final Ed25519HDPublicKey addressQueuePubkey;

  /// Address merkle tree public key.
  final Ed25519HDPublicKey addressMerkleTreePubkey;

  /// Root index for address merkle tree.
  final int addressMerkleTreeRootIndex;
}
