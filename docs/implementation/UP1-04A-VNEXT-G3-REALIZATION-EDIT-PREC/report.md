# UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC implementation slice

Date: 2026-09-15  
Work order: `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC`  
Decision boundary: AD-31 `accepted_limited`; implementation node remains
`planned`/`proposal`/`accepted=false`.

## Scope delivered

This slice adds a realization-only, candidate-owned closed source body in
`src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl`. It provides typed source
ports and exact source/field/return/heat closure, a typed parent G3 declaration
reference and hash, the exact additive child contract identity, four closed
provenance slots, typed absence, and a fixed full replacement operation named
`replace_source_payload`.

The implementation separates `contract_admission` from
`physical_resolution`. Local construction, canonical hashes, replacement
receipts and tests can only produce `:declared_consistent`,
`:terminal_deferred`, or `:fail_closed` contract outcomes; physical resolution
stays `:unknown`. No provider, mesh, solver, engineering or physical authority
is created.

## Identity and stale-state boundary

The implementation keeps the layers distinct: child contract identity,
independent source-record hash, source-content hash, initial-state hash,
current-state hash and operation hash. Source-record hashing excludes its own
hash and all content/operation hashes. Source-content hashing includes the
source-record hash but excludes itself. Operation hashing excludes the
resulting state hash. `expected_prior_source_content_hash` and
`expected_prior_state_hash` are checked independently and any stale mismatch
leaves the state unchanged.

An absent schema, canonicalization, profile or evidence receipt is represented
by a typed absent provenance slot and a typed absent state with no payload or
source-content hash. The absence hash is derived from the absence marker and
does not stand in for source evidence.

## Owned files and exclusions

| Kind | File |
|---|---|
| implementation | `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl` |
| focused tests | `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl` |
| implementation record | this directory |

The old G3 V5/V1 files, T0, package, registry, core planning files and old
receipts were not edited. Control, binding and feedback children are excluded.
No T0 import or dependency was added, and no source, mesh, engineering or
physical run was executed.

## Static validation boundary

Static QA records UTF-8/control-byte checks, JSON parsing of this manifest,
the plan/link validator, and scoped `git diff --check`, with command, exit
code, counts and hashes in `manifest.json`. Julia, focused Julia tests, DESC,
provider, mesh, solver, engineering and physical execution are deliberately
recorded as not run. A different Luna must review the source and these
receipts before any implementation acceptance.

