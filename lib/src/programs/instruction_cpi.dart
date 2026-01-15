import 'dart:typed_data';

import 'package:light_sdk/src/programs/account_layouts.dart'
    as layouts
    show
        NewAddressParamsPacked,
        OutputCompressedAccountWithPackedContext,
        PackedCompressedAccountWithMerkleContext;
import 'package:light_sdk/src/state/validity_proof.dart';
import 'package:light_sdk/src/utils/borsh.dart';

/// Compressed CPI context for cross-program invocations.
///
/// Use this if you want to use a single ValidityProof to update two or more
/// compressed accounts owned by separate programs. The CPI context allows
/// programs to share verification state across CPI boundaries.
class CompressedCpiContext {
  const CompressedCpiContext({
    required this.setContext,
    required this.firstSetContext,
    required this.cpiContextAccountIndex,
  });

  /// Is set by the program that is invoking the CPI to signal that it should
  /// set the cpi context.
  final bool setContext;

  /// Is set to wipe the cpi context since someone could have set it before
  /// with unrelated data.
  final bool firstSetContext;

  /// Index of cpi context account in remaining accounts.
  final int cpiContextAccountIndex;

  /// Create a CPI context for the first invocation (clears previous context).
  factory CompressedCpiContext.first() => const CompressedCpiContext(
    setContext: false,
    firstSetContext: true,
    cpiContextAccountIndex: 0,
  );

  /// Create a CPI context for subsequent invocations (reuses existing context).
  factory CompressedCpiContext.set() => const CompressedCpiContext(
    setContext: true,
    firstSetContext: false,
    cpiContextAccountIndex: 0,
  );

  /// Encode to Borsh bytes.
  Uint8List encode() {
    final writer =
        BorshWriter()
          ..writeBool(setContext)
          ..writeBool(firstSetContext)
          ..writeU8(cpiContextAccountIndex);
    return writer.toBytes();
  }
}

/// Instruction data for invoking a CPI with the Light System Program.
///
/// This instruction type is used when you need to invoke the Light System Program
/// from another program (Cross-Program Invocation). It includes an optional CPI
/// context for sharing verification state across program boundaries.
class InstructionDataInvokeCpi {
  const InstructionDataInvokeCpi({
    this.proof,
    required this.newAddressParams,
    required this.inputCompressedAccountsWithMerkleContext,
    required this.outputCompressedAccounts,
    this.relayFee,
    this.compressOrDecompressLamports,
    required this.isCompress,
    this.cpiContext,
  });

  /// Compressed ZK proof (optional for pure compress operations).
  final CompressedProof? proof;

  /// Params for creating new addresses.
  final List<layouts.NewAddressParamsPacked> newAddressParams;

  /// Input compressed accounts with merkle context.
  final List<layouts.PackedCompressedAccountWithMerkleContext>
  inputCompressedAccountsWithMerkleContext;

  /// Output compressed accounts.
  final List<layouts.OutputCompressedAccountWithPackedContext>
  outputCompressedAccounts;

  /// Relay fee. Default is null.
  final BigInt? relayFee;

  /// If some, it's either a compress or decompress instruction.
  final BigInt? compressOrDecompressLamports;

  /// If `compressOrDecompressLamports` is some, whether it's a compress or
  /// decompress instruction.
  final bool isCompress;

  /// Optional compressed CPI context for cross-program invocations.
  final CompressedCpiContext? cpiContext;

  /// Encode to bytes using Borsh format.
  ///
  /// The encoding follows the Anchor instruction format:
  /// - 8-byte discriminator (INVOKE_CPI)
  /// - 4-byte length prefix (u32 little-endian)
  /// - Borsh-encoded instruction data
  Uint8List encode() {
    final writer = BorshWriter();

    // Proof (Option<CompressedProof>)
    writer.writeOption<CompressedProof>(proof, (p) {
      writer.writeFixedArray(p.a);
      writer.writeFixedArray(p.b);
      writer.writeFixedArray(p.c);
    });

    // New address params (Vec<NewAddressParamsPacked>)
    writer.writeU32(newAddressParams.length);
    for (final params in newAddressParams) {
      writer.writeFixedArray(params.encode());
    }

    // Input accounts (Vec<PackedCompressedAccountWithMerkleContext>)
    writer.writeU32(inputCompressedAccountsWithMerkleContext.length);
    for (final account in inputCompressedAccountsWithMerkleContext) {
      writer.writeFixedArray(account.encode());
    }

    // Output accounts (Vec<OutputCompressedAccountWithPackedContext>)
    writer.writeU32(outputCompressedAccounts.length);
    for (final account in outputCompressedAccounts) {
      writer.writeFixedArray(account.encode());
    }

    // Relay fee (Option<u64>)
    writer.writeOption<BigInt>(relayFee, writer.writeU64);

    // Compress or decompress lamports (Option<u64>)
    writer.writeOption<BigInt>(compressOrDecompressLamports, writer.writeU64);

    // Is compress (bool)
    writer.writeBool(isCompress);

    // CPI context (Option<CompressedCpiContext>)
    writer.writeOption<CompressedCpiContext>(cpiContext, (ctx) {
      writer.writeFixedArray(ctx.encode());
    });

    return writer.toBytes();
  }
}
