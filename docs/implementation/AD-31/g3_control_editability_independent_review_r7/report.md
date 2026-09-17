# AD-31 G3 control editability independent review R7

Date: 2026-09-15  
Reviewer: independent Luna review (`/root/g3_control_arch_independent_review`)  
Decision: `pass_limited`  
Review scope: proposal and contract review only; no implementation acceptance

## Reviewed evidence

The review read the R7 proposal and manifest, the R6 proposal and manifest,
the frozen AD-31/common contracts, the old `ControlGenomeV5.jl` control
semantics, the sibling realization types/proposal boundary, and the source
feedback contract. The reviewed R7 proposal SHA-256 is
`6eb25f7bb000a37db19ce1435f2848b88c91aa0e08da2b546bc1723bc63069b5`.
The observed repository HEAD is
`4b69f55f7f80240147a65a22809dc1207824dde2`, with 306 dirty porcelain rows as
reported by the proposal. No Julia or DESC execution was performed.

## R7 disposition

R7 closes the three R6 identity/serialization defects without introducing a
new contract conflict.

1. **Single source of truth is now explicit.** The payload contains the actual
   `key`, parent declaration fields, child contract ref, source record, and
   source content hash. Parent binding, child identity, source-record ref, and
   source-payload ref are derived from those actual payload fields. The payload
   does not carry an alternate `parent_binding` or `source_record_ref`, and
   the constructor rejects caller-supplied alternate refs. Source URI/version
   are byte-checked against the source record; a matching URI with a different
   digest is rejected. State and operation receipt refs are required to equal
   the derived payload ref.

2. **The initial key is grouped and serialized once.** The R7 initial hash
   recipe has one `key` input. The key itself contains exactly
   `(candidate_ref, parent_g3_declaration_hash, child_kind, child_id)`, and R7
   expressly forbids repeating those fields as top-level hash inputs. The same
   grouped key is included in the typed-absence recipe. This removes the R6
   dual representation of explicit key components plus a grouped key.

3. **Forgery and chain checks are closed.** Derived parent, child, source
   record, and payload refs are checked against the actual payload, including
   the source-record digest. Empty, first, and second transitions specify
   `ZERO_DIGEST`, prior state, ordered prior operation hashes, last-operation
   equality, and resulting-state equality. Reordered, omitted, duplicated,
   or wrongly referenced history fails closed. The operation hash excludes its
   own and resulting-state hashes, so the stated recipes are acyclic.

The inherited contract remains aligned with the old control semantics: the
fixed historical operation changes exactly one existing fault's `mode`, while
signals, controllers, faults, plans, axes, source payload, source record,
parent binding, child identity, and initial hashes remain immutable. The
proposal remains a control-only sibling of realization and T0, with no T0 or
realization dependency and no physical/provider/engineering/solver/search
promotion. Physical resolution remains typed `:unknown` or
`:terminal_deferred` with a reason.

## Required implementation gates

`pass_limited` authorizes the root architect to decide whether to open the
proposed work order; it does not accept an implementation. Before any
implementation is accepted, the assigned Luna must:

- derive every binding, identity, record ref, and payload ref from the payload
  fields and reject forged or URI-only matching refs;
- implement the grouped-key initial and absence hash recipes exactly once,
  with no legacy duplicate key inputs or recursive hash inputs;
- verify source-record, source-content, initial, operation, and resulting-state
  hashes independently, including empty/first/second history and duplicate,
  reordered, omitted, stale, and forged negative paths;
- preserve the old closed-body and `g3_edit_fault` mode-only semantics, require
  one existing fault mode, and prove failed calls leave canonical semantic
  bytes and digest unchanged;
- keep the source payload immutable and retain the control-only/evidence
  ceiling. No realization, T0, physical, provider, engineering, mesh, solver,
  search, or R01--R10 claim may be promoted by this implementation slice.

No R7 contradiction, obsolete independent-ref field, second key serialization,
or hash recursion was found in the reviewed proposal text. The review is
limited to the contract and does not replace executable implementation,
focused tests, or physical evidence.
