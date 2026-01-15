import 'package:solana/solana.dart';

import '../state/bn254.dart';
import '../state/compressed_account.dart';
import '../state/token_data.dart';
import '../state/tree_info.dart';

/// A compressed token account with parsed data.
///
/// This represents a compressed token account as returned by the
/// `getCompressedTokenAccountsByOwner` RPC method.
class ParsedTokenAccount {
  const ParsedTokenAccount({
    required this.compressedAccount,
    required this.parsed,
  });

  /// The underlying compressed account.
  final CompressedAccountWithMerkleContext compressedAccount;

  /// Parsed token data.
  final TokenData parsed;

  /// Get the account hash as BN254 (for use with getValidityProof).
  BN254 get hash => compressedAccount.hash;

  /// Get the leaf index.
  int get leafIndex => compressedAccount.leafIndex;

  /// Get the tree info.
  TreeInfo get treeInfo => compressedAccount.treeInfo;

  /// Whether this account can be proven by index (batch trees).
  bool get proveByIndex => compressedAccount.proveByIndex;
}

/// Parameters for compressing SPL tokens.
class CompressTokenParams {
  const CompressTokenParams({
    required this.payer,
    required this.owner,
    required this.source,
    required this.toAddress,
    required this.amount,
    required this.mint,
    required this.outputStateTreeInfo,
    required this.tokenPoolInfo,
  });

  /// Fee payer.
  final Ed25519HDPublicKey payer;

  /// Owner of uncompressed token account.
  final Ed25519HDPublicKey owner;

  /// Source SPL Token account address.
  final Ed25519HDPublicKey source;

  /// Recipient address(es).
  final List<Ed25519HDPublicKey> toAddress;

  /// Token amount(s) to compress.
  final List<BigInt> amount;

  /// SPL Token mint address.
  final Ed25519HDPublicKey mint;

  /// State tree to write to.
  final TreeInfo outputStateTreeInfo;

  /// Token pool info.
  final TokenPoolInfo tokenPoolInfo;
}

/// Parameters for decompressing tokens.
class DecompressTokenParams {
  const DecompressTokenParams({
    required this.payer,
    required this.inputCompressedTokenAccounts,
    required this.toAddress,
    required this.amount,
    required this.recentValidityProof,
    required this.recentInputStateRootIndices,
    required this.tokenPoolInfos,
  });

  /// Fee payer.
  final Ed25519HDPublicKey payer;

  /// Source compressed token accounts.
  final List<ParsedTokenAccount> inputCompressedTokenAccounts;

  /// Destination uncompressed token account.
  final Ed25519HDPublicKey toAddress;

  /// Token amount to decompress.
  final BigInt amount;

  /// Validity proof for input state.
  final dynamic recentValidityProof;

  /// Recent state root indices.
  final List<int> recentInputStateRootIndices;

  /// Token pool info(s).
  final List<TokenPoolInfo> tokenPoolInfos;
}

/// Parameters for transferring compressed tokens.
class TransferTokenParams {
  const TransferTokenParams({
    required this.payer,
    required this.inputCompressedTokenAccounts,
    required this.toAddress,
    required this.amount,
    required this.recentValidityProof,
    required this.recentInputStateRootIndices,
  });

  /// Fee payer.
  final Ed25519HDPublicKey payer;

  /// Source compressed token accounts.
  final List<ParsedTokenAccount> inputCompressedTokenAccounts;

  /// Recipient address.
  final Ed25519HDPublicKey toAddress;

  /// Token amount to transfer.
  final BigInt amount;

  /// Validity proof for input state.
  final dynamic recentValidityProof;

  /// Recent state root indices.
  final List<int> recentInputStateRootIndices;
}

/// Parameters for minting compressed tokens.
class MintToParams {
  const MintToParams({
    required this.feePayer,
    required this.mint,
    required this.authority,
    required this.toPubkey,
    required this.amount,
    required this.outputStateTreeInfo,
    required this.tokenPoolInfo,
  });

  /// Fee payer.
  final Ed25519HDPublicKey feePayer;

  /// Token mint address.
  final Ed25519HDPublicKey mint;

  /// Mint authority.
  final Ed25519HDPublicKey authority;

  /// Recipient address(es).
  final List<Ed25519HDPublicKey> toPubkey;

  /// Token amount(s) to mint.
  final List<BigInt> amount;

  /// State tree for minted tokens.
  final TreeInfo outputStateTreeInfo;

  /// Token pool info.
  final TokenPoolInfo tokenPoolInfo;
}

/// Parameters for approving a delegate.
class ApproveParams {
  const ApproveParams({
    required this.payer,
    required this.inputCompressedTokenAccounts,
    required this.delegate,
    required this.amount,
    required this.recentValidityProof,
    required this.recentInputStateRootIndices,
  });

  /// Fee payer.
  final Ed25519HDPublicKey payer;

  /// Source compressed token accounts.
  final List<ParsedTokenAccount> inputCompressedTokenAccounts;

  /// Delegate address.
  final Ed25519HDPublicKey delegate;

  /// Token amount to approve.
  final BigInt amount;

  /// Validity proof for input state.
  final dynamic recentValidityProof;

  /// Recent state root indices.
  final List<int> recentInputStateRootIndices;
}

/// Parameters for revoking a delegate.
class RevokeParams {
  const RevokeParams({
    required this.payer,
    required this.inputCompressedTokenAccounts,
    required this.recentValidityProof,
    required this.recentInputStateRootIndices,
  });

  /// Fee payer.
  final Ed25519HDPublicKey payer;

  /// Input compressed token accounts.
  final List<ParsedTokenAccount> inputCompressedTokenAccounts;

  /// Validity proof for input state.
  final dynamic recentValidityProof;

  /// Recent state root indices.
  final List<int> recentInputStateRootIndices;
}

/// Parameters for creating a token pool (SPL interface).
class CreateSplInterfaceParams {
  const CreateSplInterfaceParams({
    required this.feePayer,
    required this.mint,
    this.tokenProgramId,
  });

  /// Fee payer.
  final Ed25519HDPublicKey feePayer;

  /// SPL Mint address.
  final Ed25519HDPublicKey mint;

  /// Token program ID (defaults to SPL Token Program).
  final Ed25519HDPublicKey? tokenProgramId;
}

/// Token pool info.
class TokenPoolInfo {
  const TokenPoolInfo({
    required this.splInterfacePda,
    required this.mint,
    this.tokenProgramId,
    this.isSplInterface = true,
  });

  /// SPL interface PDA address.
  final Ed25519HDPublicKey splInterfacePda;

  /// Mint address.
  final Ed25519HDPublicKey mint;

  /// Token program ID.
  final Ed25519HDPublicKey? tokenProgramId;

  /// Whether this is an SPL interface (vs legacy token pool).
  final bool isSplInterface;
}

/// Token transfer output data.
class TokenTransferOutputData {
  const TokenTransferOutputData({
    required this.owner,
    required this.amount,
    this.lamports,
    this.merkleTreeIndex,
    this.delegate,
  });

  /// Output owner.
  final Ed25519HDPublicKey owner;

  /// Token amount.
  final BigInt amount;

  /// Optional lamports.
  final BigInt? lamports;

  /// Merkle tree index in remaining accounts.
  final int? merkleTreeIndex;

  /// Optional delegate for approval.
  final Ed25519HDPublicKey? delegate;
}
