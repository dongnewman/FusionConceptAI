# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC implementation repair R3

Date: 2026-09-15  
Status: `planned` / `proposal` / `accepted=false`; independent R2 precheck was
`changes_requested`.

## Repairs made

`G3RealizationSourceStateV1` now stores an explicit immutable
`initial_source_content_hash`. The initial-state hash is computed from that
frozen initial identity and the complete missing-slot set; replacement carries
it forward unchanged. The current-state hash is computed from the replacement
source content, operation hash and ordered operation history. This avoids
recomputing the initial hash from current content and makes the history
replayable.

The four source ports now require unique port IDs in addition to unique roles.
All component, ledger, unit, owner, closure-domain and port references are
checked through explicit maps and exact source-body coefficients/effects;
duplicate IDs, wrong units/references and closure-domain conflicts fail at
construction.

`program_exception` is retained only as an internal result path used when an
unexpected exception is caught by the operation. The public result constructor
does not admit user-forged `program_exception`; state and receipt constructors
also use closed admission/physical enums. Physical resolution remains only
`:unknown` or `:terminal_deferred`, and local replacement always emits
`:unknown`.

## Negative controls and evidence boundary

The focused test source adds duplicate-port, ledger-unit/reference,
closure-domain, frozen-initial-source, invalid-public-status and illegal
physical-promotion controls, while retaining foreign-key, both stale-hash,
forged-operation, complete-absence and non-adjacent duplicate-operation
controls. Only UTF-8/control-byte, JSON, plan/link and scoped diff checks are
run here. Julia, focused tests, DESC, provider, mesh, solver, engineering and
physical execution remain unrun; a different Luna must precheck this repair
before implementation acceptance.

