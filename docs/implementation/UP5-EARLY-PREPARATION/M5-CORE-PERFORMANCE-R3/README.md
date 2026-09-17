# M5 core performance R3 — early preparation

Status: `implementation_pending_runtime / screen_only`.

This slice is limited to the shared conditional e-graph core files assigned by
the implementation work order.  It preserves the existing canonical byte and
hash writers, rule semantics, query/replay contracts, public entry points, and
the formal UP5/DAG credit boundary.

## Implemented slice

- A derivation-local typed-AST byte/hash cache avoids re-entering the factorial
  canonical search for repeated immutable program references.
- Receipt writers have cache-aware overloads.  Their regular overloads and
  emitted field order remain unchanged.
- Member and proposal identity has structured full-byte fields and an explicit
  length-delimited encoding.  The historical concatenated string is retained
  only as a deterministic emission sort projection, so canonical member order
  and hashes are not changed.
- Saturation uses `Dict` indexes for visited members and proposal targets while
  retaining full-byte equality and the existing witness tie-break.

## Deliberate limits

No Julia command was run in this lane because the parent owns the serialized
Julia lane.  Therefore canonical/hash equality, query/replay equivalence, and
runtime allocation/wall-clock improvement are `not_measured` here.  The new
focused test is provided for the parent integration lane; this record does not
promote `typed_absent`, `terminal_deferred`, or `screen_only` evidence.

The manufactured adapter, its probe, existing P1 tests, `tools/m5_search_contract_r2`,
all `runs/` and historical evidence remain outside this change.
