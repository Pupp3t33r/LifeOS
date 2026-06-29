import '../../../../app/theme/category_colors.dart';

// =============================================================================
// MOCK DATA — DELETE WHEN WIRED TO THE MONEY BACKEND.
//
// Everything below is hand-authored sample content so the Home cockpit renders
// a realistic, *static* month with no server. When the Money API lands, replace
// `homeMock` with data mapped from `MonthProjection` (Money ADR-0007), the flow
// ledger (ADR-0016/0026), recurring occurrences (ADR-0017) and planned-purchase
// period events (ADR-0018), then delete this file.
//
// The view models (HomeEntry / HomeLine / ...) are deliberately UI-shaped, not
// domain-shaped — a rendering sketch, not an API contract. The real screen will
// map DTOs onto whatever widgets survive this iteration.
// =============================================================================

/// How an entry came to be in the period — drives the by-Type grouping toggle.
enum EntryType { recurring, planned, adhoc }

/// A category reference as the UI needs it: a display name + a palette slot.
/// The real model resolves colour from a device-local override or
/// [CategoryPalette.forId]; here we pin slots by hand to match the design.
class HomeCategoryRef {
  const HomeCategoryRef(this.name, this.color);

  final String name;
  final CategoryPalette color;
}

/// One line inside an entry. Entries are containers (Money ADR-0019: line-items
/// carry the per-line category); a single-line entry is just the common case.
class HomeLine {
  const HomeLine({required this.name, required this.category, required this.amount});

  final String name;
  final HomeCategoryRef category;

  /// Signed: income positive, spending negative.
  final double amount;
}

/// A worklist entry — a recurring payment, a planned purchase, or an ad-hoc
/// flow. [logged] mirrors the projected-vs-actual split (ADR-0007/0026): an
/// upcoming entry is not yet a flow; a logged one is.
class HomeEntry {
  const HomeEntry({
    required this.title,
    required this.type,
    required this.logged,
    required this.lines,
    this.note,
    this.due,
  });

  final String title;
  final EntryType type;
  final bool logged;
  final List<HomeLine> lines;

  /// Trailing subtitle context, e.g. "from wishlist", "8 of 24", "Jun 1".
  final String? note;

  /// Due hint shown in the accent colour on upcoming rows, e.g. "due Jun 5".
  final String? due;

  double get total => lines.fold(0, (sum, x) => sum + x.amount);
  bool get isIncome => total > 0;
}

/// The reactive on-track verdict + the period header.
class HomeSummary {
  const HomeSummary({
    required this.monthLabel,
    required this.periodSpan,
    required this.projected,
    required this.target,
    required this.daysLeft,
    required this.active,
    this.nextPeriodLabel,
  });

  final String monthLabel; // "June 2026"
  final String periodSpan; // "Jun 1 – Jun 30 · day 18 of 30"
  final double projected; // projected savings this period
  final double target; // savings target
  final int daysLeft;
  final bool active;
  final String? nextPeriodLabel; // "July open" — another open period (ADR-0023)

  /// Positive = ahead of target.
  double get onTrackBy => projected - target;
}

/// A per-category budget for the period (Money ADR-0025).
class HomeBudget {
  const HomeBudget({
    required this.name,
    required this.color,
    required this.spent,
    required this.limit,
  });

  final String name;
  final CategoryPalette color;
  final double spent;
  final double limit;

  double get fraction => limit <= 0 ? 0 : (spent / limit).clamp(0, 1).toDouble();
  bool get full => spent >= limit;
}

/// A savings account line in the side rail. Pre-formatted strings — these are
/// mock; the real rail formats from `Money` + the display-currency conversion.
class HomeAccount {
  const HomeAccount({required this.name, required this.value, this.secondary, this.accent = false});

  final String name;
  final String value;
  final String? secondary; // original-currency amount, e.g. "€2,150"
  final bool accent; // tint the dot with the accent colour
}

/// A pinned exchange rate.
class HomeRate {
  const HomeRate({required this.pair, required this.value, required this.delta, required this.up});

  final String pair; // "EUR → USD"
  final String value; // "1.074"
  final String delta; // ".3%"
  final bool up;
}

/// The whole mocked month, in one place.
class HomeMock {
  const HomeMock({
    required this.summary,
    required this.entries,
    required this.budgets,
    required this.accounts,
    required this.rates,
    required this.rateSource,
  });

  final HomeSummary summary;
  final List<HomeEntry> entries;
  final List<HomeBudget> budgets;
  final List<HomeAccount> accounts;
  final List<HomeRate> rates;
  final String rateSource; // "Belarusbank sell · 14:02"
}

// ---- categories used by the sample month -----------------------------------

const _housing = HomeCategoryRef('Housing', CategoryPalette.clay);
const _utilities = HomeCategoryRef('Utilities', CategoryPalette.teal);
const _finance = HomeCategoryRef('Finance', CategoryPalette.slate);
const _photography = HomeCategoryRef('Photography', CategoryPalette.ochre);
const _accessories = HomeCategoryRef('Accessories', CategoryPalette.denim);
const _fitness = HomeCategoryRef('Fitness', CategoryPalette.olive);
const _income = HomeCategoryRef('Income', CategoryPalette.sage);
const _food = HomeCategoryRef('Food', CategoryPalette.sage);
const _household = HomeCategoryRef('Household', CategoryPalette.stone);
const _drinks = HomeCategoryRef('Drinks', CategoryPalette.rose);
const _clothing = HomeCategoryRef('Clothing', CategoryPalette.rose);
const _subscriptions = HomeCategoryRef('Subscriptions', CategoryPalette.teal);

/// The sample month rendered by the Home cockpit. Mirrors the design mock at
/// apps/wallet/docs/design/home/cockpit-final.html.
const homeMock = HomeMock(
  summary: HomeSummary(
    monthLabel: 'June 2026',
    periodSpan: 'Jun 1 – Jun 30 · day 18 of 30',
    projected: 1250,
    target: 1000,
    daysLeft: 12,
    active: true,
    nextPeriodLabel: 'July open',
  ),
  entries: [
    // ---- upcoming (not yet a flow) ----
    HomeEntry(
      title: 'Rent',
      type: EntryType.recurring,
      logged: false,
      due: 'due Jun 5',
      lines: [HomeLine(name: 'Rent', category: _housing, amount: -1400)],
    ),
    HomeEntry(
      title: 'Phone plan',
      type: EntryType.recurring,
      logged: false,
      due: 'due Jun 12',
      lines: [HomeLine(name: 'Phone plan', category: _utilities, amount: -30)],
    ),
    HomeEntry(
      title: 'Car loan',
      type: EntryType.recurring,
      logged: false,
      due: 'due Jun 15',
      note: '8 of 24',
      lines: [HomeLine(name: 'Car loan', category: _finance, amount: -320)],
    ),
    HomeEntry(
      title: 'Camera kit',
      type: EntryType.planned,
      logged: false,
      note: 'from wishlist',
      lines: [
        HomeLine(name: '50mm lens', category: _photography, amount: -240),
        HomeLine(name: 'UV filter + cap', category: _accessories, amount: -60),
      ],
    ),
    HomeEntry(
      title: 'Running shoes',
      type: EntryType.planned,
      logged: false,
      note: 'from wishlist',
      lines: [HomeLine(name: 'Running shoes', category: _fitness, amount: -120)],
    ),
    // ---- logged (realized as flows) ----
    HomeEntry(
      title: 'Salary',
      type: EntryType.recurring,
      logged: true,
      note: 'Jun 1',
      lines: [HomeLine(name: 'Salary', category: _income, amount: 4200)],
    ),
    HomeEntry(
      title: 'Costco run',
      type: EntryType.adhoc,
      logged: true,
      lines: [
        HomeLine(name: 'Bulk groceries', category: _food, amount: -62),
        HomeLine(name: 'Household', category: _household, amount: -34),
        HomeLine(name: 'Wine', category: _drinks, amount: -16),
      ],
    ),
    HomeEntry(
      title: 'Groceries · Lidl',
      type: EntryType.adhoc,
      logged: true,
      lines: [HomeLine(name: 'Groceries · Lidl', category: _food, amount: -86)],
    ),
    HomeEntry(
      title: 'Refund · ASOS',
      type: EntryType.adhoc,
      logged: true,
      lines: [HomeLine(name: 'Refund · ASOS', category: _clothing, amount: 22)],
    ),
    HomeEntry(
      title: 'Netflix',
      type: EntryType.recurring,
      logged: true,
      lines: [HomeLine(name: 'Netflix', category: _subscriptions, amount: -15)],
    ),
  ],
  budgets: [
    HomeBudget(name: 'Housing', color: CategoryPalette.clay, spent: 1400, limit: 1400),
    HomeBudget(name: 'Food', color: CategoryPalette.sage, spent: 86, limit: 300),
    HomeBudget(name: 'Subscriptions', color: CategoryPalette.teal, spent: 15, limit: 40),
    HomeBudget(name: 'Fitness', color: CategoryPalette.olive, spent: 0, limit: 150),
  ],
  accounts: [
    HomeAccount(name: 'Main savings', value: '\$8,420'),
    HomeAccount(name: 'Euro pot', value: '\$2,310', secondary: '€2,150'),
    HomeAccount(name: 'Travel fund', value: '\$1,050', accent: true),
  ],
  rates: [
    HomeRate(pair: 'EUR → USD', value: '1.074', delta: '.3%', up: true),
    HomeRate(pair: 'GBP → USD', value: '1.271', delta: '.1%', up: false),
    HomeRate(pair: 'PLN → USD', value: '0.252', delta: '.2%', up: true),
  ],
  rateSource: 'Belarusbank sell · 14:02',
);

// ---- formatting helpers (mock-grade USD; replace with locale-aware Money
// formatting when the real model lands) -------------------------------------

/// "$1,400" — magnitude only, no sign.
String formatUsd(double amount) => '\$${_grouped(amount.abs().round())}';

/// "1,400" — magnitude, no symbol or sign (for the right side of "spent / limit").
String formatPlain(double amount) => _grouped(amount.abs().round());

/// "+$4,200" / "−$1,400" — signed, using the minus glyph (U+2212) like the design.
String formatSigned(double amount) {
  final sign = amount < 0 ? '−' : '+';
  return '$sign\$${_grouped(amount.abs().round())}';
}

String _grouped(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
