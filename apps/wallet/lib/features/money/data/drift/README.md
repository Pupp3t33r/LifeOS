# features/money/data/drift

drift (SQLite) tables and DAOs holding **cached read models** (e.g.
MonthProjection, account balances, transaction lists) and the
`pending_operations` outbox. Cached projections only — never an event log.
Generated with `build_runner` (`drift_dev`).
