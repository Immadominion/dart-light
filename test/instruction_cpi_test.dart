import 'package:light_sdk/src/programs/account_layouts.dart';
import 'package:light_sdk/src/programs/instruction_cpi.dart';
import 'package:light_sdk/src/state/validity_proof.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  group('CompressedCpiContext', () {
    test('creates first context correctly', () {
      final context = CompressedCpiContext.first();

      expect(context.setContext, isFalse);
      expect(context.firstSetContext, isTrue);
      expect(context.cpiContextAccountIndex, equals(0));
    });

    test('creates set context correctly', () {
      final context = CompressedCpiContext.set();

      expect(context.setContext, isTrue);
      expect(context.firstSetContext, isFalse);
      expect(context.cpiContextAccountIndex, equals(0));
    });

    test('encodes correctly', () {
      final context = CompressedCpiContext(
        setContext: true,
        firstSetContext: false,
        cpiContextAccountIndex: 5,
      );

      final encoded = context.encode();

      // 2 bools (1 byte each) + 1 u8 = 3 bytes
      expect(encoded.length, equals(3));
      expect(encoded[0], equals(1)); // setContext = true
      expect(encoded[1], equals(0)); // firstSetContext = false
      expect(encoded[2], equals(5)); // cpiContextAccountIndex
    });

    test('encodes first context', () {
      final context = CompressedCpiContext.first();
      final encoded = context.encode();

      expect(encoded[0], equals(0)); // setContext = false
      expect(encoded[1], equals(1)); // firstSetContext = true
      expect(encoded[2], equals(0)); // index
    });
  });

  group('InstructionDataInvokeCpi', () {
    test('encodes minimal instruction', () {
      final instruction = InstructionDataInvokeCpi(
        proof: null,
        newAddressParams: [],
        inputCompressedAccountsWithMerkleContext: [],
        outputCompressedAccounts: [],
        relayFee: null,
        compressOrDecompressLamports: null,
        isCompress: false,
        cpiContext: null,
      );

      final encoded = instruction.encode();

      // Verify structure:
      // 1 byte (Option<Proof> = None)
      // + 4 bytes (Vec<NewAddressParams> length = 0)
      // + 4 bytes (Vec<Input> length = 0)
      // + 4 bytes (Vec<Output> length = 0)
      // + 1 byte (Option<relay_fee> = None)
      // + 1 byte (Option<compress_lamports> = None)
      // + 1 byte (bool isCompress = false)
      // + 1 byte (Option<cpi_context> = None)
      // = 17 bytes
      expect(encoded.length, equals(17));

      // Verify None options
      expect(encoded[0], equals(0)); // proof = None
      expect(encoded[13], equals(0)); // relay_fee = None
      expect(encoded[14], equals(0)); // compress_lamports = None
      expect(encoded[15], equals(0)); // isCompress = false
      expect(encoded[16], equals(0)); // cpi_context = None
    });

    test('encodes with proof', () {
      final proof = CompressedProof(
        a: List<int>.filled(32, 0xAA),
        b: List<int>.filled(64, 0xBB),
        c: List<int>.filled(32, 0xCC),
      );

      final instruction = InstructionDataInvokeCpi(
        proof: proof,
        newAddressParams: [],
        inputCompressedAccountsWithMerkleContext: [],
        outputCompressedAccounts: [],
        isCompress: false,
      );

      final encoded = instruction.encode();

      // 1 (Some) + 32 (a) + 64 (b) + 32 (c) + 4 + 4 + 4 + 1 + 1 + 1 + 1
      expect(encoded.length, equals(145));

      // Verify proof discriminator is Some (1)
      expect(encoded[0], equals(1));

      // Verify proof data
      expect(encoded.sublist(1, 33), equals(proof.a));
      expect(encoded.sublist(33, 97), equals(proof.b));
      expect(encoded.sublist(97, 129), equals(proof.c));
    });

    test('encodes with new address params', () {
      final params = NewAddressParamsPacked(
        seed: List<int>.filled(32, 0x11),
        addressQueueAccountIndex: 1,
        addressMerkleTreeAccountIndex: 2,
        addressMerkleTreeRootIndex: 42,
      );

      final instruction = InstructionDataInvokeCpi(
        newAddressParams: [params],
        inputCompressedAccountsWithMerkleContext: [],
        outputCompressedAccounts: [],
        isCompress: false,
      );

      final encoded = instruction.encode();

      // 1 (proof None) + 4 (vec len = 1) + 36 (params) + ...
      expect(encoded[0], equals(0)); // proof None
      expect(encoded[1], equals(1)); // vec length = 1
      expect(encoded[2], equals(0));
      expect(encoded[3], equals(0));
      expect(encoded[4], equals(0));

      // Verify params seed starts at offset 5
      expect(encoded.sublist(5, 37), equals(params.seed));
    });

    test('encodes with CPI context', () {
      final cpiContext = CompressedCpiContext(
        setContext: true,
        firstSetContext: false,
        cpiContextAccountIndex: 3,
      );

      final instruction = InstructionDataInvokeCpi(
        newAddressParams: [],
        inputCompressedAccountsWithMerkleContext: [],
        outputCompressedAccounts: [],
        isCompress: true,
        cpiContext: cpiContext,
      );

      final encoded = instruction.encode();

      // 1 + 4 + 4 + 4 + 1 + 1 + 1 + 1 (cpi context Some) + 3 (cpi context data)
      expect(encoded.length, equals(20));

      // Verify isCompress
      expect(encoded[15], equals(1)); // true

      // Verify CPI context discriminator is Some (1)
      expect(encoded[16], equals(1));

      // Verify CPI context data
      expect(encoded[17], equals(1)); // setContext = true
      expect(encoded[18], equals(0)); // firstSetContext = false
      expect(encoded[19], equals(3)); // index
    });

    test('encodes with relay fee and compress lamports', () {
      final instruction = InstructionDataInvokeCpi(
        newAddressParams: [],
        inputCompressedAccountsWithMerkleContext: [],
        outputCompressedAccounts: [],
        relayFee: BigInt.from(5000),
        compressOrDecompressLamports: BigInt.from(1000000),
        isCompress: true,
      );

      final encoded = instruction.encode();

      // 1 (proof None) + 4 + 4 + 4 + 1 (Some) + 8 (relay_fee) + 1 (Some) + 8 (lamports) + 1 (isCompress) + 1 (cpi None)
      expect(encoded.length, equals(33));

      // Verify relay fee option is Some
      expect(encoded[13], equals(1));

      // Verify relay fee value (little-endian u64 = 5000)
      expect(encoded[14], equals(0x88)); // 5000 = 0x1388
      expect(encoded[15], equals(0x13));

      // Verify compress lamports option is Some
      expect(encoded[22], equals(1));

      // Verify compress lamports value (little-endian u64 = 1000000)
      expect(encoded[23], equals(0x40)); // 1000000 = 0xF4240
      expect(encoded[24], equals(0x42));
      expect(encoded[25], equals(0x0F));

      // Verify isCompress = true
      expect(encoded[31], equals(1));
    });

    test('encodes with input and output accounts', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );

      final compressedAccountLayout = CompressedAccountLayout(
        owner: owner,
        lamports: BigInt.from(1000),
      );

      final merkleContext = PackedMerkleContext(
        merkleTreePubkeyIndex: 1,
        queuePubkeyIndex: 2,
        leafIndex: 100,
        proveByIndex: false,
      );

      final inputAccount = PackedCompressedAccountWithMerkleContext(
        compressedAccount: compressedAccountLayout,
        merkleContext: merkleContext,
        rootIndex: 0,
        readOnly: false,
      );

      final outputAccount = OutputCompressedAccountWithPackedContext(
        compressedAccount: compressedAccountLayout,
        merkleTreeIndex: 3,
      );

      final instruction = InstructionDataInvokeCpi(
        newAddressParams: [],
        inputCompressedAccountsWithMerkleContext: [inputAccount],
        outputCompressedAccounts: [outputAccount],
        isCompress: false,
      );

      final encoded = instruction.encode();

      // Verify vec lengths
      // proof (1) + new_address_params (4) + input_accounts (4 + 52) + output_accounts (4 + 43) + relay_fee (1) + compress_lamports (1) + isCompress (1) + cpi_context (1)
      expect(encoded[0], equals(0)); // proof None
      expect(encoded[1], equals(0)); // new_address_params length = 0

      // Input accounts vec length = 1
      expect(encoded[5], equals(1));

      // Output accounts vec should start after input accounts
      // 1 (proof) + 4 (new_addr vec) + 4 (input vec len) + 52 (input account) = 61
      expect(encoded[61], equals(1)); // output vec length = 1
    });
  });
}
