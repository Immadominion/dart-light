# Solana Dart API Reference

This document maps TypeScript Solana/web3.js APIs to their Dart (espresso-cash) equivalents.
Understanding these differences is **critical** for implementing the Light Protocol SDK.

---

## 1. Key Pair & Public Key

### TypeScript (web3.js)

```typescript
import { Keypair, PublicKey } from "@solana/web3.js";

const keypair = Keypair.generate();
const pubkey = keypair.publicKey;
const pubkeyFromString = new PublicKey("...");
pubkey.toBase58();
pubkey.toBytes();
```

### Dart (espresso-cash/solana)

```dart
import 'package:solana/solana.dart';

// Generate random keypair
final keypair = await Ed25519HDKeyPair.random();

// From mnemonic
final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic, account: 0, change: 0);

// From private key bytes
final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: bytes);

// Public key
final publicKey = keypair.publicKey; // Ed25519HDPublicKey

// Public key from base58 string
final pubkey = Ed25519HDPublicKey.fromBase58("...");

// Public key methods
pubkey.toBase58(); // String
pubkey.bytes;      // List<int>
pubkey.toByteArray(); // ByteArray
```

### Key Differences

- Dart uses `Ed25519HDKeyPair` (not `Keypair`)
- Dart uses `Ed25519HDPublicKey` (not `PublicKey`)
- All keypair creation is **async** in Dart
- There's no `Ed25519HDPublicKey(bytes)` constructor taking raw bytes - use factory

---

## 2. Program Derived Addresses (PDAs)

### TypeScript

```typescript
const [pda, bump] = PublicKey.findProgramAddressSync(
  [Buffer.from("seed"), pubkey.toBuffer()],
  programId
);
```

### Dart

```dart
// Note: Returns only the address (no bump)
final pda = await Ed25519HDPublicKey.findProgramAddress(
  seeds: [
    "seed".codeUnits,
    pubkey.bytes,
  ],
  programId: programId,
);
```

### Key Differences

- Dart method is **async** (no sync variant)
- Dart does **not** return bump seed - must manually calculate if needed
- Seeds are `Iterable<Iterable<int>>` in Dart, not `Buffer[]`

---

## 3. Instructions

### TypeScript

```typescript
const instruction = new TransactionInstruction({
  keys: [
    { pubkey: account1, isSigner: true, isWritable: true },
    { pubkey: account2, isSigner: false, isWritable: false },
  ],
  programId: PROGRAM_ID,
  data: Buffer.from([...]),
});
```

### Dart

```dart
final instruction = Instruction(
  programId: programId, // Ed25519HDPublicKey
  accounts: [
    AccountMeta.writeable(pubKey: account1, isSigner: true),
    AccountMeta.readonly(pubKey: account2, isSigner: false),
  ],
  data: ByteArray([...]), // ByteArray, not Buffer
);
```

### Key Differences

- `Instruction` class, not `TransactionInstruction`
- `AccountMeta.writeable()` / `AccountMeta.readonly()` factory constructors
- Data is `ByteArray`, not `Buffer`

---

## 4. Transactions / Messages

### TypeScript

```typescript
const transaction = new Transaction();
transaction.add(instruction1, instruction2);
transaction.recentBlockhash = blockhash;
transaction.feePayer = payer.publicKey;

// Sign
transaction.sign(signer1, signer2);

// Serialize for sending
const rawTx = transaction.serialize();
```

### Dart

```dart
// Create message with instructions
final message = Message(instructions: [instruction1, instruction2]);

// Sign message (returns SignedTx)
final signedTx = await keypair.signMessage(
  message: message,
  recentBlockhash: blockhash,
);

// The signedTx.compiledMessage includes all account info
// Encode for sending
final encoded = signedTx.encode(); // Base64 string
```

### Key Differences

- Dart uses `Message` (not `Transaction`)
- `signMessage` returns `SignedTx` directly
- Fee payer is derived from the signing keypair
- For multiple signers: see signTransaction helper

---

## 5. Multi-Signer Transactions

### TypeScript

```typescript
transaction.sign(signer1, signer2);
```

### Dart

```dart
// Use signTransaction helper (from solana_client.dart)
Future<SignedTx> signTransaction(
  RecentBlockhash recentBlockhash,
  Message message,
  List<Ed25519HDKeyPair> signers,
) async {
  final feePayer = signers.first.publicKey;
  final compiled = message.compile(
    recentBlockhash: recentBlockhash.blockhash,
    feePayer: feePayer,
  );
  
  final signatures = await Future.wait(
    signers.map((s) => s.sign(compiled.toByteArray())),
  );
  
  return SignedTx(signatures: signatures, compiledMessage: compiled);
}
```

---

## 6. RPC Client

### TypeScript

```typescript
const connection = new Connection("https://api.mainnet-beta.solana.com");
const balance = await connection.getBalance(pubkey);
const accountInfo = await connection.getAccountInfo(pubkey);
```

### Dart

```dart
// Simple RPC calls
final rpcClient = RpcClient("https://api.mainnet-beta.solana.com");
final balance = await rpcClient.getBalance(pubkey.toBase58());
final accountInfo = await rpcClient.getAccountInfo(pubkey.toBase58());

// Full client with websocket support
final client = SolanaClient(
  rpcUrl: Uri.parse("https://api.mainnet-beta.solana.com"),
  websocketUrl: Uri.parse("wss://api.mainnet-beta.solana.com"),
);
```

### Key Differences

- `RpcClient` for simple RPC calls
- `SolanaClient` for full features (includes websocket)
- Most methods take `String` (base58), not PublicKey object

---

## 7. Commitment

### TypeScript

```typescript
import { Commitment } from "@solana/web3.js";
const commitment: Commitment = "confirmed";
```

### Dart

```dart
import 'package:solana/solana.dart'; // exports Commitment

final commitment = Commitment.confirmed;
// Values: Commitment.processed, Commitment.confirmed, Commitment.finalized
```

---

## 8. Compute Budget

### TypeScript

```typescript
import { ComputeBudgetProgram } from "@solana/web3.js";

const ix = ComputeBudgetProgram.setComputeUnitLimit({ units: 400000 });
const ix2 = ComputeBudgetProgram.setComputeUnitPrice({ microLamports: 1 });
```

### Dart

```dart
import 'package:solana/solana.dart'; // exports ComputeBudgetProgram

final ix = ComputeBudgetInstruction.setComputeUnitLimit(units: 400000);
final ix2 = ComputeBudgetInstruction.setComputeUnitPrice(microLamports: 1);
```

### Key Differences

- Dart uses `ComputeBudgetInstruction` factories (not `ComputeBudgetProgram.xxx`)
- Returns `Instruction` directly

---

## 9. ByteArray Utilities

### Dart-specific ByteArray helpers

```dart
import 'package:solana/encoder.dart';

ByteArray.u8(value);   // 1 byte unsigned
ByteArray.u16(value);  // 2 bytes unsigned little-endian
ByteArray.u32(value);  // 4 bytes unsigned little-endian
ByteArray.u64(value);  // 8 bytes unsigned little-endian

ByteArray.merge([array1, array2]); // Concatenate
ByteArray.fromBase58(string);
ByteArray.fromString(string); // Length-prefixed
```

---

## 10. Complete Transaction Flow Example

### Dart

```dart
import 'package:solana/solana.dart';

Future<String> sendTransaction({
  required SolanaClient client,
  required Ed25519HDKeyPair payer,
  required List<Instruction> instructions,
}) async {
  final message = Message(instructions: instructions);
  
  final txId = await client.sendAndConfirmTransaction(
    message: message,
    signers: [payer],
    commitment: Commitment.confirmed,
  );
  
  return txId;
}
```

---

## Summary: Import Mapping

| TypeScript Import | Dart Import |
|-------------------|-------------|
| `@solana/web3.js` | `package:solana/solana.dart` |
| `Keypair` | `Ed25519HDKeyPair` |
| `PublicKey` | `Ed25519HDPublicKey` |
| `Transaction` | `Message` + `SignedTx` |
| `TransactionInstruction` | `Instruction` |
| `ComputeBudgetProgram` | `ComputeBudgetInstruction` |
| `Connection` | `RpcClient` or `SolanaClient` |
| `AccountMeta` | `AccountMeta` (same) |
| `Buffer` | `ByteArray` |
| `Commitment` | `Commitment` (enum) |

---

## Type Aliases for dart-light

For cleaner code, we define:

```dart
/// Type alias for wallet/signer
typedef Wallet = Ed25519HDKeyPair;

/// Type alias for public key  
typedef PublicKey = Ed25519HDPublicKey;
```

This allows more intuitive code while maintaining compatibility.
