import 'dart:typed_data';

import 'package:light_sdk/src/programs/instruction_data.dart';
import 'package:light_sdk/src/programs/pack.dart';
import 'package:light_sdk/src/state/state.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

// Helper to generate test public keys
Ed25519HDPublicKey _testKey(int seed) {
  final bytes = Uint8List(32);
  bytes[0] = seed;
  return Ed25519HDPublicKey(bytes);
}

void main() {
  group('getIndexOrAdd', () {
    test('adds new account and returns index', () {
      final accounts = <Ed25519HDPublicKey>[];
      final key = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final index = getIndexOrAdd(accounts, key);

      expect(index, 0);
      expect(accounts.length, 1);
      expect(accounts[0], key);
    });

    test('returns existing index for duplicate', () {
      final key1 = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final key2 = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final accounts = <Ed25519HDPublicKey>[key1];

      // Adding same key should return 0
      final index1 = getIndexOrAdd(accounts, key1);
      expect(index1, 0);
      expect(accounts.length, 1);

      // Adding new key should return 1
      final index2 = getIndexOrAdd(accounts, key2);
      expect(index2, 1);
      expect(accounts.length, 2);

      // Adding first key again should still return 0
      final index3 = getIndexOrAdd(accounts, key1);
      expect(index3, 0);
      expect(accounts.length, 2);
    });

    test('handles multiple unique accounts', () {
      final accounts = <Ed25519HDPublicKey>[];
      final keys = List.generate(5, _testKey);

      for (var i = 0; i < keys.length; i++) {
        final index = getIndexOrAdd(accounts, keys[i]);
        expect(index, i);
      }

      expect(accounts.length, 5);
    });
  });

  group('padOutputStateMerkleTrees', () {
    test('returns empty list for zero count', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final result = padOutputStateMerkleTrees(tree, 0);

      expect(result, isEmpty);
    });

    test('returns empty list for negative count', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final result = padOutputStateMerkleTrees(tree, -5);

      expect(result, isEmpty);
    });

    test('pads single output', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final result = padOutputStateMerkleTrees(tree, 1);

      expect(result.length, 1);
      expect(result[0], tree);
    });

    test('pads multiple outputs with same tree', () {
      final tree = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final result = padOutputStateMerkleTrees(tree, 5);

      expect(result.length, 5);
      for (final t in result) {
        expect(t, tree);
      }
    });
  });

  group('toAccountMetas', () {
    test('converts empty list', () {
      final accounts = <Ed25519HDPublicKey>[];

      final metas = toAccountMetas(accounts);

      expect(metas, isEmpty);
    });

    test('converts single account', () {
      final key = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final accounts = [key];

      final metas = toAccountMetas(accounts);

      expect(metas.length, 1);
      expect(metas[0].pubKey, key);
      expect(metas[0].isWriteable, isTrue);
      expect(metas[0].isSigner, isFalse);
    });

    test('converts multiple accounts', () {
      final keys = List.generate(3, _testKey);

      final metas = toAccountMetas(keys);

      expect(metas.length, 3);
      for (var i = 0; i < metas.length; i++) {
        expect(metas[i].pubKey, keys[i]);
        expect(metas[i].isWriteable, isTrue);
        expect(metas[i].isSigner, isFalse);
      }
    });
  });

  group('packCompressedAccounts', () {
    test('packs single input account', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
      );

      final inputAccount = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(1000000),
        hash: BN254.fromBigInt(BigInt.from(123)),
        treeInfo: treeInfo,
        leafIndex: 10,
        proveByIndex: true,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [inputAccount],
        inputStateRootIndices: [5],
        outputCompressedAccounts: [],
        existingRemainingAccounts: [],
      );

      expect(result.packedInputCompressedAccounts.length, 1);
      expect(result.packedOutputCompressedAccounts.length, 0);
      expect(result.remainingAccounts.length, 2); // tree + queue

      final packedInput = result.packedInputCompressedAccounts[0];
      expect(packedInput.compressedAccount.owner, owner);
      expect(packedInput.compressedAccount.lamports, BigInt.from(1000000));
      expect(packedInput.merkleContext.merkleTreePubkeyIndex, 0);
      expect(packedInput.merkleContext.queuePubkeyIndex, 1);
      expect(packedInput.merkleContext.leafIndex, 10);
      expect(packedInput.merkleContext.proveByIndex, true);
      expect(packedInput.rootIndex, 5);
      expect(packedInput.readOnly, false);
    });

    test('packs single output account with outputStateTreeInfo', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
      );

      final outputAccount = CompressedAccountLegacy(
        owner: owner,
        lamports: BigInt.from(500000),
        address: null,
        data: null,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [],
        inputStateRootIndices: [],
        outputCompressedAccounts: [outputAccount],
        outputStateTreeInfo: treeInfo,
        existingRemainingAccounts: [],
      );

      expect(result.packedInputCompressedAccounts.length, 0);
      expect(result.packedOutputCompressedAccounts.length, 1);
      expect(result.remainingAccounts.length, 1); // just tree for V1

      final packedOutput = result.packedOutputCompressedAccounts[0];
      expect(packedOutput.compressedAccount.owner, owner);
      expect(packedOutput.compressedAccount.lamports, BigInt.from(500000));
      expect(packedOutput.merkleTreeIndex, 0);
    });

    test('packs input and output accounts together', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
      );

      final inputAccount = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(2000000),
        hash: BN254.fromBigInt(BigInt.from(456)),
        treeInfo: treeInfo,
        leafIndex: 20,
        proveByIndex: false,
      );

      final outputAccount = CompressedAccountLegacy(
        owner: owner,
        lamports: BigInt.from(1500000),
        address: null,
        data: null,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [inputAccount],
        inputStateRootIndices: [10],
        outputCompressedAccounts: [outputAccount],
        existingRemainingAccounts: [],
      );

      expect(result.packedInputCompressedAccounts.length, 1);
      expect(result.packedOutputCompressedAccounts.length, 1);
      // tree + queue for input, same tree reused for output
      expect(result.remainingAccounts.length, 2);

      final packedInput = result.packedInputCompressedAccounts[0];
      expect(packedInput.compressedAccount.lamports, BigInt.from(2000000));
      expect(packedInput.merkleContext.leafIndex, 20);
      expect(packedInput.merkleContext.proveByIndex, false);

      final packedOutput = result.packedOutputCompressedAccounts[0];
      expect(packedOutput.compressedAccount.lamports, BigInt.from(1500000));
      expect(packedOutput.merkleTreeIndex, 0); // reused tree index
    });

    test('uses V2 queue for StateV2 trees', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV2, // V2 type
      );

      final outputAccount = CompressedAccountLegacy(
        owner: owner,
        lamports: BigInt.from(500000),
        address: null,
        data: null,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [],
        inputStateRootIndices: [],
        outputCompressedAccounts: [outputAccount],
        outputStateTreeInfo: treeInfo,
        existingRemainingAccounts: [],
      );

      expect(result.remainingAccounts.length, 1);
      // For V2, should use queue instead of tree
      expect(result.remainingAccounts[0], queue);
    });

    test('uses nextTreeInfo when available', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree1 = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue1 = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final tree2 = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111112',
      );
      final queue2 = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111113',
      );

      final nextTreeInfo = TreeInfo(
        tree: tree2,
        queue: queue2,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV1,
      );

      final treeInfo = TreeInfo(
        tree: tree1,
        queue: queue1,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
        nextTreeInfo: nextTreeInfo,
      );

      final outputAccount = CompressedAccountLegacy(
        owner: owner,
        lamports: BigInt.from(500000),
        address: null,
        data: null,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [],
        inputStateRootIndices: [],
        outputCompressedAccounts: [outputAccount],
        outputStateTreeInfo: treeInfo,
        existingRemainingAccounts: [],
      );

      expect(result.remainingAccounts.length, 1);
      // Should use next tree, not current tree
      expect(result.remainingAccounts[0], tree2);
    });

    test('reuses existing remaining accounts', () {
      final existingKey = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = existingKey; // Reuse existing key
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
      );

      final outputAccount = CompressedAccountLegacy(
        owner: owner,
        lamports: BigInt.from(500000),
        address: null,
        data: null,
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [],
        inputStateRootIndices: [],
        outputCompressedAccounts: [outputAccount],
        outputStateTreeInfo: treeInfo,
        existingRemainingAccounts: [existingKey],
      );

      // Should reuse existing key, so only 1 account total
      expect(result.remainingAccounts.length, 1);
      expect(result.remainingAccounts[0], existingKey);
    });

    test(
      'throws when both input accounts and outputStateTreeInfo provided',
      () {
        final owner = Ed25519HDPublicKey.fromBase58(
          'BPFLoaderUpgradeab1e11111111111111111111111',
        );
        final tree = Ed25519HDPublicKey.fromBase58(
          'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
        );
        final queue = Ed25519HDPublicKey.fromBase58(
          'So11111111111111111111111111111111111111112',
        );

        final treeInfo = TreeInfo(
          tree: tree,
          queue: queue,
          cpiContext: Ed25519HDPublicKey.fromBase58(
            '11111111111111111111111111111111',
          ),
          treeType: TreeType.stateV1,
        );

        final inputAccount = CompressedAccount(
          owner: owner,
          lamports: BigInt.from(1000000),
          hash: BN254.fromBigInt(BigInt.from(789)),
          treeInfo: treeInfo,
          leafIndex: 10,
          proveByIndex: true,
        );

        expect(
          () => packCompressedAccounts(
            inputCompressedAccounts: [inputAccount],
            inputStateRootIndices: [0],
            outputCompressedAccounts: [],
            outputStateTreeInfo: treeInfo, // Should not be provided with inputs
            existingRemainingAccounts: [],
          ),
          throwsArgumentError,
        );
      },
    );

    test('throws when neither input nor output tree info provided', () {
      expect(
        () => packCompressedAccounts(
          inputCompressedAccounts: [],
          inputStateRootIndices: [],
          outputCompressedAccounts: [],
          // No outputStateTreeInfo provided
          existingRemainingAccounts: [],
        ),
        throwsArgumentError,
      );
    });

    test('pads multiple output accounts correctly', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final tree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final treeInfo = TreeInfo(
        tree: tree,
        queue: queue,
        cpiContext: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        ),
        treeType: TreeType.stateV1,
      );

      final outputAccounts = List.generate(
        3,
        (i) => CompressedAccountLegacy(
          owner: owner,
          lamports: BigInt.from(100000 * (i + 1)),
          address: null,
          data: null,
        ),
      );

      final result = packCompressedAccounts(
        inputCompressedAccounts: [],
        inputStateRootIndices: [],
        outputCompressedAccounts: outputAccounts,
        outputStateTreeInfo: treeInfo,
        existingRemainingAccounts: [],
      );

      expect(result.packedOutputCompressedAccounts.length, 3);
      expect(result.remainingAccounts.length, 1); // Single tree reused

      // All outputs should point to same tree index
      for (final output in result.packedOutputCompressedAccounts) {
        expect(output.merkleTreeIndex, 0);
      }
    });
  });

  group('packNewAddressParams', () {
    test('packs single address params', () {
      final addressQueue = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final addressTree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final params = NewAddressParams(
        seed: Uint8List.fromList(List.filled(32, 1)),
        addressQueuePubkey: addressQueue,
        addressMerkleTreePubkey: addressTree,
        addressMerkleTreeRootIndex: 5,
      );

      final result = packNewAddressParams([params], []);

      expect(result.newAddressParamsPacked.length, 1);
      expect(result.remainingAccounts.length, 2); // queue + tree

      final packed = result.newAddressParamsPacked[0];
      expect(packed.addressQueueAccountIndex, 0);
      expect(packed.addressMerkleTreeAccountIndex, 1);
      expect(packed.addressMerkleTreeRootIndex, 5);
    });

    test('reuses accounts across multiple params', () {
      final addressQueue = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final addressTree = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final params = List.generate(
        3,
        (i) => NewAddressParams(
          seed: Uint8List.fromList(List.filled(32, i)),
          addressQueuePubkey: addressQueue, // Same queue
          addressMerkleTreePubkey: addressTree, // Same tree
          addressMerkleTreeRootIndex: i,
        ),
      );

      final result = packNewAddressParams(params, []);

      expect(result.newAddressParamsPacked.length, 3);
      expect(result.remainingAccounts.length, 2); // Accounts reused

      // All should reference same indices
      for (final packed in result.newAddressParamsPacked) {
        expect(packed.addressQueueAccountIndex, 0);
        expect(packed.addressMerkleTreeAccountIndex, 1);
      }
    });
  });
}
