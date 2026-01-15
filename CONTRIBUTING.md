# Contributing to Light Protocol Dart SDK

Thank you for your interest in contributing to the Light Protocol Dart SDK! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Pull Requests](#pull-requests)
- [Code Style](#code-style)
- [Documentation](#documentation)

## Code of Conduct

Please read and follow our [Code of Conduct](https://github.com/Lightprotocol/light-protocol/blob/main/CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up the development environment (see below)
4. Create a feature branch
5. Make your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- Dart SDK 3.7.0 or later
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/Lightprotocol/light-protocol.git
cd light-protocol/dart-light

# Get dependencies
dart pub get

# Verify setup
dart analyze
dart test
```

### Project Structure

```
dart-light/
├── lib/
│   ├── light_sdk.dart          # Main library export
│   └── src/
│       ├── actions/            # High-level operations
│       ├── constants/          # Program IDs, configuration
│       ├── errors/             # Exception types
│       ├── programs/           # Instruction builders
│       ├── rpc/                # RPC layer
│       ├── state/              # Data types
│       ├── token/              # Token operations
│       └── utils/              # Utilities
├── test/                       # Unit tests
│   └── integration/            # Integration tests
├── example/                    # Example code
└── docs/                       # Documentation
```

## Making Changes

### Branch Naming

Use descriptive branch names:

- `feature/add-xyz` - New features
- `fix/issue-123` - Bug fixes
- `docs/update-readme` - Documentation
- `refactor/improve-xyz` - Code improvements

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:

```
feat(rpc): add getCompressedTokenBalances method
fix(transfer): handle zero amount edge case
docs(readme): add Flutter integration example
test(compress): add unit tests for compress action
```

## Testing

### Running Tests

```bash
# Run all unit tests
dart test

# Run specific test file
dart test test/address_test.dart

# Run with coverage
dart test --coverage=coverage

# Run integration tests (requires local validator)
dart test --tags integration
```

### Writing Tests

- Place tests in `test/` directory
- Use descriptive test names
- Follow the Arrange-Act-Assert pattern
- Test edge cases and error conditions

Example:

```dart
import 'package:test/test.dart';
import 'package:light_sdk/light_sdk.dart';

void main() {
  group('BN254', () {
    test('should create from BigInt', () {
      // Arrange
      final value = BigInt.from(12345);
      
      // Act
      final bn254 = BN254.fromBigInt(value);
      
      // Assert
      expect(bn254.toBigInt(), equals(value));
    });
    
    test('should throw for value exceeding field size', () {
      // Arrange
      final tooLarge = BN254.fieldModulus + BigInt.one;
      
      // Act & Assert
      expect(
        () => BN254.fromBigInt(tooLarge),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

## Pull Requests

### Before Submitting

1. Run `dart format .` to format code
2. Run `dart analyze` and fix any issues
3. Run `dart test` and ensure all tests pass
4. Update documentation if needed
5. Add tests for new functionality

### PR Template

```markdown
## Description

Brief description of changes.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

Describe how you tested the changes.

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-reviewed the code
- [ ] Added tests for new functionality
- [ ] All tests pass
- [ ] Updated documentation
```

### Review Process

1. A maintainer will review your PR
2. Address any feedback
3. Once approved, your PR will be merged

## Code Style

### General Guidelines

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `dart format` for formatting
- Maximum line length: 80 characters
- Use meaningful variable and function names

### Naming Conventions

```dart
// Classes: PascalCase
class CompressedAccount {}

// Functions/methods: camelCase
Future<void> compressSol() async {}

// Variables: camelCase
final balance = BigInt.zero;

// Constants: camelCase or SCREAMING_SNAKE_CASE
const lamportsPerSol = 1000000000;

// Private members: _prefixed
final _internalState = <String, dynamic>{};
```

### Documentation

- Document all public APIs with `///` comments
- Include examples in documentation
- Use `@param`, `@return`, `@throws` annotations where helpful

```dart
/// Compresses SOL from a regular account into a compressed account.
///
/// Example:
/// ```dart
/// final signature = await compress(
///   rpc: rpc,
///   payer: wallet,
///   lamports: BigInt.from(1000000000),
///   toAddress: recipient,
/// );
/// ```
///
/// Throws [InsufficientBalanceException] if the payer doesn't have enough SOL.
Future<String> compress({
  required Rpc rpc,
  required Ed25519HDKeyPair payer,
  required BigInt lamports,
  Ed25519HDPublicKey? toAddress,
}) async {
  // Implementation
}
```

### Error Handling

- Use typed exceptions from `errors/light_errors.dart`
- Never swallow errors silently
- Provide helpful error messages

```dart
if (balance < required) {
  throw InsufficientBalanceException(
    required: required,
    available: balance,
  );
}
```

## Documentation

### Updating Documentation

- Keep README.md up to date
- Add examples for new features
- Update CHANGELOG.md for releases
- Document breaking changes clearly

### API Documentation

Generate API docs with:

```bash
dart doc .
```

## Questions?

- Open an issue for questions
- Join our [Discord](https://discord.gg/lightprotocol)
- Check existing issues and discussions

Thank you for contributing!
