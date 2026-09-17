# M5-C R4 machine acceptance and negative matrix

| area | required machine closure | negative typed result |
|---|---|---|
| condition | eight `prefixItems` in fixed order; aggregate branch; required facts bind to `met/true` | `condition.duplicate`, `condition.order`, `condition.required_closure` |
| binding | nine fixed layers; expected field arrays; field-level booleans; artifact/graph relation | `binding.missing_layer`, `binding.duplicate_layer`, `binding.wrong_link`, `binding.detached` |
| preflight | complete `R`/`limits`; UInt128 cap and saturation; writer guards; admit/defer branch | `preflight.overflow_before_guard`, `preflight.writer_called`, `preflight.limit_relation` |
| budget | relation-to-reason/applied/status/rank; mismatch priority over over-limit | `budget_invalid`, `budget_mismatch`, `budget.over_limit_priority` |
| collision | deterministic injection, payload/full-key bytes+hashes, domains/emitted IDs, hostile raw receipt | `key_collision`, `key_domain_confusion`, `hostile_receipt_incomplete` |
| supervisor | zero post-process, exit relation, termination/timeout/status branch, raw sidecars | `supervisor.receipt_incomplete`, `terminal_deferred`, `not_executed` |
| cache | full key/payload/canonical/validation bytes and hashes; owner is inherited from top-level envelope; entry count/escape flags | `cache_entry_incomplete`, `cache.owner_mismatch`, `cache_cross_derivation`, `cache_escape`, `cache_mutation` |
| baseline | real `baseline_capture_contract_schema.json`; `contract_only_not_captured` -> `typed_absent`; null run/receipt fields | `baseline.typed_absent`, `run.not_authorized` |

Historical corrected counts remain only in a stage receipt with raw line IDs. A missing
receipt is `not_measured`, never numeric zero; the sole timeout-before-receipt exception is
`prepare_rewrite_set` with `not_measured_timeout_before_receipt` and null counts.
