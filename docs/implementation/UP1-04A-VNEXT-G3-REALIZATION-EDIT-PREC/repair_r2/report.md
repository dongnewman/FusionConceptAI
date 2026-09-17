# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC implementation repair R2

Date: 2026-09-15  
Status: `planned` / `proposal` / `accepted=false`; independent precheck R1 was
`changes_requested`.

## Repairs made

The implementation and focused test files in the parent work order directory
were revised within the same frozen ownership boundary. The child key now uses
the canonical `child_kind=:realization`.

`G3RealizationSourceBodyV1` is a closed typed realization body with source,
field, return and heat ports plus typed components, material domains,
manufacturing domains, ledger accounts, ledger entries and ledger closures.
Construction checks unique IDs, owner scope, port role/direction/sign,
component references, material/process references, account/entry units,
closure domains and exact ledger balances. This keeps the editable body
semantics in the candidate-owned payload instead of leaving a four-port shell.

Typed provenance absence now carries the complete ordered missing-slot set in
the absence hash. Structural conflicts remain `fail_closed`; only genuinely
missing source provenance becomes a typed absent state with
`contract_admission=:terminal_deferred` and no source-content hash.

State operation history is an ordered immutable tuple. An operation ID already
present anywhere in that history is rejected, including non-adjacent repeats.
`initial_state_hash` is carried unchanged through replacement; only current
state, source-content and operation hashes are rebuilt, and the current hash
includes the updated history for replay.

The public state, operation receipt and replacement result constructors accept
only their closed status enums. `physical_resolution` is restricted to
`:unknown` or `:terminal_deferred`, and local replacement always emits
`:unknown`; no local edit can promote physical authority.

## Negative controls added

The focused test source covers complete body hash changes, invalid port
direction and ownership, ledger closure mismatch, foreign candidate/key,
stale state and source hashes, forged operation hash, non-adjacent duplicate
operation ID, complete missing-slot absence hash, absent provenance carrying a
source hash, invalid public statuses, and frozen initial-state hash.

## Evidence boundary

Only static UTF-8/control-byte, JSON, plan/link and scoped diff checks are
performed in this repair. Julia, focused tests, DESC, provider, mesh, solver,
engineering and physical execution remain deliberately unrun. A different
Luna must precheck the revised source and manifest before implementation
acceptance.

