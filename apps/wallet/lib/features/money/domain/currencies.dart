/// The currency pool offered in pickers (onboarding, add-entry, recurring). Hardcoded
/// for now; a future preference will let the user curate which currencies they see
/// (ADR-0013/0015). Codes are ISO 4217.
const List<String> kCurrencyPool = [
  'USD', 'EUR', 'GBP', 'BYN', 'RUB', 'KZT', 'PLN', 'JPY', 'CAD',
];

/// English display names for the pool — used where no localized label exists (the
/// recurring/add-entry pickers) and as the onboarding fallback for currencies without
/// a dedicated l10n string.
const Map<String, String> kCurrencyNames = {
  'USD': 'US Dollar',
  'EUR': 'Euro',
  'GBP': 'British Pound',
  'BYN': 'Belarusian Ruble',
  'RUB': 'Russian Ruble',
  'KZT': 'Kazakhstani Tenge',
  'PLN': 'Polish Zloty',
  'JPY': 'Japanese Yen',
  'CAD': 'Canadian Dollar',
};
