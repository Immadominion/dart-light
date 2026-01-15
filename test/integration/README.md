# Integration Tests

This directory contains integration tests for the Light Protocol Dart SDK.

## Prerequisites

Integration tests require a local test environment with:

1. **Solana Validator** - Local Solana test validator
2. **Light Protocol Programs** - Deployed compression programs
3. **Photon Indexer** - Compression API for querying compressed accounts
4. **Prover Service** - ZK proof generation server

## Setup

### Option 1: Light Protocol Dev Environment

If you have the Light Protocol repository cloned:

```bash
cd light-protocol
./scripts/devenv.sh
```

This starts all required services.

### Option 2: Manual Setup

1. Start Solana test validator:

   ```bash
   solana-test-validator
   ```

2. Deploy Light Protocol programs:

   ```bash
   # From light-protocol repo
   anchor deploy
   ```

3. Start Photon indexer:

   ```bash
   # Default endpoint: http://127.0.0.1:8784
   ```

4. Start prover service:

   ```bash
   # Default endpoint: http://127.0.0.1:3001
   ```

## Running Tests

### Run All Integration Tests

```bash
cd dart-light
dart test test/integration/ --tags integration
```

### Run Specific Test File

```bash
dart test test/integration/compress_test.dart
dart test test/integration/transfer_test.dart
dart test test/integration/token_test.dart
dart test test/integration/address_test.dart
dart test test/integration/edge_cases_test.dart
```

### Run with Custom Endpoints

```bash
SOLANA_RPC_URL=http://localhost:8899 \
COMPRESSION_API_URL=http://localhost:8784 \
PROVER_URL=http://localhost:3001 \
dart test test/integration/
```

## Test Structure

| File | Description |
|------|-------------|
| `test_config.dart` | Configuration constants and environment variables |
| `test_rpc.dart` | TestRpc class for integration test RPC client |
| `test_utils.dart` | Helper functions for test account creation |
| `compress_test.dart` | Compress and decompress SOL operations |
| `transfer_test.dart` | Compressed SOL transfer operations |
| `token_test.dart` | Compressed token operations |
| `address_test.dart` | Address derivation and account lookup |
| `edge_cases_test.dart` | Edge cases and stress tests |

## Skipping Integration Tests

Integration tests are tagged with `@Tags(['integration'])`. To skip them:

```bash
dart test --exclude-tags integration
```

## Troubleshooting

### Connection Refused

Ensure all services are running:

- Solana validator on port 8899
- Photon indexer on port 8784
- Prover on port 3001

### Airdrop Failed

Local validator may need SOL. Check validator logs.

### Proof Generation Timeout

Prover service may be slow on first request. Increase timeout:

```dart
final testRpc = await getTestRpc(
  config: TestRpcConfig(timeout: Duration(seconds: 120)),
);
```

### Transaction Failed

Check transaction logs for specific error. Common issues:

- Insufficient balance
- Stale validity proof
- Program not deployed
