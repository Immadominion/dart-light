import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('LightSystemProgram', () {
    late Ed25519HDPublicKey payer;
    late TreeInfo treeInfo;

    setUp(() {
      payer = Ed25519HDPublicKey.fromBase58(
        '7yucc7fL3JGbyMwg4neUaenNSdySS39hbAk89Ao3t1Hz',
      );
      treeInfo = TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58(
          'HMf9WvxyqRY6vqHxWNLWWU5s7Z2BgXjaDdnPT6RzMcMu',
        ),
        queue: Ed25519HDPublicKey.fromBase58(
          'HMf9WvxyqRY6vqHxWNLWWU5s7Z2BgXjaDdnPT6RzMcMu',
        ),
        treeType: TreeType.stateV2,
      );
    });

    test('programId should be correct', () {
      expect(
        LightSystemProgram.programId.toBase58(),
        equals(LightProgramIds.lightSystemProgram.toBase58()),
      );
    });

    test('deriveCompressedSolPda should return valid PDA', () async {
      final pda = await LightSystemProgram.deriveCompressedSolPda();

      // Should be 32 bytes
      expect(pda.bytes.length, equals(32));

      // Should be deterministic
      final pda2 = await LightSystemProgram.deriveCompressedSolPda();
      expect(pda, equals(pda2));
    });

    group('compress instruction', () {
      test('should create valid instruction', () {
        final instruction = LightSystemProgram.compress(
          payer: payer,
          toAddress: payer,
          lamports: BigInt.from(1000000000),
          outputStateTreeInfo: treeInfo,
        );

        expect(instruction.programId, equals(LightSystemProgram.programId));
        expect(instruction.accounts.isNotEmpty, isTrue);
        expect(instruction.data.isNotEmpty, isTrue);
      });

      test('should include discriminator in data', () {
        final instruction = LightSystemProgram.compress(
          payer: payer,
          toAddress: payer,
          lamports: BigInt.from(1000000000),
          outputStateTreeInfo: treeInfo,
        );

        // First 8 bytes should be the invoke discriminator
        expect(instruction.data.length, greaterThan(8));
        expect(
          instruction.data.toList().sublist(0, 8),
          equals(LightDiscriminators.invoke),
        );
      });
    });

    group('sumUpLamports', () {
      CompressedAccountWithMerkleContext createAccount(BigInt lamports) {
        final owner = Ed25519HDPublicKey.fromBase58(
          '11111111111111111111111111111111',
        );
        return CompressedAccountWithMerkleContext(
          owner: owner,
          lamports: lamports,
          hash: BN254.zero,
          treeInfo: treeInfo,
          leafIndex: 0,
        );
      }

      test('should sum empty list to zero', () {
        final sum = LightSystemProgram.sumUpLamports([]);
        expect(sum, equals(BigInt.zero));
      });

      test('should sum single account', () {
        final accounts = [createAccount(BigInt.from(1000000))];
        final sum = LightSystemProgram.sumUpLamports(accounts);
        expect(sum, equals(BigInt.from(1000000)));
      });

      test('should sum multiple accounts', () {
        final accounts = [
          createAccount(BigInt.from(1000000)),
          createAccount(BigInt.from(2000000)),
          createAccount(BigInt.from(3000000)),
        ];
        final sum = LightSystemProgram.sumUpLamports(accounts);
        expect(sum, equals(BigInt.from(6000000)));
      });
    });

    group('createTransferOutputState', () {
      CompressedAccountWithMerkleContext createAccount(BigInt lamports) {
        return CompressedAccountWithMerkleContext(
          owner: payer,
          lamports: lamports,
          hash: BN254.zero,
          treeInfo: treeInfo,
          leafIndex: 0,
        );
      }

      test('should create single output when exact amount', () {
        final accounts = [createAccount(BigInt.from(1000000))];
        final outputs = LightSystemProgram.createTransferOutputState(
          inputCompressedAccounts: accounts,
          toAddress: payer,
          lamports: BigInt.from(1000000),
        );

        expect(outputs.length, equals(1));
        expect(outputs.first.lamports, equals(BigInt.from(1000000)));
      });

      test('should create two outputs with change', () {
        final accounts = [createAccount(BigInt.from(1000000))];
        final outputs = LightSystemProgram.createTransferOutputState(
          inputCompressedAccounts: accounts,
          toAddress: payer,
          lamports: BigInt.from(600000),
        );

        expect(outputs.length, equals(2));
        // First output is change
        expect(outputs[0].lamports, equals(BigInt.from(400000)));
        // Second output is transfer amount
        expect(outputs[1].lamports, equals(BigInt.from(600000)));
      });

      test('should throw on insufficient balance', () {
        final accounts = [createAccount(BigInt.from(1000000))];

        expect(
          () => LightSystemProgram.createTransferOutputState(
            inputCompressedAccounts: accounts,
            toAddress: payer,
            lamports: BigInt.from(2000000),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });

  group('Program IDs', () {
    test('light system program ID should be valid', () {
      expect(LightProgramIds.lightSystemProgram.bytes.length, equals(32));
    });

    test('account compression program ID should be valid', () {
      expect(
        LightProgramIds.accountCompressionProgram.bytes.length,
        equals(32),
      );
    });

    test('compressed token program ID should be valid', () {
      expect(LightProgramIds.compressedTokenProgram.bytes.length, equals(32));
    });
  });
}
