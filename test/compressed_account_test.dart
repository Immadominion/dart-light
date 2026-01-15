import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('CompressedAccount', () {
    test('should create with required fields', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final hash = BN254.zero;
      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );

      final account = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(1000000),
        hash: hash,
        treeInfo: treeInfo,
        leafIndex: 42,
      );

      expect(account.owner, equals(owner));
      expect(account.lamports, equals(BigInt.from(1000000)));
      expect(account.leafIndex, equals(42));
      expect(account.address, isNull);
      expect(account.data, isNull);
    });

    test('should create with optional address', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final hash = BN254.zero;
      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );
      final address = List<int>.filled(32, 42);

      final account = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(1000000),
        hash: hash,
        treeInfo: treeInfo,
        leafIndex: 0,
        address: address,
      );

      expect(account.address, equals(address));
    });
  });

  group('TreeInfo', () {
    test('should create state V1 tree info', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'HMf9WvxyqRY6vqHxWNLWWU5s7Z2BgXjaDdnPT6RzMcMu',
      );

      final info = TreeInfo(
        tree: tree,
        queue: tree,
        treeType: TreeType.stateV1,
      );

      expect(info.tree, equals(tree));
      expect(info.queue, equals(tree));
      expect(info.treeType, equals(TreeType.stateV1));
      expect(info.cpiContext, isNull);
      expect(info.nextTreeInfo, isNull);
    });

    test('should create state V2 tree info with CPI context', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'HMf9WvxyqRY6vqHxWNLWWU5s7Z2BgXjaDdnPT6RzMcMu',
      );
      final cpi = Ed25519HDPublicKey.fromBase58(
        '7yucc7fL3JGbyMwg4neUaenNSdySS39hbAk89Ao3t1Hz',
      );

      final info = TreeInfo(
        tree: tree,
        queue: tree,
        treeType: TreeType.stateV2,
        cpiContext: cpi,
      );

      expect(info.treeType, equals(TreeType.stateV2));
      expect(info.cpiContext, equals(cpi));
    });

    test('should support next tree info for tree migration', () {
      final tree1 = Ed25519HDPublicKey.fromBase58(
        'HMf9WvxyqRY6vqHxWNLWWU5s7Z2BgXjaDdnPT6RzMcMu',
      );
      final tree2 = Ed25519HDPublicKey.fromBase58(
        '7yucc7fL3JGbyMwg4neUaenNSdySS39hbAk89Ao3t1Hz',
      );

      final nextInfo = TreeInfo(
        tree: tree2,
        queue: tree2,
        treeType: TreeType.stateV2,
      );

      final info = TreeInfo(
        tree: tree1,
        queue: tree1,
        treeType: TreeType.stateV1,
        nextTreeInfo: nextInfo,
      );

      expect(info.nextTreeInfo, equals(nextInfo));
      expect(info.nextTreeInfo!.treeType, equals(TreeType.stateV2));
    });
  });

  group('TreeType', () {
    test('should have all expected values', () {
      expect(TreeType.values.length, equals(4));
      expect(TreeType.values, contains(TreeType.stateV1));
      expect(TreeType.values, contains(TreeType.stateV2));
      expect(TreeType.values, contains(TreeType.addressV1));
      expect(TreeType.values, contains(TreeType.addressV2));
    });
  });
}
