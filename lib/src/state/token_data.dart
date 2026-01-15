import 'package:equatable/equatable.dart';
import 'package:solana/solana.dart';

/// Token account state.
enum TokenAccountState { uninitialized, initialized, frozen }

/// Parsed token data from a compressed token account.
class TokenData extends Equatable {
  const TokenData({
    required this.mint,
    required this.owner,
    required this.amount,
    required this.state,
    this.delegate,
    this.tlv,
  });

  /// Token mint address.
  final Ed25519HDPublicKey mint;

  /// Token owner address.
  final Ed25519HDPublicKey owner;

  /// Token amount.
  final BigInt amount;

  /// Account state.
  final TokenAccountState state;

  /// Optional delegate address.
  final Ed25519HDPublicKey? delegate;

  /// Optional TLV data (for token extensions).
  final List<int>? tlv;

  @override
  List<Object?> get props => [mint, owner, amount, state, delegate, tlv];
}

// Note: ParsedTokenAccount is defined in token_types.dart with proper typing.

/// Token balance for a specific mint.
class TokenBalance extends Equatable {
  const TokenBalance({required this.balance, required this.mint});

  /// Balance amount.
  final BigInt balance;

  /// Mint address.
  final Ed25519HDPublicKey mint;

  @override
  List<Object?> get props => [balance, mint];
}
