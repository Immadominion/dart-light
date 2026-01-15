import '../state/compressed_account.dart';

/// Selects the minimal number of compressed SOL accounts for a transfer.
///
/// 1. Sorts the accounts by amount in descending order
/// 2. Accumulates the amount until it is greater than or equal to the transfer amount
///
/// Returns the selected accounts and total accumulated lamports.
(List<CompressedAccountWithMerkleContext>, BigInt)
selectMinCompressedSolAccountsForTransfer(
  List<CompressedAccountWithMerkleContext> accounts,
  BigInt transferLamports,
) {
  var accumulatedLamports = BigInt.zero;
  final selectedAccounts = <CompressedAccountWithMerkleContext>[];

  // Sort accounts by lamports in descending order
  final sortedAccounts = List<CompressedAccountWithMerkleContext>.from(accounts)
    ..sort((a, b) => b.lamports.compareTo(a.lamports));

  for (final account in sortedAccounts) {
    if (accumulatedLamports >= transferLamports) break;
    accumulatedLamports += account.lamports;
    selectedAccounts.add(account);
  }

  if (accumulatedLamports < transferLamports) {
    throw InsufficientBalanceException(
      required: transferLamports,
      available: accumulatedLamports,
    );
  }

  return (selectedAccounts, accumulatedLamports);
}

/// Exception thrown when there is insufficient balance for an operation.
class InsufficientBalanceException implements Exception {
  const InsufficientBalanceException({
    required this.required,
    required this.available,
  });

  final BigInt required;
  final BigInt available;

  @override
  String toString() =>
      'InsufficientBalanceException: Required $required, available $available';
}

/// Selects compressed token accounts for a transfer.
///
/// Similar to SOL account selection but for token accounts.
(List<T>, BigInt) selectMinCompressedTokenAccountsForTransfer<T>(
  List<T> accounts,
  BigInt transferAmount,
  BigInt Function(T account) getAmount,
) {
  var accumulatedAmount = BigInt.zero;
  final selectedAccounts = <T>[];

  // Sort accounts by amount in descending order
  final sortedAccounts = List<T>.from(accounts)
    ..sort((a, b) => getAmount(b).compareTo(getAmount(a)));

  for (final account in sortedAccounts) {
    if (accumulatedAmount >= transferAmount) break;
    accumulatedAmount += getAmount(account);
    selectedAccounts.add(account);
  }

  if (accumulatedAmount < transferAmount) {
    throw InsufficientBalanceException(
      required: transferAmount,
      available: accumulatedAmount,
    );
  }

  return (selectedAccounts, accumulatedAmount);
}
