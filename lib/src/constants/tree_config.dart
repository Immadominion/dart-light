import 'package:solana/solana.dart';

import '../state/tree_info.dart';
import 'program_ids.dart';

/// Default Merkle tree height for state trees.
const int defaultMerkleTreeHeight = 26;

/// Default Merkle tree height for V2 state trees.
const int defaultMerkleTreeHeightV2 = 32;

/// Default Merkle tree roots.
const int defaultMerkleTreeRoots = 2800;

/// Default address tree height.
const int defaultAddressTreeHeight = 26;

/// Default address tree height for V2.
const int defaultAddressTreeHeightV2 = 40;

/// V1 State Tree Accounts (Localnet/Devnet).
class V1StateTreeAccounts {
  V1StateTreeAccounts._();

  /// State tree 1.
  static final merkleTree1 = Ed25519HDPublicKey.fromBase58(
    'smt1NamzXdq4AMqS2fS2F1i5KTYPZRhoHgWx38d8WsT',
  );

  static final nullifierQueue1 = Ed25519HDPublicKey.fromBase58(
    'nfq1NvQDJ2GEgnS8zt9prAe8rjjpAW1zFkrvZoBR148',
  );

  static final cpiContext1 = Ed25519HDPublicKey.fromBase58(
    'cpi1uHzrEhBG733DoEJNgHCyRS3XmmyVNZx5fonubE4',
  );

  /// State tree 2.
  static final merkleTree2 = Ed25519HDPublicKey.fromBase58(
    'smt2rJAFdyJJupwMKAqTNAJwvjhmiZ4JYGZmbVRw1Ho',
  );

  static final nullifierQueue2 = Ed25519HDPublicKey.fromBase58(
    'nfq2hgS7NYemXsFaFUCe3EMXSDSfnZnAe27jC6aPP1X',
  );

  static final cpiContext2 = Ed25519HDPublicKey.fromBase58(
    'cpi2cdhkH5roePvcudTgUL8ppEBfTay1desGh8G8QxK',
  );

  /// V1 Address tree.
  static final addressTree = Ed25519HDPublicKey.fromBase58(
    'amt1Ayt45jfbdw5YSo7iz6WZxUmnZsQTYXy82hVwyC2',
  );

  static final addressQueue = Ed25519HDPublicKey.fromBase58(
    'aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F',
  );
}

/// V2 Batch State Tree Accounts (Localnet/Devnet).
class V2BatchTreeAccounts {
  V2BatchTreeAccounts._();

  /// Batch state tree 1.
  static final batchMerkleTree1 = Ed25519HDPublicKey.fromBase58(
    'bmt1LryLZUMmF7ZtqESaw7wifBXLfXHQYoE4GAmrahU',
  );

  static final batchQueue1 = Ed25519HDPublicKey.fromBase58(
    'oq1na8gojfdUhsfCpyjNt6h4JaDWtHf1yQj4koBWfto',
  );

  static final batchCpiContext1 = Ed25519HDPublicKey.fromBase58(
    'cpi15BoVPKgEPw5o8wc2T816GE7b378nMXnhH3Xbq4y',
  );

  /// Batch state tree 2.
  static final batchMerkleTree2 = Ed25519HDPublicKey.fromBase58(
    'bmt2UxoBxB9xWev4BkLvkGdapsz6sZGkzViPNph7VFi',
  );

  static final batchQueue2 = Ed25519HDPublicKey.fromBase58(
    'oq2UkeMsJLfXt2QHzim242SUi3nvjJs8Pn7Eac9H9vg',
  );

  static final batchCpiContext2 = Ed25519HDPublicKey.fromBase58(
    'cpi2yGapXUR3As5SjnHBAVvmApNiLsbeZpF3euWnW6B',
  );

  /// Batch state tree 3.
  static final batchMerkleTree3 = Ed25519HDPublicKey.fromBase58(
    'bmt3ccLd4bqSVZVeCJnH1F6C8jNygAhaDfxDwePyyGb',
  );

  static final batchQueue3 = Ed25519HDPublicKey.fromBase58(
    'oq3AxjekBWgo64gpauB6QtuZNesuv19xrhaC1ZM1THQ',
  );

  static final batchCpiContext3 = Ed25519HDPublicKey.fromBase58(
    'cpi3mbwMpSX8FAGMZVP85AwxqCaQMfEk9Em1v8QK9Rf',
  );

  /// Batch state tree 4.
  static final batchMerkleTree4 = Ed25519HDPublicKey.fromBase58(
    'bmt4d3p1a4YQgk9PeZv5s4DBUmbF5NxqYpk9HGjQsd8',
  );

  static final batchQueue4 = Ed25519HDPublicKey.fromBase58(
    'oq4ypwvVGzCUMoiKKHWh4S1SgZJ9vCvKpcz6RT6A8dq',
  );

  static final batchCpiContext4 = Ed25519HDPublicKey.fromBase58(
    'cpi4yyPDc4bCgHAnsenunGA8Y77j3XEDyjgfyCKgcoc',
  );

  /// Batch state tree 5.
  static final batchMerkleTree5 = Ed25519HDPublicKey.fromBase58(
    'bmt5yU97jC88YXTuSukYHa8Z5Bi2ZDUtmzfkDTA2mG2',
  );

  static final batchQueue5 = Ed25519HDPublicKey.fromBase58(
    'oq5oh5ZR3yGomuQgFduNDzjtGvVWfDRGLuDVjv9a96P',
  );

  static final batchCpiContext5 = Ed25519HDPublicKey.fromBase58(
    'cpi5ZTjdgYpZ1Xr7B1cMLLUE81oTtJbNNAyKary2nV6',
  );

  /// V2 Address tree (batch).
  static final batchAddressTree = Ed25519HDPublicKey.fromBase58(
    'amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx',
  );
}

/// Localnet/Devnet default state tree accounts.
/// @deprecated Use V1StateTreeAccounts and V2BatchTreeAccounts instead.
class DefaultTestStateTreeAccounts {
  DefaultTestStateTreeAccounts._();

  /// Default nullifier queue.
  static final nullifierQueue = V1StateTreeAccounts.nullifierQueue1;

  /// Default Merkle tree.
  static final merkleTree = V1StateTreeAccounts.merkleTree1;

  /// Default address tree (V1).
  static final addressTree = V1StateTreeAccounts.addressTree;

  /// Default address queue.
  static final addressQueue = V1StateTreeAccounts.addressQueue;

  /// Default batch state tree (V2).
  static final batchStateTree = V2BatchTreeAccounts.batchMerkleTree1;

  /// Default batch address tree (V2).
  static final batchAddressTree = V2BatchTreeAccounts.batchAddressTree;
}

/// Get all local test state tree infos.
///
/// V1: 2 state trees (smt/nfq/cpi pairs)
/// V2: 5 batched state trees (bmt/oq/cpi triplets) + 1 address tree (amt2)
List<TreeInfo> localTestActiveStateTreeInfos() {
  // V1 State Trees
  final v1Trees = [
    TreeInfo(
      tree: V1StateTreeAccounts.merkleTree1,
      queue: V1StateTreeAccounts.nullifierQueue1,
      cpiContext: V1StateTreeAccounts.cpiContext1,
      treeType: TreeType.stateV1,
    ),
    TreeInfo(
      tree: V1StateTreeAccounts.merkleTree2,
      queue: V1StateTreeAccounts.nullifierQueue2,
      cpiContext: V1StateTreeAccounts.cpiContext2,
      treeType: TreeType.stateV1,
    ),
  ];

  // V2 State Trees (batched)
  final v2Trees = [
    TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree1,
      queue: V2BatchTreeAccounts.batchQueue1,
      cpiContext: V2BatchTreeAccounts.batchCpiContext1,
      treeType: TreeType.stateV2,
    ),
    TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree2,
      queue: V2BatchTreeAccounts.batchQueue2,
      cpiContext: V2BatchTreeAccounts.batchCpiContext2,
      treeType: TreeType.stateV2,
    ),
    TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree3,
      queue: V2BatchTreeAccounts.batchQueue3,
      cpiContext: V2BatchTreeAccounts.batchCpiContext3,
      treeType: TreeType.stateV2,
    ),
    TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree4,
      queue: V2BatchTreeAccounts.batchQueue4,
      cpiContext: V2BatchTreeAccounts.batchCpiContext4,
      treeType: TreeType.stateV2,
    ),
    TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree5,
      queue: V2BatchTreeAccounts.batchQueue5,
      cpiContext: V2BatchTreeAccounts.batchCpiContext5,
      treeType: TreeType.stateV2,
    ),
  ];

  // V2 Address Tree
  final v2AddressTree = TreeInfo(
    tree: V2BatchTreeAccounts.batchAddressTree,
    queue: V2BatchTreeAccounts.batchAddressTree, // queue is part of the tree
    treeType: TreeType.addressV2,
  );

  if (LightFeatureFlags.isV2) {
    return [...v1Trees, ...v2Trees, v2AddressTree];
  }
  return v1Trees;
}

/// Get default test state tree info for localnet.
TreeInfo defaultTestStateTreeInfo() {
  if (LightFeatureFlags.isV2) {
    return TreeInfo(
      tree: V2BatchTreeAccounts.batchMerkleTree1,
      queue: V2BatchTreeAccounts.batchQueue1,
      cpiContext: V2BatchTreeAccounts.batchCpiContext1,
      treeType: TreeType.stateV2,
    );
  }
  return TreeInfo(
    tree: V1StateTreeAccounts.merkleTree1,
    queue: V1StateTreeAccounts.nullifierQueue1,
    cpiContext: V1StateTreeAccounts.cpiContext1,
    treeType: TreeType.stateV1,
  );
}

/// Get default test address tree info for localnet.
TreeInfo defaultTestAddressTreeInfo() {
  if (LightFeatureFlags.isV2) {
    return TreeInfo(
      tree: V2BatchTreeAccounts.batchAddressTree,
      queue: V2BatchTreeAccounts.batchAddressTree,
      treeType: TreeType.addressV2,
    );
  }
  return TreeInfo(
    tree: V1StateTreeAccounts.addressTree,
    queue: V1StateTreeAccounts.addressQueue,
    treeType: TreeType.addressV1,
  );
}

/// Get default batch state tree info for V2.
TreeInfo defaultBatchStateTreeInfo() => TreeInfo(
  tree: V2BatchTreeAccounts.batchMerkleTree1,
  queue: V2BatchTreeAccounts.batchQueue1,
  cpiContext: V2BatchTreeAccounts.batchCpiContext1,
  treeType: TreeType.stateV2,
);

/// Get default batch address tree info for V2.
TreeInfo defaultBatchAddressTreeInfo() => TreeInfo(
  tree: V2BatchTreeAccounts.batchAddressTree,
  queue: V2BatchTreeAccounts.batchAddressTree,
  treeType: TreeType.addressV2,
);

/// State tree lookup table addresses.
class StateTreeLookupTables {
  StateTreeLookupTables._();

  /// Mainnet state tree lookup table.
  static final mainnetStateTree = Ed25519HDPublicKey.fromBase58(
    '7i86eQs3GSqHjN47WdWLTCGMW6gde1q96G2EVnUyK2st',
  );

  /// Mainnet nullified state tree lookup table.
  static final mainnetNullifiedStateTree = Ed25519HDPublicKey.fromBase58(
    'H9QD4u1fG7KmkAzn2tDXhheushxFe1EcrjGGyEFXeMqT',
  );

  /// Devnet state tree lookup table.
  static final devnetStateTree = Ed25519HDPublicKey.fromBase58(
    'Dk9mNkbiZXJZ4By8DfSP6HEE4ojZzRvucwpawLeuwq8q',
  );

  /// Devnet nullified state tree lookup table.
  static final devnetNullifiedStateTree = Ed25519HDPublicKey.fromBase58(
    'AXbHzp1NgjLvpfnD6JRTTovXZ7APUCdtWZFCRr5tCxse',
  );
}

/// State tree lookup table pair.
class StateTreeLutPair {
  const StateTreeLutPair({
    required this.stateTreeLookupTable,
    required this.nullifyLookupTable,
  });

  final Ed25519HDPublicKey stateTreeLookupTable;
  final Ed25519HDPublicKey nullifyLookupTable;
}

/// Get default state tree lookup tables for networks.
Map<String, List<StateTreeLutPair>> defaultStateTreeLookupTables() {
  return {
    'mainnet': [
      StateTreeLutPair(
        stateTreeLookupTable: StateTreeLookupTables.mainnetStateTree,
        nullifyLookupTable: StateTreeLookupTables.mainnetNullifiedStateTree,
      ),
    ],
    'devnet': [
      StateTreeLutPair(
        stateTreeLookupTable: StateTreeLookupTables.devnetStateTree,
        nullifyLookupTable: StateTreeLookupTables.devnetNullifiedStateTree,
      ),
    ],
  };
}

/// Check if a URL is for local testing.
bool isLocalTest(String url) =>
    url.contains('localhost') || url.contains('127.0.0.1');

/// Network endpoints.
class LightEndpoints {
  LightEndpoints._();

  /// Local validator endpoint.
  static const localnet = 'http://localhost:8899';

  /// Devnet endpoint.
  static const devnet = 'https://api.devnet.solana.com';

  /// Mainnet endpoint.
  static const mainnet = 'https://api.mainnet-beta.solana.com';

  /// Default Photon API endpoint for devnet.
  static const photonDevnet = 'https://devnet.helius-rpc.com';

  /// Default Photon API endpoint for mainnet.
  static const photonMainnet = 'https://mainnet.helius-rpc.com';
}
