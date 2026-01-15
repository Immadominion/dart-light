import 'dart:typed_data';

import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import '../state/compressed_account.dart';
import '../state/tree_info.dart';
import 'instruction_data.dart';

/// Convert CompressedAccountData to PackedCompressedAccountData.
PackedCompressedAccountData? _toPackedData(CompressedAccountData? data) {
  if (data == null) return null;
  return PackedCompressedAccountData(
    discriminator: Uint8List.fromList(data.discriminator),
    data: Uint8List.fromList(data.data),
    dataHash: Uint8List.fromList(data.dataHash),
  );
}

/// Finds the index of a public key in an array, or adds it if not present.
int getIndexOrAdd(List<Ed25519HDPublicKey> accounts, Ed25519HDPublicKey key) {
  final index = accounts.indexWhere((k) => k == key);
  if (index == -1) {
    accounts.add(key);
    return accounts.length - 1;
  }
  return index;
}

/// Pads output state merkle trees.
List<Ed25519HDPublicKey> padOutputStateMerkleTrees(
  Ed25519HDPublicKey merkleTree,
  int numberOfOutputAccounts,
) {
  if (numberOfOutputAccounts <= 0) {
    return [];
  }
  return List.filled(numberOfOutputAccounts, merkleTree);
}

/// Convert remaining accounts to account metas.
List<AccountMeta> toAccountMetas(List<Ed25519HDPublicKey> accounts) =>
    accounts
        .map(
          (account) => AccountMeta.writeable(pubKey: account, isSigner: false),
        )
        .toList();

/// Result of packing compressed accounts.
class PackedAccounts {
  const PackedAccounts({
    required this.packedInputCompressedAccounts,
    required this.packedOutputCompressedAccounts,
    required this.remainingAccounts,
  });

  final List<PackedCompressedAccountWithMerkleContext>
  packedInputCompressedAccounts;
  final List<OutputCompressedAccountWithPackedContext>
  packedOutputCompressedAccounts;
  final List<Ed25519HDPublicKey> remainingAccounts;
}

/// Pack compressed accounts for instruction.
///
/// Replaces PublicKey references with index pointers to remaining accounts.
PackedAccounts packCompressedAccounts({
  required List<CompressedAccountWithMerkleContext> inputCompressedAccounts,
  required List<int> inputStateRootIndices,
  required List<CompressedAccountLegacy> outputCompressedAccounts,
  TreeInfo? outputStateTreeInfo,
  List<Ed25519HDPublicKey>? existingRemainingAccounts,
}) {
  final remainingAccounts = List<Ed25519HDPublicKey>.from(
    existingRemainingAccounts ?? [],
  );

  final packedInputs = <PackedCompressedAccountWithMerkleContext>[];
  final packedOutputs = <OutputCompressedAccountWithPackedContext>[];

  // Pack input accounts
  for (var i = 0; i < inputCompressedAccounts.length; i++) {
    final account = inputCompressedAccounts[i];

    final merkleTreeIndex = getIndexOrAdd(
      remainingAccounts,
      account.treeInfo.tree,
    );

    final queueIndex = getIndexOrAdd(remainingAccounts, account.treeInfo.queue);

    packedInputs.add(
      PackedCompressedAccountWithMerkleContext(
        compressedAccount: CompressedAccountCore(
          owner: account.owner,
          lamports: account.lamports,
          address: account.address,
          data: _toPackedData(account.data),
        ),
        merkleContext: PackedMerkleContext(
          merkleTreePubkeyIndex: merkleTreeIndex,
          queuePubkeyIndex: queueIndex,
          leafIndex: account.leafIndex,
          proveByIndex: account.proveByIndex,
        ),
        rootIndex: inputStateRootIndices[i],
        readOnly: false,
      ),
    );
  }

  // Validate
  if (inputCompressedAccounts.isNotEmpty && outputStateTreeInfo != null) {
    throw ArgumentError(
      'Cannot specify both input accounts and outputStateTreeInfo',
    );
  }

  // Determine tree info for output
  final TreeInfo treeInfo;
  if (inputCompressedAccounts.isNotEmpty) {
    treeInfo = inputCompressedAccounts.first.treeInfo;
  } else if (outputStateTreeInfo != null) {
    treeInfo = outputStateTreeInfo;
  } else {
    throw ArgumentError(
      'Neither input accounts nor outputStateTreeInfo are available',
    );
  }

  // Use next tree if available, otherwise fall back to current tree.
  final activeTreeInfo = treeInfo.nextTreeInfo ?? treeInfo;
  final Ed25519HDPublicKey activeTreeOrQueue;

  if (activeTreeInfo.treeType == TreeType.stateV2) {
    activeTreeOrQueue = activeTreeInfo.queue;
  } else {
    activeTreeOrQueue = activeTreeInfo.tree;
  }

  // Pack output accounts
  final paddedOutputTrees = padOutputStateMerkleTrees(
    activeTreeOrQueue,
    outputCompressedAccounts.length,
  );

  for (var i = 0; i < outputCompressedAccounts.length; i++) {
    final account = outputCompressedAccounts[i];
    final merkleTreeIndex = getIndexOrAdd(
      remainingAccounts,
      paddedOutputTrees[i],
    );

    packedOutputs.add(
      OutputCompressedAccountWithPackedContext(
        compressedAccount: CompressedAccountCore(
          owner: account.owner,
          lamports: account.lamports,
          address: account.address,
          data: account.data,
        ),
        merkleTreeIndex: merkleTreeIndex,
      ),
    );
  }

  return PackedAccounts(
    packedInputCompressedAccounts: packedInputs,
    packedOutputCompressedAccounts: packedOutputs,
    remainingAccounts: remainingAccounts,
  );
}

/// Pack new address params.
class PackedNewAddressParams {
  const PackedNewAddressParams({
    required this.newAddressParamsPacked,
    required this.remainingAccounts,
  });

  final List<NewAddressParamsPacked> newAddressParamsPacked;
  final List<Ed25519HDPublicKey> remainingAccounts;
}

/// Pack new address parameters for instruction.
PackedNewAddressParams packNewAddressParams(
  List<NewAddressParams> newAddressParams,
  List<Ed25519HDPublicKey> existingRemainingAccounts,
) {
  final remainingAccounts = List<Ed25519HDPublicKey>.from(
    existingRemainingAccounts,
  );

  final packed =
      newAddressParams.map((params) {
        final queueIndex = getIndexOrAdd(
          remainingAccounts,
          params.addressQueuePubkey,
        );
        final treeIndex = getIndexOrAdd(
          remainingAccounts,
          params.addressMerkleTreePubkey,
        );

        return NewAddressParamsPacked(
          seed: params.seed,
          addressQueueAccountIndex: queueIndex,
          addressMerkleTreeAccountIndex: treeIndex,
          addressMerkleTreeRootIndex: params.addressMerkleTreeRootIndex,
        );
      }).toList();

  return PackedNewAddressParams(
    newAddressParamsPacked: packed,
    remainingAccounts: remainingAccounts,
  );
}

/// Legacy compressed account (for output creation).
class CompressedAccountLegacy {
  const CompressedAccountLegacy({
    required this.owner,
    required this.lamports,
    this.address,
    this.data,
  });

  /// Create a simple compressed account.
  factory CompressedAccountLegacy.create(
    Ed25519HDPublicKey owner,
    BigInt lamports, {
    PackedCompressedAccountData? data,
    List<int>? address,
  }) => CompressedAccountLegacy(
    owner: owner,
    lamports: lamports,
    address: address,
    data: data,
  );

  /// Program owner.
  final Ed25519HDPublicKey owner;

  /// Lamports balance.
  final BigInt lamports;

  /// Optional 32-byte PDA address.
  final List<int>? address;

  /// Optional account data.
  final PackedCompressedAccountData? data;
}
