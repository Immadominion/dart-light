import 'dart:typed_data';

import 'package:solana/solana.dart';

/// Abstract interface for transaction signers.
///
/// This allows the SDK to work with different signing mechanisms:
/// - [KeyPairSigner]: Uses an [Ed25519HDKeyPair] with direct private key access
/// - [ExternalSigner]: Uses an external signing service (e.g., Privy, hardware wallets)
///
/// ## Example with KeyPair
/// ```dart
/// final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
/// final signer = KeyPairSigner(keypair);
/// ```
///
/// ## Example with External Signer
/// ```dart
/// class PrivySigner implements ExternalSigner {
///   @override
///   Ed25519HDPublicKey get publicKey => myPublicKey;
///
///   @override
///   Future<Uint8List> sign(Uint8List message) async {
///     return await privyWallet.signMessage(message);
///   }
/// }
/// ```
abstract class Signer {
  /// The public key of this signer.
  Ed25519HDPublicKey get publicKey;

  /// Sign a message and return the 64-byte Ed25519 signature.
  Future<Uint8List> sign(Uint8List message);
}

/// A signer that uses an [Ed25519HDKeyPair] for signing.
///
/// This is the simplest signer type, used when you have direct access
/// to the private key (e.g., in server-side code or testing).
class KeyPairSigner implements Signer {
  final Ed25519HDKeyPair _keyPair;

  KeyPairSigner(this._keyPair);

  @override
  Ed25519HDPublicKey get publicKey => _keyPair.publicKey;

  @override
  Future<Uint8List> sign(Uint8List message) async {
    final signature = await _keyPair.sign(message);
    return Uint8List.fromList(signature.bytes);
  }

  /// Access the underlying keypair (useful for compatibility with existing code).
  Ed25519HDKeyPair get keyPair => _keyPair;
}

/// Extension to easily convert an [Ed25519HDKeyPair] to a [Signer].
extension Ed25519HDKeyPairSignerExtension on Ed25519HDKeyPair {
  /// Convert this keypair to a [Signer].
  Signer toSigner() => KeyPairSigner(this);
}
