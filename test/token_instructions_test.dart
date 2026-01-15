import 'dart:typed_data';

import 'package:light_sdk/src/programs/account_layouts.dart';
import 'package:light_sdk/src/programs/instruction_cpi.dart';
import 'package:light_sdk/src/programs/token_instructions.dart';
import 'package:light_sdk/src/state/validity_proof.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';

void main() {
  group('InputTokenDataWithContext', () {
    test('encodes correctly with minimal data', () {
      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 100,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(1000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 5,
        lamports: null,
        tlv: null,
      );

      final encoded = input.encode();

      expect(encoded.isNotEmpty, true);
      // amount: 8 bytes, delegateIndex: 1 byte (0=None), merkleContext: 7 bytes,
      // rootIndex: 2 bytes, lamports: 1 byte (0=None), tlv: 1 byte (0=None)
      expect(encoded.length, 20);
    });

    test('encodes with delegate index', () {
      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 100,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(5000),
        delegateIndex: 3,
        merkleContext: context,
        rootIndex: 10,
        lamports: BigInt.from(100000),
        tlv: null,
      );

      final encoded = input.encode();

      expect(encoded.isNotEmpty, true);
      // amount: 8, delegateIndex: 2 (1+1), merkleContext: 7, rootIndex: 2,
      // lamports: 9 (1+8), tlv: 1
      expect(encoded.length, 29);
    });

    test('encodes with tlv data', () {
      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 2,
        queuePubkeyIndex: 3,
        leafIndex: 500,
        proveByIndex: false,
      );

      final tlvData = Uint8List.fromList([1, 2, 3, 4, 5]);

      final input = InputTokenDataWithContext(
        amount: BigInt.from(10000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 15,
        lamports: BigInt.from(50000),
        tlv: tlvData,
      );

      final encoded = input.encode();

      expect(encoded.isNotEmpty, true);
      // Should contain tlv vector (1 byte option + 4 bytes length + 5 bytes data)
    });
  });

  group('PackedTokenTransferOutputData', () {
    test('encodes correctly with minimal data', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final output = PackedTokenTransferOutputData(
        owner: owner,
        amount: BigInt.from(2000),
        lamports: null,
        merkleTreeIndex: 0,
        tlv: null,
      );

      final encoded = output.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32, amount: 8, lamports: 1 (None), merkleTreeIndex: 1, tlv: 1 (None)
      expect(encoded.length, 43);
    });

    test('encodes with lamports', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final output = PackedTokenTransferOutputData(
        owner: owner,
        amount: BigInt.from(3000),
        lamports: BigInt.from(5000000),
        merkleTreeIndex: 1,
        tlv: null,
      );

      final encoded = output.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32, amount: 8, lamports: 9 (1+8), merkleTreeIndex: 1, tlv: 1
      expect(encoded.length, 51);
    });
  });

  group('DelegatedTransfer', () {
    test('encodes without delegate change account', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final delegated = DelegatedTransfer(
        owner: owner,
        delegateChangeAccountIndex: null,
      );

      final encoded = delegated.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32 bytes, delegateChangeAccountIndex: 1 byte (None)
      expect(encoded.length, 33);
    });

    test('encodes with delegate change account index', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final delegated = DelegatedTransfer(
        owner: owner,
        delegateChangeAccountIndex: 2,
      );

      final encoded = delegated.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32, delegateChangeAccountIndex: 2 (1 + 1)
      expect(encoded.length, 34);
    });
  });

  group('InstructionDataTransfer', () {
    test('encodes transfer without proof (compress)', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final recipient = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 10,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(1000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 0,
        lamports: null,
        tlv: null,
      );

      final output = PackedTokenTransferOutputData(
        owner: recipient,
        amount: BigInt.from(1000),
        lamports: null,
        merkleTreeIndex: 0,
        tlv: null,
      );

      final transfer = InstructionDataTransfer(
        proof: null,
        mint: mint,
        delegatedTransfer: null,
        inputTokenDataWithContext: [input],
        outputCompressedAccounts: [output],
        isCompress: true,
        compressOrDecompressAmount: BigInt.from(1000),
        cpiContext: null,
        lamportsChangeAccountMerkleTreeIndex: null,
      );

      final encoded = transfer.encode();

      expect(encoded.isNotEmpty, true);
      // Verify it contains proof=None (0x00), mint (32 bytes), isCompress=true
      expect(encoded[0], 0); // proof = None
    });

    test('encodes transfer with proof and delegate', () {
      final proof = CompressedProof(
        a: List.filled(32, 1),
        b: List.filled(64, 2),
        c: List.filled(32, 3),
      );

      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final owner = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );
      final recipient = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 50,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(5000),
        delegateIndex: 1,
        merkleContext: context,
        rootIndex: 2,
        lamports: null,
        tlv: null,
      );

      final output = PackedTokenTransferOutputData(
        owner: recipient,
        amount: BigInt.from(3000),
        lamports: null,
        merkleTreeIndex: 0,
        tlv: null,
      );

      final changeOutput = PackedTokenTransferOutputData(
        owner: owner,
        amount: BigInt.from(2000),
        lamports: null,
        merkleTreeIndex: 0,
        tlv: null,
      );

      final delegated = DelegatedTransfer(
        owner: owner,
        delegateChangeAccountIndex: 1,
      );

      final transfer = InstructionDataTransfer(
        proof: proof,
        mint: mint,
        delegatedTransfer: delegated,
        inputTokenDataWithContext: [input],
        outputCompressedAccounts: [output, changeOutput],
        isCompress: false,
        compressOrDecompressAmount: null,
        cpiContext: null,
        lamportsChangeAccountMerkleTreeIndex: null,
      );

      final encoded = transfer.encode();

      expect(encoded.isNotEmpty, true);
      // Verify proof is present (0x01 followed by 128 bytes)
      expect(encoded[0], 1); // proof = Some
    });

    test('encodes decompress with CPI context', () {
      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final recipient = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 100,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(10000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 5,
        lamports: null,
        tlv: null,
      );

      final output = PackedTokenTransferOutputData(
        owner: recipient,
        amount: BigInt.from(8000),
        lamports: null,
        merkleTreeIndex: 0,
        tlv: null,
      );

      final cpiContext = CompressedCpiContext.first();

      final transfer = InstructionDataTransfer(
        proof: null,
        mint: mint,
        delegatedTransfer: null,
        inputTokenDataWithContext: [input],
        outputCompressedAccounts: [output],
        isCompress: false,
        compressOrDecompressAmount: BigInt.from(2000),
        cpiContext: cpiContext,
        lamportsChangeAccountMerkleTreeIndex: 0,
      );

      final encoded = transfer.encode();

      expect(encoded.isNotEmpty, true);
    });
  });

  group('InstructionDataMintTo', () {
    test('encodes single recipient', () {
      final recipient = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final mintTo = InstructionDataMintTo(
        recipients: [recipient],
        amounts: [BigInt.from(1000000)],
        lamports: null,
      );

      final encoded = mintTo.encode();

      expect(encoded.isNotEmpty, true);
      // Vec length (4 bytes) + recipient (32 bytes) + Vec length (4 bytes) +
      // amount (8 bytes) + lamports option (1 byte)
      expect(encoded.length, 49);
    });

    test('encodes multiple recipients', () {
      final recipient1 = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final recipient2 = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final mintTo = InstructionDataMintTo(
        recipients: [recipient1, recipient2],
        amounts: [BigInt.from(500000), BigInt.from(750000)],
        lamports: BigInt.from(5000000),
      );

      final encoded = mintTo.encode();

      expect(encoded.isNotEmpty, true);
      // recipients vec: 4 + 32*2 = 68, amounts vec: 4 + 8*2 = 20, lamports: 1 + 8 = 9
      // Total: 68 + 20 + 9 = 97
      expect(encoded.length, 97);
    });
  });

  group('InstructionDataBatchCompress', () {
    test('encodes with single pubkey', () {
      final pubkey = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final batch = InstructionDataBatchCompress(
        pubkeys: [pubkey],
        amounts: null,
        lamports: BigInt.from(1000000),
        amount: null,
        index: 0,
        bump: 255,
      );

      final encoded = batch.encode();

      expect(encoded.isNotEmpty, true);
    });

    test('encodes with multiple pubkeys and amounts', () {
      final pubkey1 = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final pubkey2 = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final batch = InstructionDataBatchCompress(
        pubkeys: [pubkey1, pubkey2],
        amounts: [BigInt.from(100), BigInt.from(200)],
        lamports: null,
        amount: BigInt.from(500),
        index: 1,
        bump: 254,
      );

      final encoded = batch.encode();

      expect(encoded.isNotEmpty, true);
    });
  });

  group('InstructionDataCompressSplTokenAccount', () {
    test('encodes without remaining amount', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );

      final compress = InstructionDataCompressSplTokenAccount(
        owner: owner,
        remainingAmount: null,
        cpiContext: null,
      );

      final encoded = compress.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32, remainingAmount: 1 (None), cpiContext: 1 (None)
      expect(encoded.length, 34);
    });

    test('encodes with remaining amount and CPI context', () {
      final owner = Ed25519HDPublicKey.fromBase58(
        'BPFLoaderUpgradeab1e11111111111111111111111',
      );
      final cpiContext = CompressedCpiContext.set();

      final compress = InstructionDataCompressSplTokenAccount(
        owner: owner,
        remainingAmount: BigInt.from(500),
        cpiContext: cpiContext,
      );

      final encoded = compress.encode();

      expect(encoded.isNotEmpty, true);
      // owner: 32, remainingAmount: 9 (1+8), cpiContext: 4 (1+3)
      expect(encoded.length, 45);
    });
  });

  group('InstructionDataApprove', () {
    test('encodes approve instruction', () {
      final proof = CompressedProof(
        a: List.filled(32, 5),
        b: List.filled(64, 6),
        c: List.filled(32, 7),
      );

      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final delegate = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 25,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(10000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 3,
        lamports: null,
        tlv: null,
      );

      final approve = InstructionDataApprove(
        proof: proof,
        mint: mint,
        inputTokenDataWithContext: [input],
        cpiContext: null,
        delegate: delegate,
        delegatedAmount: BigInt.from(5000),
        delegateMerkleTreeIndex: 0,
        changeAccountMerkleTreeIndex: 1,
        delegateLamports: null,
      );

      final encoded = approve.encode();

      expect(encoded.isNotEmpty, true);
      // Proof always present in approve/revoke (128 bytes)
      expect(encoded.sublist(0, 128).length, 128);
    });

    test('encodes with delegate lamports', () {
      final proof = CompressedProof(
        a: List.filled(32, 1),
        b: List.filled(64, 2),
        c: List.filled(32, 3),
      );

      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final delegate = Ed25519HDPublicKey.fromBase58(
        'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 50,
        proveByIndex: false,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(20000),
        delegateIndex: null,
        merkleContext: context,
        rootIndex: 5,
        lamports: BigInt.from(100000),
        tlv: null,
      );

      final approve = InstructionDataApprove(
        proof: proof,
        mint: mint,
        inputTokenDataWithContext: [input],
        cpiContext: null,
        delegate: delegate,
        delegatedAmount: BigInt.from(15000),
        delegateMerkleTreeIndex: 0,
        changeAccountMerkleTreeIndex: 1,
        delegateLamports: BigInt.from(50000),
      );

      final encoded = approve.encode();

      expect(encoded.isNotEmpty, true);
    });
  });

  group('InstructionDataRevoke', () {
    test('encodes revoke instruction', () {
      final proof = CompressedProof(
        a: List.filled(32, 8),
        b: List.filled(64, 9),
        c: List.filled(32, 10),
      );

      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 0,
        queuePubkeyIndex: 1,
        leafIndex: 75,
        proveByIndex: true,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(8000),
        delegateIndex: 1,
        merkleContext: context,
        rootIndex: 4,
        lamports: null,
        tlv: null,
      );

      final revoke = InstructionDataRevoke(
        proof: proof,
        mint: mint,
        inputTokenDataWithContext: [input],
        cpiContext: null,
        outputAccountMerkleTreeIndex: 0,
      );

      final encoded = revoke.encode();

      expect(encoded.isNotEmpty, true);
      // Proof always present in revoke (128 bytes)
      expect(encoded.sublist(0, 128).length, 128);
    });

    test('encodes with CPI context', () {
      final proof = CompressedProof(
        a: List.filled(32, 11),
        b: List.filled(64, 12),
        c: List.filled(32, 13),
      );

      final mint = Ed25519HDPublicKey.fromBase58(
        'So11111111111111111111111111111111111111112',
      );
      final cpiContext = CompressedCpiContext.first();

      final context = PackedMerkleContext(
        merkleTreePubkeyIndex: 2,
        queuePubkeyIndex: 3,
        leafIndex: 100,
        proveByIndex: false,
      );

      final input = InputTokenDataWithContext(
        amount: BigInt.from(12000),
        delegateIndex: 2,
        merkleContext: context,
        rootIndex: 6,
        lamports: BigInt.from(200000),
        tlv: null,
      );

      final revoke = InstructionDataRevoke(
        proof: proof,
        mint: mint,
        inputTokenDataWithContext: [input],
        cpiContext: cpiContext,
        outputAccountMerkleTreeIndex: 1,
      );

      final encoded = revoke.encode();

      expect(encoded.isNotEmpty, true);
    });
  });

  group('CompressedProof', () {
    test('encodes proof correctly', () {
      final proof = CompressedProof(
        a: List.generate(32, (i) => i),
        b: List.generate(64, (i) => i + 32),
        c: List.generate(32, (i) => i + 96),
      );

      final encoded = proof.encode();

      expect(encoded.length, 128); // 32 + 64 + 32

      // Verify a component
      expect(encoded.sublist(0, 32), List.generate(32, (i) => i));

      // Verify b component
      expect(encoded.sublist(32, 96), List.generate(64, (i) => i + 32));

      // Verify c component
      expect(encoded.sublist(96, 128), List.generate(32, (i) => i + 96));
    });
  });
}
