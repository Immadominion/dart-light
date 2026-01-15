/// Integration tests for compressed account address operations.
///
/// These tests require a local Solana validator with Light Protocol programs
/// deployed, along with Photon indexer and prover services.
///
/// To run:
/// ```bash
/// # Start local test environment first
/// dart test test/integration/address_test.dart
/// ```
@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:solana/solana.dart';
import 'package:test/test.dart';

import 'package:light_sdk/light_sdk.dart';

import 'integration.dart';

void main() {
  late TestRpc testRpc;
  late Ed25519HDKeyPair payer;
  late TreeInfo stateTreeInfo;

  setUpAll(() async {
    // Initialize test RPC
    testRpc = await getTestRpc();

    // Create and fund test account
    payer = await newAccountWithLamports(testRpc, lamports: lamportsPerSol * 2);

    // Get state tree info
    final treeInfos = await testRpc.rpc.getStateTreeInfos();
    stateTreeInfo = selectStateTreeInfo(treeInfos);
  });

  group('address derivation', () {
    test('should derive deterministic address from seed', () {
      final seed = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        seed[i] = i + 1;
      }

      // Derive address
      final address1 = deriveAddress(
        seed: seed,
        addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
      );

      // Derive again with same inputs
      final address2 = deriveAddress(
        seed: seed,
        addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
      );

      // Should be identical
      expect(address1, equals(address2));
    });

    test('should derive different addresses for different seeds', () {
      final seed1 = Uint8List(32);
      final seed2 = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        seed1[i] = i;
        seed2[i] = 32 - i;
      }

      final address1 = deriveAddress(
        seed: seed1,
        addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
      );

      final address2 = deriveAddress(
        seed: seed2,
        addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
      );

      // Should be different
      expect(address1, isNot(equals(address2)));
    });

    test('should derive V2 address correctly', () {
      final addressSeed = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        addressSeed[i] = i + 10;
      }
      final programId = LightProgramIds.lightSystemProgram;

      final address = deriveAddressV2(
        addressSeed: addressSeed,
        programId: programId,
        addressMerkleTreePubkey: DefaultTestStateTreeAccounts.batchAddressTree,
      );

      expect(address, isNotNull);
      expect(address.bytes, hasLength(32));
    });
  });

  group('create account with address', () {
    test(
      'should create compressed account with derived address',
      () async {
        // This test is V1 only - V2 requires programId for address derivation via CPI
        // Skip if using V2 API
        if (testRpc.rpc.isV2) {
          return; // Skip for V2
        }

        final seed = Uint8List.fromList(
          List.generate(8, (i) => DateTime.now().microsecond + i),
        );

        final preBalance = await getBalance(testRpc, payer.publicKey);

        // Create account with address
        final result = await createAccount(
          rpc: testRpc.rpc,
          payer: payer,
          seeds: [seed],
          programId: LightProgramIds.lightSystemProgram,
          outputStateTreeInfo: stateTreeInfo,
        );

        expect(result.signature, isNotEmpty);
        expect(result.address, isNotNull);

        // Verify balance decreased (fees paid)
        final postBalance = await getBalance(testRpc, payer.publicKey);
        expect(postBalance, lessThan(preBalance));
      },
      skip: 'V2 API requires programId for address derivation via CPI',
    );

    test('should enforce address uniqueness', () async {
      // Creating same address twice should fail
      // This is enforced by the protocol
    }, skip: 'Requires V1 API or CPI context');
  });

  group('getCompressedAccount by address', () {
    test('should fetch compressed account by hash', () async {
      // First compress some SOL to create an account
      final compressAmount = BigInt.from(50000000);

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: compressAmount,
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get accounts by owner
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items, isNotEmpty);

      // Fetch by hash
      final hash = accounts.items.first.hash;
      final account = await testRpc.rpc.getCompressedAccount(hash: hash);

      expect(account, isNotNull);
      expect(account!.hash, equals(hash));
    });

    test('should return null for non-existent hash', () async {
      final fakeHash = BN254.zero;

      final account = await testRpc.rpc.getCompressedAccount(hash: fakeHash);

      expect(account, isNull);
    });
  });

  group('getMultipleCompressedAccounts', () {
    test('should fetch multiple accounts by hash', () async {
      // Compress multiple amounts
      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: BigInt.from(10000000),
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      await compress(
        rpc: testRpc.rpc,
        payer: payer,
        lamports: BigInt.from(20000000),
        toAddress: payer.publicKey,
        outputStateTreeInfo: stateTreeInfo,
      );

      // Get accounts
      final accounts = await testRpc.rpc.getCompressedAccountsByOwner(
        payer.publicKey,
      );

      expect(accounts.items.length, greaterThanOrEqualTo(2));

      // Fetch multiple by hash
      final hashes = accounts.items.take(2).map((a) => a.hash).toList();
      final fetched = await testRpc.rpc.getMultipleCompressedAccounts(hashes);

      expect(fetched, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(fetched[i], isNotNull);
      }
    });
  });

  group('address tree info', () {
    test('should get address tree info for V2', () async {
      if (!testRpc.rpc.isV2) {
        return; // Skip for V1
      }

      final addressTreeInfo = await testRpc.rpc.getAddressTreeInfoV2();

      expect(addressTreeInfo, isNotNull);
      expect(addressTreeInfo.treeType, equals(TreeType.addressV2));
    });
  });
}
