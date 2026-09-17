# R3 contract boundary

## Status and authority

The package is a contract-only repair.  Current source bytes are
`unknown_until_fresh_refreeze`; the historical R1 package is historical-only.
No Julia, solver, provider, DESC, mesh, S3, network or hardware execution is
part of this package.  External references that cannot be resolved from the
local registry are `typed_absent`; they stay `not_implemented` and
`terminal_deferred`, never `valid_screen`.

## Canonical identity and digest closure

The canonical payload is one byte-defined object containing candidate, G1/G2/G3,
parent, mission, scenario and source typed references.  The binding is a
projection of that same payload.  The checker must recompute payload,
candidate-body, every typed-ref body/content, binding projection and source
projection SHA-256 values from canonical JCS UTF-8 LF bytes.  It must compare
every pointer in `checker_contract.json`; a foreign bundle, ref, owner, mission,
scenario, source, or digest is deterministic `fail_closed`.

## Valid-screen implication

Schema and checker jointly require `status=valid_screen` to imply:

* `valid=true`, `authority=fresh_refreeze_complete`, `fresh_refreeze=true`;
* canonical join, all ref/digest checks, taxonomy, and typed checker are true;
* the complete CAS identity tuple and all four feedback checks are true;
* exactly two distinct serial attempts, exit codes `[0,0]`, semantic and byte
  equality, non-empty raw/process refs, and the same environment/input hash.

Any false value, unknown authority, missing receipt, or absent replay is
`not_executed`, `typed_failure`, or `fail_closed`; it is not a screen pass.

## CAS/history

The immutable tuple is `(candidate_ref, source_ref, owner_ref, edge_ref,
parameter, axis, direction)`.  The deletion request, edge, result feedback and
every history record must have pointer equality for this tuple.  CAS requires
`expected_version=before_version=edge.version` and
`after_version=before_version+1`.  History sequences are exactly `1..n`, with
canonical before/after state bytes and hashes, UTC `Z` timestamps, and no
dynamic insertion.  Rejected operations must be fail-atomic: state, state hash,
operation hash and history bytes are unchanged.

## Dependency and dirty closure

`manifest.json` freezes every source actually loaded by the declared M5/M5-A
include graph: M5/M5-A, M4-A..M4-D, five IR files, both tests, both Python
oracles, and `Project.toml`/`Manifest.toml`.  Each path has bytes, SHA-256,
include/import edges and role.  The review-start inventory captures every
dirty path with status, bytes and hash.  The review-end receipt is an explicit
comparison: baseline paths are unchanged and the only additive paths are this
package.  A pending/absent end receipt cannot authorize execution.

## Failure mapping and evidence ceiling

The concrete taxonomy has exactly one class and resolution for each accepted
failure code.  Record code/class/resolution must equal that row; unknown codes,
duplicate rows and mismatched resolutions fail closed.  Raw stdout/stderr,
PID, exit code and UTC receipt are preserved.

The package can at most support a future manufactured software fixture
screen-only lane.  It grants no UP4/B07A/B07B/B08, provider, solver,
engineering, physical, candidate, or R01-R10 credit.
