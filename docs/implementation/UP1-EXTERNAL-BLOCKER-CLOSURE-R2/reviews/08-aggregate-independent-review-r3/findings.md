# Findings

No P1/P2 findings.

## Bounded observations

- Forged `prior_state` with matching fingerprint is rejected as
  `conflict/prior_state_not_in_ledger`, terminal and no-publish.
- Missing ledger argument is `typed_absence/state_ledger_required` with
  `terminal_deferred=true` and `no_publish=true`, including when a forged prior
  is supplied.
- Ledger state, `prev_hash`, sequence, `code_version`, canonical state hash,
  input fingerprint, record hash, unknown record field, and rollback variants
  all become `invalid/state_ledger_tampered` or conflict, terminal and
  non-publishable.
- Concurrent changed-intake replay yields exactly one `intake_changed` append
  and one `prior_state_not_in_ledger` conflict; the ledger remains two records.
- Same-input noop with an empty input package overlay returns the complete
  four-package state from the ledger, not caller-controlled packages.

