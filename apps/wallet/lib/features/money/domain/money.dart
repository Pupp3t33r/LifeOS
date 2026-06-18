/// Dart mirror of the Money service's `Money(decimal Amount, string Currency)`
/// value object. Always pass the amount/currency pair together — never a bare
/// `double` or `num` (see apps/wallet/AGENTS.md, "Conventions Specific to Wallet").
///
/// Dart has no native decimal type. The real model (once the OpenAPI dart-dio
/// client lands in Phase 5) carries the amount as a string-backed decimal to
/// avoid float rounding. This placeholder uses `num` only to keep the shell
/// compiling; do not build money math on it.
class Money {
  const Money({required this.amount, required this.currency});

  /// Monetary amount. Replace with a decimal-safe representation in Phase 5.
  final num amount;

  /// ISO 4217 currency code, e.g. "USD", "EUR".
  final String currency;
}
