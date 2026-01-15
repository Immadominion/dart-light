import 'package:solana/solana.dart';

import '../state/bn254.dart';
import '../state/compressed_account.dart';
import '../state/token_data.dart';
import '../state/tree_info.dart';
import '../state/validity_proof.dart';
import '../token/token_types.dart';

/// Paginated response wrapper.
class WithCursor<T> {
  const WithCursor({required this.items, required this.cursor});

  final T items;
  final String? cursor;
}

/// Context wrapper for RPC responses.
class WithContext<T> {
  const WithContext({required this.context, required this.value});

  final RpcContext context;
  final T value;
}

/// RPC response context.
class RpcContext {
  const RpcContext({required this.slot});

  final int slot;

  factory RpcContext.fromJson(Map<String, dynamic> json) =>
      RpcContext(slot: json['slot'] as int);
}

/// Configuration for getCompressedAccountsByOwner.
class GetCompressedAccountsByOwnerConfig {
  const GetCompressedAccountsByOwnerConfig({
    this.filters,
    this.dataSlice,
    this.cursor,
    this.limit,
  });

  final List<MemcmpFilter>? filters;
  final DataSlice? dataSlice;
  final String? cursor;
  final int? limit;
}

/// Memcmp filter for account queries.
class MemcmpFilter {
  const MemcmpFilter({required this.offset, required this.bytes});

  final int offset;
  final String bytes;

  Map<String, dynamic> toJson() => {
    'memcmp': {'offset': offset, 'bytes': bytes},
  };
}

/// Data slice configuration.
class DataSlice {
  const DataSlice({required this.offset, required this.length});

  final int offset;
  final int length;

  Map<String, dynamic> toJson() => {'offset': offset, 'length': length};
}

/// Options for getCompressedTokenAccountsByOwner.
class GetCompressedTokenAccountsByOwnerOptions {
  const GetCompressedTokenAccountsByOwnerOptions({
    this.mint,
    this.cursor,
    this.limit,
  });

  final Ed25519HDPublicKey? mint;
  final String? cursor;
  final int? limit;
}

/// Paginated options.
class PaginatedOptions {
  const PaginatedOptions({this.cursor, this.limit});

  final String? cursor;
  final int? limit;
}

/// Signature with metadata.
class SignatureWithMetadata {
  const SignatureWithMetadata({
    required this.signature,
    required this.slot,
    required this.blockTime,
  });

  final String signature;
  final int slot;
  final int blockTime;

  factory SignatureWithMetadata.fromJson(Map<String, dynamic> json) =>
      SignatureWithMetadata(
        signature: json['signature'] as String,
        slot: json['slot'] as int,
        blockTime: json['blockTime'] as int,
      );
}

/// Hash with tree information.
class HashWithTree {
  const HashWithTree({
    required this.hash,
    required this.tree,
    required this.queue,
  });

  final BN254 hash;
  final Ed25519HDPublicKey tree;
  final Ed25519HDPublicKey queue;

  Map<String, String> toJson() => {
    'hash': hash.toBase58(),
    'tree': tree.toBase58(),
    'queue': queue.toBase58(),
  };
}

/// Hash with full tree info.
class HashWithTreeInfo {
  const HashWithTreeInfo({required this.hash, required this.stateTreeInfo});

  final BN254 hash;
  final TreeInfo stateTreeInfo;
}

/// Address with tree information.
class AddressWithTree {
  const AddressWithTree({
    required this.address,
    required this.tree,
    required this.queue,
  });

  final BN254 address;
  final Ed25519HDPublicKey tree;
  final Ed25519HDPublicKey queue;

  Map<String, String> toJson() => {
    'address': address.toBase58(),
    'tree': tree.toBase58(),
    'queue': queue.toBase58(),
  };
}

/// Address with full tree info.
class AddressWithTreeInfo {
  const AddressWithTreeInfo({
    required this.address,
    required this.addressTreeInfo,
  });

  final BN254 address;
  final TreeInfo addressTreeInfo;
}

/// Derivation mode for addresses.
enum DerivationMode { compressible, standard }

/// Latest non-voting signatures response.
class LatestNonVotingSignatures {
  const LatestNonVotingSignatures({required this.context, required this.items});

  final RpcContext context;
  final List<LatestSignatureItem> items;
}

/// Latest signature item.
class LatestSignatureItem {
  const LatestSignatureItem({
    required this.signature,
    required this.slot,
    required this.blockTime,
    this.error,
  });

  final String signature;
  final int slot;
  final int blockTime;
  final String? error;

  factory LatestSignatureItem.fromJson(Map<String, dynamic> json) =>
      LatestSignatureItem(
        signature: json['signature'] as String,
        slot: json['slot'] as int,
        blockTime: json['blockTime'] as int,
        error: json['error'] as String?,
      );
}

/// Latest non-voting signatures with pagination.
class LatestNonVotingSignaturesPaginated {
  const LatestNonVotingSignaturesPaginated({
    required this.context,
    required this.items,
    required this.cursor,
  });

  final RpcContext context;
  final List<SignatureWithMetadata> items;
  final String? cursor;
}

/// Compressed mint token holders.
class CompressedMintTokenHolders {
  const CompressedMintTokenHolders({
    required this.owner,
    required this.balance,
  });

  final Ed25519HDPublicKey owner;
  final BigInt balance;

  factory CompressedMintTokenHolders.fromJson(Map<String, dynamic> json) =>
      CompressedMintTokenHolders(
        owner: Ed25519HDPublicKey.fromBase58(json['owner'] as String),
        balance: BigInt.parse(json['balance'].toString()),
      );
}

/// Hex inputs for prover.
class HexInputsForProver {
  const HexInputsForProver({
    required this.root,
    required this.pathIndex,
    required this.pathElements,
    required this.leaf,
  });

  final String root;
  final int pathIndex;
  final List<String> pathElements;
  final String leaf;

  Map<String, dynamic> toJson() => {
    'root': root,
    'pathIndex': pathIndex,
    'pathElements': pathElements,
    'leaf': leaf,
  };
}

/// Hex batch inputs for prover.
class HexBatchInputsForProver {
  const HexBatchInputsForProver({required this.inputCompressedAccounts});

  final List<HexInputsForProver> inputCompressedAccounts;

  Map<String, dynamic> toJson() => {
    'input-compressed-accounts':
        inputCompressedAccounts.map((e) => e.toJson()).toList(),
  };
}

/// Compression API interface.
///
/// This interface defines all the methods available for querying
/// compressed account state from the Photon indexer.
abstract class CompressionApiInterface {
  /// Get a compressed account by hash or address.
  Future<CompressedAccountWithMerkleContext?> getCompressedAccount({
    BN254? address,
    BN254? hash,
  });

  /// Get compressed balance for an account.
  Future<BigInt> getCompressedBalance({BN254? address, BN254? hash});

  /// Get total compressed balance for an owner.
  Future<BigInt> getCompressedBalanceByOwner(Ed25519HDPublicKey owner);

  /// Get Merkle proof for a compressed account.
  Future<MerkleContextWithMerkleProof> getCompressedAccountProof(BN254 hash);

  /// Get multiple compressed accounts by hashes.
  Future<List<CompressedAccountWithMerkleContext>>
  getMultipleCompressedAccounts(List<BN254> hashes);

  /// Get multiple Merkle proofs.
  Future<List<MerkleContextWithMerkleProof>> getMultipleCompressedAccountProofs(
    List<BN254> hashes,
  );

  /// Get validity proof for state transition.
  Future<ValidityProofWithContext> getValidityProof({
    List<BN254>? hashes,
    List<BN254>? newAddresses,
  });

  /// Get validity proof with explicit tree info.
  Future<ValidityProofWithContext> getValidityProofV0({
    List<HashWithTree>? hashes,
    List<AddressWithTree>? newAddresses,
  });

  /// Get compressed accounts by owner.
  Future<WithCursor<List<CompressedAccountWithMerkleContext>>>
  getCompressedAccountsByOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
    List<MemcmpFilter>? filters,
  });

  /// Get compressed token accounts by owner.
  Future<WithCursor<List<ParsedTokenAccount>>>
  getCompressedTokenAccountsByOwner(
    Ed25519HDPublicKey owner, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  });

  /// Get compressed token accounts by delegate.
  Future<WithCursor<List<ParsedTokenAccount>>>
  getCompressedTokenAccountsByDelegate(
    Ed25519HDPublicKey delegate, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  });

  /// Get compressed token account balance.
  Future<BigInt> getCompressedTokenAccountBalance(BN254 hash);

  /// Get compressed token balances by owner.
  Future<WithCursor<List<TokenBalance>>> getCompressedTokenBalancesByOwner(
    Ed25519HDPublicKey owner, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  });

  /// Get transaction with compression info.
  Future<CompressedTransaction?> getTransactionWithCompressionInfo(
    String signature,
  );

  /// Get compression signatures for an account.
  Future<List<SignatureWithMetadata>> getCompressionSignaturesForAccount(
    BN254 hash,
  );

  /// Get compression signatures for an address.
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForAddress(
    Ed25519HDPublicKey address, {
    String? cursor,
    int? limit,
  });

  /// Get compression signatures for an owner.
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
  });

  /// Get compression signatures for a token owner.
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForTokenOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
  });

  /// Get indexer health status.
  Future<String> getIndexerHealth();

  /// Get current indexer slot.
  Future<int> getIndexerSlot();

  /// Wait until indexer reaches the given slot.
  Future<bool> confirmTransactionIndexed(int slot);

  /// Get compressed mint token holders (paginated).
  Future<WithContext<WithCursor<List<CompressedMintTokenHolders>>>>
  getCompressedMintTokenHolders(
    Ed25519HDPublicKey mint, {
    String? cursor,
    int? limit,
  });

  /// Get latest compression signatures (paginated).
  Future<LatestNonVotingSignaturesPaginated> getLatestCompressionSignatures({
    String? cursor,
    int? limit,
  });

  /// Get latest non-voting signatures.
  Future<LatestNonVotingSignatures> getLatestNonVotingSignatures({
    int? limit,
    String? cursor,
  });

  /// Get state tree infos.
  Future<List<TreeInfo>> getStateTreeInfos();

  /// Get V2 address tree info.
  Future<TreeInfo> getAddressTreeInfoV2();
}

/// Additional nullifier metadata for closed accounts (V2 only).
class NullifierMetadata {
  const NullifierMetadata({required this.nullifier, required this.txHash});

  final BN254 nullifier;
  final BN254 txHash;
}

/// Compressed transaction with compression info.
class CompressedTransaction {
  const CompressedTransaction({
    required this.closedAccounts,
    required this.openedAccounts,
    required this.transaction,
    this.preTokenBalances,
    this.postTokenBalances,
  });

  final List<ClosedAccountInfo> closedAccounts;
  final List<OpenedAccountInfo> openedAccounts;
  final dynamic transaction;
  final List<TokenBalanceInfo>? preTokenBalances;
  final List<TokenBalanceInfo>? postTokenBalances;
}

/// Closed account info.
class ClosedAccountInfo {
  const ClosedAccountInfo({
    required this.account,
    this.maybeTokenData,
    this.nullifierMetadata,
  });

  final CompressedAccountWithMerkleContext account;
  final TokenData? maybeTokenData;
  final NullifierMetadata? nullifierMetadata;
}

/// Opened account info.
class OpenedAccountInfo {
  const OpenedAccountInfo({required this.account, this.maybeTokenData});

  final CompressedAccountWithMerkleContext account;
  final TokenData? maybeTokenData;
}

/// Token balance info.
class TokenBalanceInfo {
  const TokenBalanceInfo({
    required this.owner,
    required this.mint,
    required this.amount,
  });

  final Ed25519HDPublicKey owner;
  final Ed25519HDPublicKey mint;
  final BigInt amount;
}
