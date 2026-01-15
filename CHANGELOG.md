# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta.1] - 2026-01-15

### Added

- Initial SDK implementation with full TypeScript parity
- Core state types (BN254, CompressedAccount, TreeInfo, ValidityProof)
- Cryptographic utilities (Keccak256, address derivation)
- Complete RPC layer with Photon API support
- Light System Program instruction builders
- Compressed Token Program instruction builders
- High-level actions (compress, decompress, transfer)
- Transaction building and signing utilities
- Account selection algorithms
- Comprehensive error handling
- 275+ unit tests
- Integration test suite
- Documentation and examples
- TypeScript migration guide

## [0.1.0] - 2026-01-11

### Added

#### Core SDK

- `Rpc` class for Solana RPC with compression API (Photon) support
- `BN254` - 254-bit field element for ZK proofs
- `CompressedAccount` and `CompressedAccountWithMerkleContext` types
- `TreeInfo` and `TreeType` for state tree metadata
- `ValidityProof` and `CompressedProof` for ZK validity proofs
- `TokenData` and `ParsedTokenAccount` for compressed tokens

#### Programs

- `LightSystemProgram` - Core compression program instructions
  - `compress()` - Compress SOL
  - `decompress()` - Decompress SOL
  - `transfer()` - Transfer compressed SOL
  - `createAccount()` - Create compressed accounts
- `CompressedTokenProgram` - Token compression instructions
  - `createSplInterface()` - Create token pool
  - `mintTo()` - Mint compressed tokens
  - `transfer()` - Transfer compressed tokens
  - `compress()` - Compress SPL tokens
  - `decompress()` - Decompress to SPL tokens
  - `approve()` / `revoke()` - Delegation support

#### High-Level Actions

- `compress()` - Compress SOL with automatic tree selection
- `decompress()` - Decompress SOL with balance validation
- `transfer()` - Transfer compressed SOL with account selection
- Account selection algorithms for optimal UTXO management

#### RPC Methods

- `getCompressedAccount()` - Get single compressed account
- `getCompressedAccountsByOwner()` - Get accounts by owner
- `getCompressedBalanceByOwner()` - Get compressed SOL balance
- `getCompressedTokenAccountsByOwner()` - Get token accounts
- `getCompressedTokenBalancesByOwner()` - Get token balances
- `getValidityProof()` - Get ZK validity proofs
- `getMultipleNewAddressProofs()` - Get address proofs

#### Utilities

- `deriveAddress()` / `deriveAddressV2()` - Address derivation
- `buildAndSignTransaction()` - Transaction building
- `sendAndConfirmTransaction()` - Transaction submission
- Borsh serialization for all instruction data

#### Error Handling

- `LightException` base class with error codes
- `InsufficientBalanceException` for balance checks
- `TransactionFailedException` / `TransactionTimeoutException`
- `ProofGenerationError` / `ProverUnavailableError`
- `parseLightError()` for RPC error conversion

### Dependencies

- `solana` from espresso-cash for Solana primitives
- `coral_xyz` for Anchor program interactions
- `pointycastle` for Keccak256 cryptography

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.1.0 | 2026-01-11 | Initial release |

[0.1.0]: https://github.com/Lightprotocol/light-protocol/releases/tag/dart-v0.1.0
