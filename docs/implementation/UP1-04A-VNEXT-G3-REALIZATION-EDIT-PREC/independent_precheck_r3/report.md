# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC repair R3 independent precheck

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`pass_limited`; `accepted=false`; `review_pending=true`.

R3 closes the four R2 blockers in the reviewed source and focused-test
inputs. The initial identity is carried by an explicit immutable
`initial_source_content_hash`; `initial_state_hash` is checked against that
identity and is carried unchanged by replacement. The current state hash binds
the replacement source hash, operation hash, ordered operation history and
typed absence data. Port IDs are unique before maps are built, public state,
receipt and result constructors have closed status/physical vocabularies, and
the `program_exception` result is reachable only through the internal catch
constructor.

The closed body now rejects duplicate ports, wrong ledger units, unresolved
component/account/port references, and closure/account-domain conflicts. The
focused-test source drives those production constructors and also checks
illegal physical promotion, stale state/source hashes, foreign keys, forged
operation hashes, complete typed absence and non-adjacent duplicate operation
IDs. No Julia, focused test, DESC, provider, mesh, solver, engineering or
physical command was run here, so this is a limited static gate only.

## R2 closure and hash audit

`G3RealizationSourceStateV1` validates `initial_state_hash` with the frozen
initial source hash rather than the current replacement hash (source lines
604-608). The replacement path passes `state.initial_source_content_hash`,
preserves `state.initial_state_hash`, and computes a new current hash from the
replacement source, operation hash, full ordered history and missing-slot
tuple (lines 797-806). The focused source asserts both immutable fields after a
source-changing replacement and then performs a second replacement.

The source-content recipe excludes its own hash and includes the typed parent
identity, child contract identity, source record hash and complete body. The
source-record recipe excludes its own hash. The operation recipe includes the
operation ID, key, both expected prior hashes, complete replacement payload and
source-record reference while excluding any resulting state hash. No new
recursive hash dependency or omitted hash input was found in the reviewed
recipes.

The body enforces four distinct roles and port IDs before constructing
`port_map` (lines 270-273), then resolves account, component, port, unit,
owner, coefficient/effect and closure-domain relationships. R3 tests exercise
duplicate port IDs, a dimensioned ledger unit mismatch, an unresolved port
reference, an invalid/mismatched closure domain and illegal physical status
through the public constructors.

`G3_REALIZATION_CHILD_EDIT_CONTRACT_STATUSES_V1` retains
`:program_exception` as an internal fault vocabulary, while state admission,
receipt admission and public result construction reject it and accept only
their closed public sets. The catch path uses the explicitly tagged internal
constructor; it carries no receipt and cannot be forged through the public
result constructor. Physical resolution remains restricted to `:unknown` and
`:terminal_deferred`, and replacement always emits `:unknown`.

## Boundary and exit gate

The work order remains `planned` / `proposal` / `accepted=false`. This review
does not grant actual-child authority, T0/T1/T2, provider, mesh, engineering,
physical, search, B00/B04 or R01-R10 credit. The old G3 V1/V5, T0 and package
paths were observed read-only. Most of those files are pre-existing untracked
paths in this checkout, so their hashes are observations rather than Git
before/after proof; the tracked registry path has no scoped diff.

The R3 static gate is pass-limited. One serial focused Julia run may now be
scheduled by the parent after recording the current source/test hashes and
keeping the implementation acceptance false. A passing focused run still
cannot promote contract admission to physical or engineering evidence.

