import 'package:solana/dto.dart';
import 'package:solana/solana.dart';

import '../rpc/compression_api.dart';
import '../utils/account_selection.dart';
import 'compressed_token_program.dart';
import 'token_types.dart';

/// Get token pool info for a mint.
Future<TokenPoolInfo> getTokenPoolInfo({
  required Rpc rpc,
  required Ed25519HDPublicKey mint,
  Ed25519HDPublicKey? tokenProgramId,
}) async {
  final tokenProgram =
      tokenProgramId ?? CompressedTokenProgram.splTokenProgramId;
  final tokenPoolPda = await CompressedTokenProgram.deriveTokenPoolPda(
    mint: mint,
  );

  // Verify the pool exists
  final account = await rpc.rpcClient.getAccountInfo(
    tokenPoolPda.toBase58(),
    encoding: Encoding.base64,
  );

  if (account.value == null) {
    throw StateError('Token pool not found for mint ${mint.toBase58()}');
  }

  return TokenPoolInfo(
    splInterfacePda: tokenPoolPda,
    mint: mint,
    tokenProgramId: tokenProgram,
  );
}

/// Select minimum token accounts for a transfer.
(List<ParsedTokenAccount>, BigInt) selectMinTokenAccountsForTransfer(
  List<ParsedTokenAccount> accounts,
  BigInt amount,
) {
  return selectMinCompressedTokenAccountsForTransfer(
    accounts,
    amount,
    (account) => account.parsed.amount,
  );
}

/// Filter token accounts by mint.
List<ParsedTokenAccount> filterByMint(
  List<ParsedTokenAccount> accounts,
  Ed25519HDPublicKey mint,
) {
  return accounts.where((a) => a.parsed.mint == mint).toList();
}

/// Filter token accounts by owner.
List<ParsedTokenAccount> filterByOwner(
  List<ParsedTokenAccount> accounts,
  Ed25519HDPublicKey owner,
) {
  return accounts.where((a) => a.parsed.owner == owner).toList();
}

/// Filter token accounts that have a delegate.
List<ParsedTokenAccount> filterByDelegate(
  List<ParsedTokenAccount> accounts,
  Ed25519HDPublicKey delegate,
) {
  return accounts.where((a) => a.parsed.delegate == delegate).toList();
}

/// Get total token balance across accounts.
BigInt getTotalBalance(List<ParsedTokenAccount> accounts) {
  return accounts.fold(BigInt.zero, (sum, a) => sum + a.parsed.amount);
}

/// Check if a token account can be spent by the given authority.
bool canSpend(ParsedTokenAccount account, Ed25519HDPublicKey authority) {
  // Owner can always spend
  if (account.parsed.owner == authority) return true;

  // Delegate can spend if set
  if (account.parsed.delegate == authority) return true;

  return false;
}

/// Parse a token amount string to BigInt.
BigInt parseTokenAmount(String amount, int decimals) {
  // Remove any commas
  final cleanedAmount = amount.replaceAll(',', '');

  // Split by decimal point
  final parts = cleanedAmount.split('.');
  if (parts.length > 2) {
    throw FormatException('Invalid amount: $amount');
  }

  final wholePart = parts[0];
  final decimalPart = parts.length > 1 ? parts[1] : '';

  // Pad or truncate decimal part
  final adjustedDecimal = decimalPart
      .padRight(decimals, '0')
      .substring(
        0,
        decimals > decimalPart.length ? decimalPart.length : decimals,
      );

  // Combine
  final combined = wholePart + adjustedDecimal.padRight(decimals, '0');
  return BigInt.parse(combined);
}

/// Format a token amount to human-readable string.
String formatTokenAmount(BigInt amount, int decimals) {
  final str = amount.toString().padLeft(decimals + 1, '0');
  final wholePart = str.substring(0, str.length - decimals);
  final decimalPart = str.substring(str.length - decimals);

  // Remove trailing zeros from decimal part
  var trimmedDecimal = decimalPart.replaceAll(RegExp(r'0+$'), '');
  if (trimmedDecimal.isEmpty) {
    return wholePart;
  }

  return '$wholePart.$trimmedDecimal';
}
