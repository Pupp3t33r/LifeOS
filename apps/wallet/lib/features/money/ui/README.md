# features/money/ui

One folder per screen (vertical slice): widgets, controllers, and screen-local
Riverpod providers co-located. Phase 1 screens (see apps/wallet/PLAN.md §4):

- `month_overview/` — Home savings canvas (implemented as a placeholder shell)
- `recurring/` — income, bills, subscriptions, installments
- `wishlist/` — wishlist + planned purchases
- `purchase_orders/` — convert-to-PO flow and PO status
- `transactions/` — optional actuals log
- `budgets/` — light per-category targets
