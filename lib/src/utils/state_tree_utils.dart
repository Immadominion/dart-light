import 'dart:math' as math;

import 'package:solana/solana.dart';

import '../constants/tree_config.dart';
import '../state/tree_info.dart';

/// State tree lookup table addresses per network.
/// Format: stateTreeLookupTable (contains [tree, queue, cpiContext] triplets)
const _stateTreeLookupTableMainnet =
    '7i86eQs3GSqHjN47WdWLTCGMW6gde1q96G2EVnUyK2st';
const _stateTreeLookupTableDevnet =
    'Dk9mNkbiZXJZ4By8DfSP6HEE4ojZzRvucwpawLeuwq8q';

/// Fetch state tree infos from lookup tables.
///
/// This retrieves the current state trees from the on-chain lookup tables.
/// Tries mainnet first, then falls back to devnet.
Future<List<TreeInfo>> fetchStateTreeInfosFromLookupTables(
  RpcClient rpc,
) async {
  // Try mainnet first, then devnet
  for (final lutAddress in [
    _stateTreeLookupTableMainnet,
    _stateTreeLookupTableDevnet,
  ]) {
    try {
      final infos = await _fetchFromLookupTable(rpc, lutAddress);
      if (infos.isNotEmpty) {
        return infos;
      }
    } catch (_) {
      // Try next lookup table
    }
  }

  return [];
}

/// Fetch state tree infos from a single lookup table using proper RPC method.
Future<List<TreeInfo>> _fetchFromLookupTable(
  RpcClient rpc,
  String lutAddress,
) async {
  final lutPubkey = Ed25519HDPublicKey.fromBase58(lutAddress);

  // Use the proper getAddressLookupTable method from solana package
  final lookupTableAccount = await rpc.getAddressLookupTable(lutPubkey);
  final addresses = lookupTableAccount.state.addresses;

  if (addresses.isEmpty) return [];

  // State tree LUT contains triplets: [tree, queue, cpiContext]
  if (addresses.length % 3 != 0) {
    // Fallback: try pairs if not divisible by 3
    return _parseAsPairs(addresses);
  }

  return _parseAsTriplets(addresses);
}

/// Parse lookup table addresses as triplets [tree, queue, cpiContext].
List<TreeInfo> _parseAsTriplets(List<Ed25519HDPublicKey> addresses) {
  final infos = <TreeInfo>[];
  for (var i = 0; i + 2 < addresses.length; i += 3) {
    final tree = addresses[i];
    final queue = addresses[i + 1];
    final cpiContext = addresses[i + 2];

    // Detect tree type based on address prefix
    final treeType = _detectTreeType(tree.toBase58());

    infos.add(
      TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: cpiContext,
        treeType: treeType,
      ),
    );
  }
  return infos;
}

/// Parse lookup table addresses as pairs [tree, cpiContext] (legacy).
List<TreeInfo> _parseAsPairs(List<Ed25519HDPublicKey> addresses) {
  final infos = <TreeInfo>[];
  for (var i = 0; i + 1 < addresses.length; i += 2) {
    infos.add(
      TreeInfo(
        tree: addresses[i],
        queue: addresses[i],
        cpiContext: addresses[i + 1],
        treeType: TreeType.stateV2,
      ),
    );
  }
  return infos;
}

/// Detect tree type from address prefix.
TreeType _detectTreeType(String address) {
  if (address.startsWith('bmt')) return TreeType.stateV2;
  if (address.startsWith('smt')) return TreeType.stateV1;
  if (address.startsWith('amt')) return TreeType.addressV1;
  return TreeType.stateV2; // Default to V2
}

/// Select a random state tree info from the available ones.
TreeInfo selectStateTreeInfo(List<TreeInfo> treeInfos) {
  if (treeInfos.isEmpty) {
    throw StateError('No state trees available');
  }

  final random = math.Random();
  return treeInfos[random.nextInt(treeInfos.length)];
}

/// Select a state tree info suitable for batch operations.
TreeInfo selectStateTreeInfoForBatch(
  List<TreeInfo> treeInfos, {
  TreeType preferredType = TreeType.stateV2,
}) {
  // Prefer V2 trees for batch operations
  final v2Trees = treeInfos.where((t) => t.treeType == preferredType).toList();

  if (v2Trees.isNotEmpty) {
    return selectStateTreeInfo(v2Trees);
  }

  return selectStateTreeInfo(treeInfos);
}

/// Get info for the default address tree (V2).
TreeInfo defaultAddressTreeInfo() => TreeInfo(
  tree: DefaultTestStateTreeAccounts.batchAddressTree,
  queue: DefaultTestStateTreeAccounts.batchAddressTree,
  treeType: TreeType.addressV2,
);
