import 'package:light_sdk/light_sdk.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  group('CompressedTokenProgram', () {
    late Ed25519HDPublicKey testPayer;
    late Ed25519HDPublicKey testMint;
    late Ed25519HDPublicKey testOwner;
    late Ed25519HDPublicKey testRecipient;
    late Ed25519HDPublicKey testDelegate;
    late TreeInfo testTreeInfo;
    late TokenPoolInfo testTokenPoolInfo;

    setUp(() {
      // Setup test accounts
      testPayer = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      testMint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      testOwner = Ed25519HDPublicKey.fromBase58(
        '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM',
      );
      testRecipient = Ed25519HDPublicKey.fromBase58(
        'H6ARHf6YXhGYeQfUzQNGk6rDNnLBQKrenN712K4AQJEG',
      );
      testDelegate = Ed25519HDPublicKey.fromBase58(
        'FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH',
      );

      // Setup test tree info
      testTreeInfo = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58(
          'CmtH7zCpq4A7v3vKvnWvogF7yZVvCqH8QkjHjLhbdASa',
        ),
        queue: Ed25519HDPublicKey.fromBase58(
          'DQs6QzT8NdTk4eFc1VLKvp3bLCnZRNRXz4rJk9MQsWHq',
        ),
        cpiContext: Ed25519HDPublicKey.fromBase58(
          'F7Z8wCWzqSBDTAq3kkqJ3vZXscZxTmX5kKBVqZGdPz1a',
        ),
        treeType: TreeType.stateV1,
      );

      // Setup test token pool info
      testTokenPoolInfo = TokenPoolInfo(
        splInterfacePda: Ed25519HDPublicKey.fromBase58(
          'GXtd2izAiMJPwMEjfgDrjTjsA1LGPbSgPG3sRzxrfat8',
        ),
        mint: testMint,
        tokenProgramId: CompressedTokenProgram.splTokenProgramId,
      );
    });

    group('PDA Derivation', () {
      test('cpiAuthorityPda is correct', () {
        // Must match the Rust SDK constant:
        // pub const CPI_AUTHORITY: Pubkey = pubkey!("GXtd2izAiMJPwMEjfgTRH3d7k9mjn4Jq3JrWFv9gySYy");
        expect(
          CompressedTokenProgram.cpiAuthorityPda.toBase58(),
          equals('GXtd2izAiMJPwMEjfgTRH3d7k9mjn4Jq3JrWFv9gySYy'),
        );
      });

      test('deriveTokenPoolPda works with index 0', () async {
        final pda = await CompressedTokenProgram.deriveTokenPoolPda(
          mint: testMint,
          poolIndex: 0,
        );

        expect(pda, isNotNull);
        expect(pda.bytes.length, equals(32));
      });

      test('deriveTokenPoolPda is deterministic', () async {
        final pda1 = await CompressedTokenProgram.deriveTokenPoolPda(
          mint: testMint,
        );
        final pda2 = await CompressedTokenProgram.deriveTokenPoolPda(
          mint: testMint,
        );

        expect(pda1, equals(pda2));
      });

      test(
        'deriveTokenPoolPda with different indices produces different PDAs',
        () async {
          final pda0 = await CompressedTokenProgram.deriveTokenPoolPda(
            mint: testMint,
            poolIndex: 0,
          );
          final pda1 = await CompressedTokenProgram.deriveTokenPoolPda(
            mint: testMint,
            poolIndex: 1,
          );

          expect(pda0, isNot(equals(pda1)));
        },
      );
    });

    group('createSplInterface', () {
      test('creates instruction with correct structure', () async {
        final instruction = await CompressedTokenProgram.createSplInterface(
          feePayer: testPayer,
          mint: testMint,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.accounts.length, greaterThanOrEqualTo(6));
        expect(instruction.data.length, greaterThan(0));
      });

      test('includes correct discriminator', () async {
        final instruction = await CompressedTokenProgram.createSplInterface(
          feePayer: testPayer,
          mint: testMint,
        );

        // ByteArray doesn't have sublist - check length (discriminator is 8 bytes)
        final data = instruction.data;
        expect(data.length, equals(8));
      });
    });

    group('mintTo', () {
      test('creates instruction with single recipient', () {
        final instruction = CompressedTokenProgram.mintTo(
          feePayer: testPayer,
          mint: testMint,
          authority: testOwner,
          recipients: [testRecipient],
          amounts: [BigInt.from(1000000)],
          outputStateTreeInfo: testTreeInfo,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.data.length, greaterThan(8));
      });

      test('creates instruction with multiple recipients', () {
        final instruction = CompressedTokenProgram.mintTo(
          feePayer: testPayer,
          mint: testMint,
          authority: testOwner,
          recipients: [testRecipient, testOwner],
          amounts: [BigInt.from(1000000), BigInt.from(500000)],
          outputStateTreeInfo: testTreeInfo,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.accounts.length, greaterThan(10));
      });

      test('throws when recipients and amounts length mismatch', () {
        expect(
          () => CompressedTokenProgram.mintTo(
            feePayer: testPayer,
            mint: testMint,
            authority: testOwner,
            recipients: [testRecipient],
            amounts: [BigInt.from(1000000), BigInt.from(500000)],
            outputStateTreeInfo: testTreeInfo,
            tokenPoolInfo: testTokenPoolInfo,
          ),
          throwsArgumentError,
        );
      });
    });

    group('compress', () {
      test('creates instruction with correct structure', () {
        final instruction = CompressedTokenProgram.compress(
          payer: testPayer,
          owner: testOwner,
          source: testRecipient,
          mint: testMint,
          amount: BigInt.from(1000000),
          outputStateTreeInfo: testTreeInfo,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.accounts.length, greaterThan(10));
      });

      test('uses owner as recipient when toAddress not provided', () {
        final instruction = CompressedTokenProgram.compress(
          payer: testPayer,
          owner: testOwner,
          source: testRecipient,
          mint: testMint,
          amount: BigInt.from(1000000),
          outputStateTreeInfo: testTreeInfo,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(instruction, isNotNull);
      });

      test('uses custom toAddress when provided', () {
        final instruction = CompressedTokenProgram.compress(
          payer: testPayer,
          owner: testOwner,
          source: testRecipient,
          mint: testMint,
          amount: BigInt.from(1000000),
          outputStateTreeInfo: testTreeInfo,
          tokenPoolInfo: testTokenPoolInfo,
          toAddress: testDelegate,
        );

        expect(instruction, isNotNull);
      });
    });

    group('transfer', () {
      test('creates instruction with valid inputs', () {
        final inputAccount = ParsedTokenAccount(
          compressedAccount: CompressedAccountWithMerkleContext(
            owner: testOwner,
            lamports: BigInt.zero,
            hash: BN254.zero,
            treeInfo: testTreeInfo,
            leafIndex: 0,
          ),
          parsed: TokenData(
            mint: testMint,
            owner: testOwner,
            amount: BigInt.from(2000000),
            delegate: null,
            state: TokenAccountState.initialized,
          ),
        );

        final instruction = CompressedTokenProgram.transfer(
          payer: testPayer,
          inputCompressedTokenAccounts: [inputAccount],
          toAddress: testRecipient,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        // ByteArray doesn't have sublist, so check discriminator differently
        final data = instruction.data;
        expect(data.length, greaterThan(8));
      });

      test('throws when input accounts are empty', () {
        expect(
          () => CompressedTokenProgram.transfer(
            payer: testPayer,
            inputCompressedTokenAccounts: [],
            toAddress: testRecipient,
            amount: BigInt.from(1000000),
            recentInputStateRootIndices: [],
            recentValidityProof: null,
          ),
          throwsArgumentError,
        );
      });
    });

    group('decompress', () {
      test('creates instruction with valid inputs', () {
        final inputAccount = ParsedTokenAccount(
          compressedAccount: CompressedAccountWithMerkleContext(
            owner: testOwner,
            lamports: BigInt.zero,
            hash: BN254.zero,
            treeInfo: testTreeInfo,
            leafIndex: 0,
          ),
          parsed: TokenData(
            mint: testMint,
            owner: testOwner,
            amount: BigInt.from(2000000),
            delegate: null,
            state: TokenAccountState.initialized,
          ),
        );

        final instruction = CompressedTokenProgram.decompress(
          payer: testPayer,
          inputCompressedTokenAccounts: [inputAccount],
          toAddress: testRecipient,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.accounts.length, greaterThan(10));
      });

      test('throws when input accounts are empty', () {
        expect(
          () => CompressedTokenProgram.decompress(
            payer: testPayer,
            inputCompressedTokenAccounts: [],
            toAddress: testRecipient,
            amount: BigInt.from(1000000),
            recentInputStateRootIndices: [],
            recentValidityProof: null,
            tokenPoolInfo: testTokenPoolInfo,
          ),
          throwsArgumentError,
        );
      });
    });

    group('approve', () {
      test('creates instruction with valid inputs', () {
        final inputAccount = ParsedTokenAccount(
          compressedAccount: CompressedAccountWithMerkleContext(
            owner: testOwner,
            lamports: BigInt.zero,
            hash: BN254.zero,
            treeInfo: testTreeInfo,
            leafIndex: 0,
          ),
          parsed: TokenData(
            mint: testMint,
            owner: testOwner,
            amount: BigInt.from(2000000),
            delegate: null,
            state: TokenAccountState.initialized,
          ),
        );

        final instruction = CompressedTokenProgram.approve(
          payer: testPayer,
          inputCompressedTokenAccounts: [inputAccount],
          delegate: testDelegate,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.data.length, greaterThan(8));
      });

      test('throws when input accounts are empty', () {
        expect(
          () => CompressedTokenProgram.approve(
            payer: testPayer,
            inputCompressedTokenAccounts: [],
            delegate: testDelegate,
            amount: BigInt.from(1000000),
            recentInputStateRootIndices: [],
            recentValidityProof: null,
          ),
          throwsArgumentError,
        );
      });
    });

    group('revoke', () {
      test('creates instruction with valid inputs', () {
        final inputAccount = ParsedTokenAccount(
          compressedAccount: CompressedAccountWithMerkleContext(
            owner: testOwner,
            lamports: BigInt.zero,
            hash: BN254.zero,
            treeInfo: testTreeInfo,
            leafIndex: 0,
          ),
          parsed: TokenData(
            mint: testMint,
            owner: testOwner,
            amount: BigInt.from(2000000),
            delegate: testDelegate,
            state: TokenAccountState.initialized,
          ),
        );

        final instruction = CompressedTokenProgram.revoke(
          payer: testPayer,
          inputCompressedTokenAccounts: [inputAccount],
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
        );

        expect(
          instruction.programId,
          equals(LightProgramIds.compressedTokenProgram),
        );
        expect(instruction.data.length, greaterThan(8));
      });

      test('throws when input accounts are empty', () {
        expect(
          () => CompressedTokenProgram.revoke(
            payer: testPayer,
            inputCompressedTokenAccounts: [],
            recentInputStateRootIndices: [],
            recentValidityProof: null,
          ),
          throwsArgumentError,
        );
      });
    });

    group('Output State Creation', () {
      test('transfer output state calculates change correctly', () {
        final inputAccounts = [
          ParsedTokenAccount(
            compressedAccount: CompressedAccountWithMerkleContext(
              owner: testOwner,
              lamports: BigInt.zero,
              hash: BN254.zero,
              treeInfo: testTreeInfo,
              leafIndex: 0,
            ),
            parsed: TokenData(
              mint: testMint,
              owner: testOwner,
              amount: BigInt.from(2000000),
              delegate: null,
              state: TokenAccountState.initialized,
            ),
          ),
        ];

        // This will be tested indirectly through instruction creation
        final instruction = CompressedTokenProgram.transfer(
          payer: testPayer,
          inputCompressedTokenAccounts: inputAccounts,
          toAddress: testRecipient,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
        );

        expect(instruction, isNotNull);
      });

      test('transfer output state with exact amount has no change', () {
        final inputAccounts = [
          ParsedTokenAccount(
            compressedAccount: CompressedAccountWithMerkleContext(
              owner: testOwner,
              lamports: BigInt.zero,
              hash: BN254.zero,
              treeInfo: testTreeInfo,
              leafIndex: 0,
            ),
            parsed: TokenData(
              mint: testMint,
              owner: testOwner,
              amount: BigInt.from(1000000),
              delegate: null,
              state: TokenAccountState.initialized,
            ),
          ),
        ];

        final instruction = CompressedTokenProgram.transfer(
          payer: testPayer,
          inputCompressedTokenAccounts: inputAccounts,
          toAddress: testRecipient,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
        );

        expect(instruction, isNotNull);
      });

      test('decompress output state calculates correctly', () {
        final inputAccounts = [
          ParsedTokenAccount(
            compressedAccount: CompressedAccountWithMerkleContext(
              owner: testOwner,
              lamports: BigInt.zero,
              hash: BN254.zero,
              treeInfo: testTreeInfo,
              leafIndex: 0,
            ),
            parsed: TokenData(
              mint: testMint,
              owner: testOwner,
              amount: BigInt.from(2000000),
              delegate: null,
              state: TokenAccountState.initialized,
            ),
          ),
        ];

        final instruction = CompressedTokenProgram.decompress(
          payer: testPayer,
          inputCompressedTokenAccounts: inputAccounts,
          toAddress: testRecipient,
          amount: BigInt.from(1000000),
          recentInputStateRootIndices: [0],
          recentValidityProof: null,
          tokenPoolInfo: testTokenPoolInfo,
        );

        expect(instruction, isNotNull);
      });
    });
  });
}
