import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('TokenData', () {
    test('creates token data with all required fields', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      expect(tokenData.mint, equals(mint));
      expect(tokenData.owner, equals(owner));
      expect(tokenData.amount, equals(BigInt.from(1000000000)));
      expect(tokenData.delegate, isNull);
      expect(tokenData.state, equals(TokenAccountState.initialized));
      expect(tokenData.tlv, isNull);
    });

    test('creates token data with delegate', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final delegate = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111112',
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
        delegate: delegate,
      );

      expect(tokenData.delegate, equals(delegate));
    });

    test('creates token data with TLV data', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final tlvData = List<int>.filled(32, 42);

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
        tlv: tlvData,
      );

      expect(tokenData.tlv, equals(tlvData));
    });

    test('creates frozen token account', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.frozen,
      );

      expect(tokenData.state, equals(TokenAccountState.frozen));
    });

    test('supports zero amount', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.zero,
        state: TokenAccountState.initialized,
      );

      expect(tokenData.amount, equals(BigInt.zero));
    });

    test('supports equality comparison', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );

      final tokenData1 = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      final tokenData2 = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      expect(tokenData1, equals(tokenData2));
    });
  });

  group('TokenAccountState', () {
    test('has all expected states', () {
      expect(TokenAccountState.values.length, equals(3));
      expect(
        TokenAccountState.values,
        contains(TokenAccountState.uninitialized),
      );
      expect(TokenAccountState.values, contains(TokenAccountState.initialized));
      expect(TokenAccountState.values, contains(TokenAccountState.frozen));
    });

    test('can be compared', () {
      expect(
        TokenAccountState.initialized,
        equals(TokenAccountState.initialized),
      );
      expect(
        TokenAccountState.frozen,
        isNot(equals(TokenAccountState.initialized)),
      );
    });
  });

  group('ParsedTokenAccount', () {
    test('combines compressed account with token data', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final hash = BN254.zero;

      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      final compressedAccount = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(0),
        hash: hash,
        treeInfo: treeInfo,
        leafIndex: 42,
        data: CompressedAccountData(
          discriminator: List<int>.filled(8, 0),
          data: List<int>.filled(32, 0),
          dataHash: List<int>.filled(32, 0),
        ),
      );

      final parsedAccount = ParsedTokenAccount(
        compressedAccount: compressedAccount,
        parsed: tokenData,
      );

      expect(parsedAccount.compressedAccount, equals(compressedAccount));
      expect(parsedAccount.parsed, equals(tokenData));
      expect(parsedAccount.parsed.mint, equals(mint));
      expect(parsedAccount.parsed.amount, equals(BigInt.from(1000000000)));
    });

    test('has matching properties when created identically', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final hash = BN254.zero;

      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV1,
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      final compressedAccount = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(0),
        hash: hash,
        treeInfo: treeInfo,
        leafIndex: 42,
      );

      final parsed1 = ParsedTokenAccount(
        compressedAccount: compressedAccount,
        parsed: tokenData,
      );

      final parsed2 = ParsedTokenAccount(
        compressedAccount: compressedAccount,
        parsed: tokenData,
      );

      // Both should have the same properties
      expect(parsed1.parsed.mint, equals(parsed2.parsed.mint));
      expect(parsed1.parsed.amount, equals(parsed2.parsed.amount));
      expect(
        parsed1.compressedAccount.leafIndex,
        equals(parsed2.compressedAccount.leafIndex),
      );
    });

    test('preserves all compressed account properties', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final hash = BN254.zero;
      final address = List<int>.filled(32, 42);

      final treeInfo = TreeInfo(
        tree: owner,
        queue: owner,
        treeType: TreeType.stateV2,
      );

      final tokenData = TokenData(
        mint: mint,
        owner: owner,
        amount: BigInt.from(1000000000),
        state: TokenAccountState.initialized,
      );

      final compressedAccount = CompressedAccount(
        owner: owner,
        lamports: BigInt.from(2039280),
        hash: hash,
        treeInfo: treeInfo,
        leafIndex: 123,
        address: address,
      );

      final parsedAccount = ParsedTokenAccount(
        compressedAccount: compressedAccount,
        parsed: tokenData,
      );

      expect(
        parsedAccount.compressedAccount.lamports,
        equals(BigInt.from(2039280)),
      );
      expect(parsedAccount.compressedAccount.leafIndex, equals(123));
      expect(parsedAccount.compressedAccount.address, equals(address));
      expect(
        parsedAccount.compressedAccount.treeInfo.treeType,
        equals(TreeType.stateV2),
      );
    });
  });
}
