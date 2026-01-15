import 'package:light_sdk/src/programs/account_layouts.dart';
import 'package:light_sdk/src/state/bn254.dart';
import 'package:light_sdk/src/state/compressed_account.dart';
import 'package:light_sdk/src/state/tree_info.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  group('PackedMerkleContext', () {
    test('encodes correctly', () {
      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 1,
        queuePubkeyIndex: 2,
        leafIndex: 42,
        proveByIndex: true,
      );

      final encoded = context.encode();

      // u8 + u8 + u32 + bool = 1 + 1 + 4 + 1 = 7 bytes
      expect(encoded.length, equals(7));
      expect(encoded[0], equals(1)); // merkle tree index
      expect(encoded[1], equals(2)); // queue index
      expect(encoded[2], equals(42)); // leaf index (little-endian u32)
      expect(encoded[3], equals(0)); // leaf index byte 2
      expect(encoded[4], equals(0)); // leaf index byte 3
      expect(encoded[5], equals(0)); // leaf index byte 4
      expect(encoded[6], equals(1)); // proveByIndex = true
    });

    test('handles large leaf index', () {
      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 0,
        leafIndex: 0x12345678,
        proveByIndex: false,
      );

      final encoded = context.encode();

      expect(encoded.length, equals(7));
      expect(encoded[2], equals(0x78)); // little-endian
      expect(encoded[3], equals(0x56));
      expect(encoded[4], equals(0x34));
      expect(encoded[5], equals(0x12));
    });
  });

  group('CompressedAccountLayout', () {
    test('encodes minimal account', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.from(1000),
      );

      final encoded = layout.encode();

      // 32 bytes owner + 8 bytes lamports + 1 byte option discriminator (0) for address + 1 byte option discriminator (0) for data
      expect(encoded.length, equals(42));

      // Verify owner
      expect(encoded.sublist(0, 32), equals(owner.bytes));

      // Verify lamports (little-endian u64)
      expect(encoded[32], equals(0xE8)); // 1000 = 0x3E8
      expect(encoded[33], equals(0x03));
      expect(encoded[34], equals(0x00));

      // Verify address option is None
      expect(encoded[40], equals(0));

      // Verify data option is None
      expect(encoded[41], equals(0));
    });

    test('encodes account with address', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final address = List<int>.filled(32, 0xAA);

      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.zero,
        address: address,
      );

      final encoded = layout.encode();

      // 32 owner + 8 lamports + 1 option (Some) + 32 address + 1 option (None)
      expect(encoded.length, equals(74));

      // Verify address option discriminator is Some (1)
      expect(encoded[40], equals(1));

      // Verify address bytes
      expect(encoded.sublist(41, 73), equals(address));

      // Verify data option is None
      expect(encoded[73], equals(0));
    });

    test('encodes account with data', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final data = CompressedAccountData(
        discriminator: List<int>.filled(8, 0x01),
        data: [1, 2, 3, 4],
        dataHash: List<int>.filled(32, 0xFF),
      );

      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.zero,
        data: data,
      );

      final encoded = layout.encode();

      // 32 owner + 8 lamports + 1 (None for address)
      // + 1 (Some for data) + 8 discriminator + 4 (vec length) + 4 (data) + 32 (data_hash)
      expect(encoded.length, equals(90));

      // Verify data option is Some (1)
      expect(encoded[40], equals(0)); // address None
      expect(encoded[41], equals(1)); // data Some

      // Verify discriminator
      expect(encoded.sublist(42, 50), equals(data.discriminator));

      // Verify vec length (u32 little-endian)
      expect(encoded[50], equals(4)); // length = 4
      expect(encoded[51], equals(0));

      // Verify data bytes
      expect(encoded.sublist(54, 58), equals([1, 2, 3, 4]));

      // Verify data hash
      expect(encoded.sublist(58, 90), equals(data.dataHash));
    });

    test('validates discriminator length', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final badData = CompressedAccountData(
        discriminator: [1, 2, 3], // wrong length
        data: [],
        dataHash: List<int>.filled(32, 0),
      );

      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.zero,
        data: badData,
      );

      expect(() => layout.encode(), throwsA(isA<ArgumentError>()));
    });
  });

  group('PackedCompressedAccountWithMerkleContext', () {
    test('encodes input account', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.from(5000),
      );

      final merkleContext = PackedMerkleContext(
        merkleTreePubkeyIndex: 3,
        queuePubkeyIndex: 4,
        leafIndex: 100,
        proveByIndex: false,
      );

      final packed = PackedCompressedAccountWithMerkleContext(
        compressedAccount: layout,
        merkleContext: merkleContext,
        rootIndex: 42,
        readOnly: false,
      );

      final encoded = packed.encode();

      // Compressed account (42 bytes) + merkle context (7 bytes) + root_index (2 bytes) + read_only (1 byte)
      expect(encoded.length, equals(52));

      // Verify root index at expected position (little-endian u16)
      expect(encoded[49], equals(42));
      expect(encoded[50], equals(0));

      // Verify read_only
      expect(encoded[51], equals(0)); // false
    });
  });

  group('OutputCompressedAccountWithPackedContext', () {
    test('encodes output account', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final layout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.from(2000),
      );

      final output = OutputCompressedAccountWithPackedContext(
        compressedAccount: layout,
        merkleTreeIndex: 5,
      );

      final encoded = output.encode();

      // Compressed account (42 bytes) + merkle_tree_index (1 byte)
      expect(encoded.length, equals(43));

      // Verify merkle tree index is at the end
      expect(encoded[42], equals(5));
    });
  });

  group('NewAddressParamsPacked', () {
    test('encodes new address params', () {
      final seed = List<int>.filled(32, 0x42);
      final params = NewAddressParamsPacked(
        seed: seed,
        addressQueueAccountIndex: 10,
        addressMerkleTreeAccountIndex: 11,
        addressMerkleTreeRootIndex: 123,
      );

      final encoded = params.encode();

      // 32 seed + 1 queue index + 1 tree index + 2 root index = 36 bytes
      expect(encoded.length, equals(36));

      // Verify seed
      expect(encoded.sublist(0, 32), equals(seed));

      // Verify indices
      expect(encoded[32], equals(10)); // queue index
      expect(encoded[33], equals(11)); // tree index

      // Verify root index (little-endian u16)
      expect(encoded[34], equals(123));
      expect(encoded[35], equals(0));
    });

    test('validates seed length', () {
      expect(
        () =>
            NewAddressParamsPacked(
              seed: [1, 2, 3], // wrong length
              addressQueueAccountIndex: 0,
              addressMerkleTreeAccountIndex: 0,
              addressMerkleTreeRootIndex: 0,
            ).encode(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CompressedAccountLayout.fromCompressedAccount', () {
    test('converts CompressedAccount to layout', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      // Create a minimal TreeInfo for the test (we just need to construct a valid CompressedAccount)
      // This won't be used in the conversion, but is required for CompressedAccount
      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );

      final account = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(1000),
        hash: BN254.fromBigInt(BigInt.zero),
        treeInfo: treeInfo,
        leafIndex: 0,
        address: List<int>.filled(32, 0xBB),
      );

      final layout = CompressedAccountLayout.fromCompressedAccount(account);

      expect(layout.owner, equals(account.owner));
      expect(layout.lamports, equals(account.lamports));
      expect(layout.address, equals(account.address));
      expect(layout.data, equals(account.data));
    });
  });
}
