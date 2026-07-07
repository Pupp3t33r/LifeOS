import 'package:flutter/material.dart';
import '../../../../app/theme/calm_tokens.dart';
import '../../domain/category.dart';
import '../../domain/currencies.dart';

/// Sentinel returned by [pickCategory] to mean "clear the category" (vs a null
/// result, which means the picker was dismissed).
const Category kNoCategory = Category(id: '', name: 'None', isSystem: false);

const Map<String, String> _symbols = {
  'USD': '\$', 'CAD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
  'RUB': '₽', 'KZT': '₸', 'BYN': 'Br',
};

/// Display magnitude of [amount] in [currency] (no sign). Display-only until the
/// decimal-safe model lands with the OpenAPI client.
String formatMagnitude(num amount, String currency) {
  final decimals = currency == 'JPY' ? 0 : 2;
  final magnitude = amount.abs().toStringAsFixed(decimals);
  final symbol = _symbols[currency];
  return symbol != null ? '$symbol$magnitude' : '$magnitude $currency';
}

/// Signed display of [amount] (− for out, + for in).
String formatSigned(num amount, String currency) {
  final sign = amount < 0 ? '−' : '+';
  return '$sign${formatMagnitude(amount, currency)}';
}

/// Opens a money create/resolve surface: a bottom sheet on phones, a centred dialog
/// on wide screens — the same wrapper the add-entry sheet uses, so every money
/// surface feels the same. [builder] receives whether it's rendering in a bottom
/// sheet (for grab-handle / safe-area handling).
Future<T?> showMoneySheet<T>(
  BuildContext context,
  Widget Function(bool bottomSheet) builder,
) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 820),
          child: builder(false),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => builder(true),
  );
}

/// A category chooser. Returns the chosen [Category], [kNoCategory] to clear, or null
/// if dismissed. System and user categories are listed together; the current
/// [selectedId] is ticked.
Future<Category?> pickCategory(
  BuildContext context,
  List<Category> categories, {
  String? selectedId,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('None'),
            trailing: selectedId == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(kNoCategory),
          ),
          const Divider(height: 1),
          for (final category in categories)
            ListTile(
              leading: Icon(
                category.isSystem ? Icons.lock_outline : Icons.label_outline,
                size: 20,
              ),
              title: Text(category.name),
              trailing: category.id == selectedId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(category),
            ),
        ],
      ),
    ),
  );
}

/// A currency chooser. Returns the chosen code, or null if dismissed.
Future<String?> pickCurrency(BuildContext context, {required String selected}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(CalmTokens.radiusLg)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final code in kCurrencyPool)
            ListTile(
              title: Text(code),
              subtitle: kCurrencyNames[code] == null ? null : Text(kCurrencyNames[code]!),
              trailing: code == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(code),
            ),
        ],
      ),
    ),
  );
}
