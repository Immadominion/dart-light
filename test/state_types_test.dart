import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('CompressedProof', () {
    test('creates proof with byte arrays', () {
      final a = List<int>.filled(32, 1);
      final b = List<int>.filled(64, 2);
      final c = List<int>.filled(32, 3);

      final proof = CompressedProof(a: a, b: b, c: c);

      expect(proof.a, equals(a));
      expect(proof.b, equals(b));
      expect(proof.c, equals(c));
      expect(proof.a.length, equals(32));
      expect(proof.b.length, equals(64));
      expect(proof.c.length, equals(32));
    });

    test('supports empty byte arrays', () {
      final proof = CompressedProof(
        a: List<int>.filled(32, 0),
        b: List<int>.filled(64, 0),
        c: List<int>.filled(32, 0),
      );

      expect(proof.a.length, equals(32));
      expect(proof.b.length, equals(64));
      expect(proof.c.length, equals(32));
    });

    test('encodes to bytes correctly', () {
      final proof = CompressedProof(
        a: List<int>.filled(32, 1),
        b: List<int>.filled(64, 2),
        c: List<int>.filled(32, 3),
      );

      final encoded = proof.encode();
      expect(encoded.length, equals(128)); // 32 + 64 + 32
    });

    test('supports equality comparison', () {
      final a = List<int>.filled(32, 1);
      final b = List<int>.filled(64, 2);
      final c = List<int>.filled(32, 3);

      final proof1 = CompressedProof(a: a, b: b, c: c);
      final proof2 = CompressedProof(a: a, b: b, c: c);

      expect(proof1, equals(proof2));
    });
  });

  group('ValidityProofWithContext', () {
    test('creates validity proof with all components', () {
      final compressedProof = CompressedProof(
        a: List<int>.filled(32, 1),
        b: List<int>.filled(64, 2),
        c: List<int>.filled(32, 3),
      );

      final roots = [BN254.zero, BN254.zero];
      final rootIndices = [0, 1];
      final leafIndices = [10, 20];
      final leaves = [BN254.zero, BN254.zero];

      final tree = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111'),
        queue: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV1,
      );
      final treeInfos = [tree, tree];
      final proveByIndices = [true, true];

      final proof = ValidityProofWithContext(
        compressedProof: compressedProof,
        roots: roots,
        rootIndices: rootIndices,
        leafIndices: leafIndices,
        leaves: leaves,
        treeInfos: treeInfos,
        proveByIndices: proveByIndices,
      );

      expect(proof.compressedProof, equals(compressedProof));
      expect(proof.roots, equals(roots));
      expect(proof.rootIndices, equals(rootIndices));
      expect(proof.leafIndices, equals(leafIndices));
      expect(proof.leaves, equals(leaves));
      expect(proof.treeInfos, equals(treeInfos));
      expect(proof.proveByIndices, equals(proveByIndices));
    });

    test('supports empty arrays', () {
      final compressedProof = CompressedProof(
        a: List<int>.filled(32, 0),
        b: List<int>.filled(64, 0),
        c: List<int>.filled(32, 0),
      );

      final proof = ValidityProofWithContext(
        compressedProof: compressedProof,
        roots: [],
        rootIndices: [],
        leafIndices: [],
        leaves: [],
        treeInfos: [],
        proveByIndices: [],
      );

      expect(proof.roots, isEmpty);
      expect(proof.rootIndices, isEmpty);
      expect(proof.leafIndices, isEmpty);
      expect(proof.leaves, isEmpty);
      expect(proof.treeInfos, isEmpty);
      expect(proof.proveByIndices, isEmpty);
    });

    test('validates array lengths match', () {
      final compressedProof = CompressedProof(
        a: List<int>.filled(32, 1),
        b: List<int>.filled(64, 2),
        c: List<int>.filled(32, 3),
      );

      final leaves = [BN254.zero, BN254.zero];
      final leafIndices = [10, 20];
      final tree = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111'),
        queue: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV1,
      );

      final proof = ValidityProofWithContext(
        compressedProof: compressedProof,
        roots: [BN254.zero, BN254.zero],
        rootIndices: [0, 1],
        leafIndices: leafIndices,
        leaves: leaves,
        treeInfos: [tree, tree],
        proveByIndices: [true, true],
      );

      expect(proof.leaves.length, equals(proof.leafIndices.length));
      expect(proof.leaves.length, equals(2));
    });
  });

  group('MerkleContext', () {
    test('creates merkle context with all fields', () {
      final tree = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111'),
        queue: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV1,
      );
      final hash = BN254.zero;

      final context = MerkleContext(treeInfo: tree, hash: hash, leafIndex: 42);

      expect(context.treeInfo, equals(tree));
      expect(context.hash, equals(hash));
      expect(context.leafIndex, equals(42));
      expect(context.proveByIndex, equals(false));
    });

    test('supports prove by index', () {
      final tree = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111'),
        queue: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV2,
      );

      final context = MerkleContext(
        treeInfo: tree,
        hash: BN254.zero,
        leafIndex: 0,
        proveByIndex: true,
      );

      expect(context.leafIndex, equals(0));
      expect(context.proveByIndex, equals(true));
    });

    test('supports equality comparison', () {
      final tree = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58('11111111111111111111111111111111'),
        queue: Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111112',
        ),
        treeType: TreeType.stateV1,
      );
      final hash = BN254.zero;

      final context1 = MerkleContext(treeInfo: tree, hash: hash, leafIndex: 42);

      final context2 = MerkleContext(treeInfo: tree, hash: hash, leafIndex: 42);

      expect(context1, equals(context2));
    });
  });
}
